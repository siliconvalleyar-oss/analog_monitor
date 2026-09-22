/**
 * =============================================================================
 * http_server.cpp - Implementacion del servidor HTTP (API REST)
 * =============================================================================
 *
 * Servidor HTTP minimo sobre la API RAW de lwIP. No usa el httpd de lwIP (que
 * requiere fsdata/SSI/CGI); implementa directamente el manejo de peticiones
 * TCP para responder GET con JSON.
 *
 * Flujo:
 *   1. http_server_init(): crea el PCB de escucha en HTTP_PORT.
 *   2. Un cliente se conecta (app Flutter) -> callback http_accept().
 *   3. Llegan datos (request HTTP) -> http_recv() acumula hasta encontrar el
 *      fin de cabeceras ("\r\n\r\n").
 *   4. Se parsea la ruta ("GET /api/..." ) y se responde con el JSON generado
 *      a partir de la ultima lectura de ADC y del estado del dispositivo.
 *   5. Cuando todos los bytes de la respuesta fueron acusados (http_sent) se
 *      cierra la conexion (Connection: close).
 *
 * Todas las funciones marcadas como callback de lwIP se ejecutan dentro de
 * cyw43_arch_poll(), por lo que pertenecen al contexto del hilo principal y
 * no requieren locks adicionales (modo NO_SYS). Sin embargo, es FUNDAMENTAL
 * llamar a http_server_poll() en el loop de main para que la red avance.
 * =============================================================================
 */

#include "http_server.h"

#include <cinttypes>
#include <cstdio>
#include <cstring>

#include "pico/cyw43_arch.h"
#include "pico/stdlib.h"

#include "lwip/ip4_addr.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include "lwip/pbuf.h"
#include "lwip/tcp.h"

#include "wifi_config.h"

/* ===========================================================================
 * Constantes internas
 * =========================================================================== */

/* Entradas analogicas expuestas (canal ADC -> GPIO) */
#define HTTP_CHANNEL_COUNT 3
static const uint16_t HTTP_CHANNEL_GPIOS[HTTP_CHANNEL_COUNT] = {26, 27, 28};

/* Tamano del buffer de request por conexion (suficiente para GET sin body) */
#define HTTP_REQUEST_BUFFER 512
/* Tamano del buffer donde se compone la respuesta HTTP completa */
#define HTTP_RESPONSE_BUFFER 1024
/* Tamano del buffer del cuerpo JSON */
#define HTTP_BODY_BUFFER 512
/* Timeout de poll: cerramos conexiones inactivas tras (POLL_INTERVAL*500) ms */
#define HTTP_POLL_INTERVAL_S 5

/* ===========================================================================
 * Estado por conexion (pool estatico)
 * =========================================================================== */

typedef struct HttpConn {
    struct tcp_pcb *pcb;
    bool            in_use;
    uint8_t         buf[HTTP_REQUEST_BUFFER];
    uint16_t        len;          /* bytes recibidos en buf */
    bool            response_pending;
    uint16_t        write_total;  /* bytes totales de la respuesta */
    uint16_t        acked;        /* bytes acusados por el cliente */
} HttpConn;

static HttpConn g_conns[HTTP_MAX_CLIENTS];
static struct tcp_pcb *g_listen_pcb = NULL;

/* Datos compartidos (un unico hilo en modo poll) */
static const AdcReading *g_reading = NULL;
static volatile int32_t g_rssi = HTTP_RSSI_UNKNOWN;
static uint32_t g_boot_ms = 0;

/* Buffers para componer respuestas (secuencial por la unicidad del hilo) */
static char g_body[HTTP_BODY_BUFFER];
static char g_response[HTTP_RESPONSE_BUFFER];

/* ===========================================================================
 * Utilidades
 * =========================================================================== */

static inline uint32_t now_ms(void) {
    return (uint32_t)to_ms_since_boot(get_absolute_time());
}

static void http_close_conn(HttpConn *c) {
    if (!c->in_use || c->pcb == NULL) {
        return;
    }
    tcp_arg(c->pcb, NULL);
    tcp_recv(c->pcb, NULL);
    tcp_sent(c->pcb, NULL);
    tcp_poll(c->pcb, NULL, 0);
    tcp_err(c->pcb, NULL);

    err_t err = tcp_close(c->pcb);
    if (err != ERR_OK) {
        /* No se pudo cerrar limpiamente (ERR_MEM): forzamos */
        tcp_abort(c->pcb);
    }
    c->pcb = NULL;
    c->in_use = false;
}

static void http_err(void *arg, err_t err) {
    HttpConn *c = (HttpConn *)arg;
    (void)err;
    if (c->in_use) {
        c->pcb = NULL; /* lwIP ya libero el PCB */
        c->in_use = false;
    }
}

static err_t http_sent(void *arg, struct tcp_pcb *pcb, u16_t len) {
    HttpConn *c = (HttpConn *)arg;
    (void)pcb;
    c->acked = (uint16_t)(c->acked + len);
    if (c->acked >= c->write_total) {
        /* Todo el response fue confirmado por el cliente */
        http_close_conn(c);
    }
    return ERR_OK;
}

static err_t http_poll_client(void *arg, struct tcp_pcb *pcb) {
    HttpConn *c = (HttpConn *)arg;
    (void)pcb;
    /* Cliente inactivo por mas del timeout: liberar el slot */
    http_close_conn(c);
    return ERR_OK;
}

/* ===========================================================================
 * Rutas HTTP
 * =========================================================================== */

typedef enum Route {
    ROUTE_UNKNOWN,
    ROUTE_STATUS,
    ROUTE_ANALOG,
    ROUTE_ROOT,
} Route;

static bool buffer_has_headers_end(const uint8_t *buf, uint16_t len) {
    for (uint16_t i = 0; i + 3 < len; i++) {
        if (buf[i] == '\r' && buf[i + 1] == '\n' &&
            buf[i + 2] == '\r' && buf[i + 3] == '\n') {
            return true;
        }
    }
    for (uint16_t i = 0; i + 1 < len; i++) {
        if (buf[i] == '\n' && buf[i + 1] == '\n') {
            return true;
        }
    }
    return false;
}

static Route parse_route(const uint8_t *buf, uint16_t len) {
    static const char status_path[] = "/api/status";
    static const char analog_path[] = "/api/analog";

    /* La primera linea tiene la forma: "GET /ruta HTTP/1.1" */
    if (len < 4 || memcmp(buf, "GET", 3) != 0) {
        return ROUTE_UNKNOWN;
    }
    uint16_t i = 4;
    while (i < len && buf[i] == ' ') i++;

    if (i >= len) {
        return ROUTE_UNKNOWN;
    }
    uint16_t start = i;
    while (i < len && buf[i] != ' ' && buf[i] != '?' && buf[i] != '\r') i++;
    uint16_t path_len = i - start;

    if (path_len == 1 && buf[start] == '/') {
        return ROUTE_ROOT;
    }
    if (path_len == sizeof(status_path) - 1 &&
        memcmp(buf + start, status_path, path_len) == 0) {
        return ROUTE_STATUS;
    }
    if (path_len == sizeof(analog_path) - 1 &&
        memcmp(buf + start, analog_path, path_len) == 0) {
        return ROUTE_ANALOG;
    }
    return ROUTE_UNKNOWN;
}

/* ===========================================================================
 * Generacion de JSON
 * =========================================================================== */

static int build_status_body(char *dst, size_t cap) {
    const unsigned long uptime = (unsigned long)http_server_get_uptime_seconds();

    if (g_rssi == HTTP_RSSI_UNKNOWN) {
        return snprintf(dst, cap,
                        "{\"device\":\"%s\",\"connected\":true,"
                        "\"ip\":\"%s\",\"uptime\":%lu}",
                        DEVICE_NAME, http_server_get_ip_str(), uptime);
    }
    return snprintf(dst, cap,
                    "{\"device\":\"%s\",\"connected\":true,"
                    "\"ip\":\"%s\",\"uptime\":%lu,\"wifi_rssi\":%d}",
                    DEVICE_NAME, http_server_get_ip_str(), uptime, (int)g_rssi);
}

static int build_analog_body(char *dst, size_t cap) {
    const unsigned long ts = (unsigned long)http_server_get_epoch_seconds();
    int n = 0;

    if (g_reading == NULL) {
        n = snprintf(dst, cap, "{\"timestamp\":%lu,\"channels\":[]}", ts);
        return n;
    }

    /* Valores por canal (mismo orden que adc_reader) */
    const uint16_t raws[HTTP_CHANNEL_COUNT] = {
        g_reading->raw_ch0, g_reading->raw_ch1, g_reading->raw_ch2,
    };
    const float mvs[HTTP_CHANNEL_COUNT] = {
        g_reading->voltage_ch0, g_reading->voltage_ch1, g_reading->voltage_ch2,
    };

    n += snprintf(dst + n, cap - n, "{\"timestamp\":%lu,\"channels\":[", ts);
    for (uint i = 0; i < HTTP_CHANNEL_COUNT; i++) {
        n += snprintf(dst + n, cap - n,
                      "%s{\"channel\":%u,\"gpio\":%u,\"raw\":%u,"
                      "\"voltage\":%.3f}",
                      (i > 0) ? "," : "", i,
                      (unsigned)HTTP_CHANNEL_GPIOS[i],
                      (unsigned)raws[i],
                      (double)(mvs[i] / 1000.0f));
    }
    n += snprintf(dst + n, cap - n, "]}");
    return n;
}

/* ===========================================================================
 * Manejo de una peticion completa
 * =========================================================================== */

static err_t http_handle_request(HttpConn *c) {
    const char *scode = "200 OK";
    const char *ctype = "application/json";
    int blen = 0;

    switch (parse_route(c->buf, c->len)) {
        case ROUTE_STATUS:
            blen = build_status_body(g_body, sizeof(g_body));
            break;
        case ROUTE_ANALOG:
            blen = build_analog_body(g_body, sizeof(g_body));
            break;
        case ROUTE_ROOT:
            ctype = "text/plain; charset=utf-8";
            blen = snprintf(g_body, sizeof(g_body),
                            "Analog Pico Monitor\n"
                            "API disponible: GET /api/status, GET /api/analog\n");
            break;
        case ROUTE_UNKNOWN:
        default:
            scode = "404 Not Found";
            blen = snprintf(g_body, sizeof(g_body), "{\"error\":\"not found\"}");
            break;
    }

    int hlen = snprintf(g_response, sizeof(g_response),
                        "HTTP/1.1 %s\r\n"
                        "Content-Type: %s\r\n"
                        "Content-Length: %d\r\n"
                        "Cache-Control: no-store\r\n"
                        "Connection: close\r\n"
                        "\r\n",
                        scode, ctype, blen);
    memcpy(g_response + hlen, g_body, (size_t)blen);

    c->write_total = (uint16_t)(hlen + blen);
    c->acked = 0;

    err_t err = tcp_write(c->pcb, g_response, c->write_total, TCP_WRITE_FLAG_COPY);
    if (err != ERR_OK) {
        return err;
    }
    return tcp_output(c->pcb);
}

/* ===========================================================================
 * Callbacks TCP de lwIP
 * =========================================================================== */

static err_t http_recv(void *arg, struct tcp_pcb *pcb, struct pbuf *p, err_t err) {
    HttpConn *c = (HttpConn *)arg;

    if (err != ERR_OK) {
        if (p != NULL) {
            pbuf_free(p);
        }
        http_close_conn(c);
        return ERR_OK;
    }
    if (p == NULL) {
        /* Cliente cerro la conexion */
        http_close_conn(c);
        return ERR_OK;
    }

    if (p->tot_len > 0 && c->len < (uint16_t)sizeof(c->buf)) {
        const uint16_t left = (uint16_t)sizeof(c->buf) - c->len;
        const uint16_t copy = (p->tot_len > left) ? left : (uint16_t)p->tot_len;
        c->len = (uint16_t)(c->len + pbuf_copy_partial(p, c->buf + c->len, copy, 0));
        tcp_recved(pcb, p->tot_len);
    }
    pbuf_free(p);

    if (!c->response_pending && buffer_has_headers_end(c->buf, c->len)) {
        c->response_pending = true;
        if (http_handle_request(c) != ERR_OK) {
            http_close_conn(c);
        }
    }
    return ERR_OK;
}

static err_t http_accept(void *arg, struct tcp_pcb *client_pcb, err_t err) {
    (void)arg;
    if (err != ERR_OK || client_pcb == NULL) {
        return ERR_VAL;
    }

    HttpConn *free_slot = NULL;
    for (uint i = 0; i < HTTP_MAX_CLIENTS; i++) {
        if (!g_conns[i].in_use) {
            free_slot = &g_conns[i];
            break;
        }
    }
    if (free_slot == NULL) {
        /* Sin slots libres: rechazamos esta conexion */
        tcp_abort(client_pcb);
        return ERR_ABRT;
    }

    free_slot->pcb = client_pcb;
    free_slot->in_use = true;
    free_slot->len = 0;
    free_slot->response_pending = false;
    free_slot->write_total = 0;
    free_slot->acked = 0;

    tcp_arg(client_pcb, free_slot);
    tcp_recv(client_pcb, http_recv);
    tcp_sent(client_pcb, http_sent);
    tcp_poll(client_pcb, http_poll_client, HTTP_POLL_INTERVAL_S);
    tcp_err(client_pcb, http_err);
    tcp_nagle_disable(client_pcb);
    return ERR_OK;
}

/* ===========================================================================
 * API publica
 * =========================================================================== */

int http_server_init(void) {
    g_boot_ms = now_ms();

    struct tcp_pcb *pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
    if (pcb == NULL) {
        return -1;
    }
    err_t err = tcp_bind(pcb, NULL, HTTP_PORT);
    if (err != ERR_OK) {
        tcp_close(pcb);
        return -1;
    }
    g_listen_pcb = tcp_listen_with_backlog(pcb, (u8_t)HTTP_MAX_CLIENTS);
    if (g_listen_pcb == NULL) {
        tcp_close(pcb);
        return -1;
    }
    tcp_arg(g_listen_pcb, NULL);
    tcp_accept(g_listen_pcb, http_accept);
    return 0;
}

void http_server_poll(void) {
    cyw43_arch_poll();
}

void http_server_set_reading(const AdcReading *reading) {
    g_reading = reading;
}

void http_server_set_rssi(int32_t rssi_dbm) {
    g_rssi = rssi_dbm;
}

const char *http_server_get_ip_str(void) {
    static char ip_buf[16];
    if (netif_default != NULL) {
        ip4addr_ntoa_r(netif_ip4_addr(netif_default), ip_buf, sizeof(ip_buf));
    } else {
        snprintf(ip_buf, sizeof(ip_buf), "0.0.0.0");
    }
    return ip_buf;
}

uint32_t http_server_get_client_count(void) {
    uint32_t count = 0;
    for (uint i = 0; i < HTTP_MAX_CLIENTS; i++) {
        if (g_conns[i].in_use) {
            count++;
        }
    }
    return count;
}

uint32_t http_server_get_uptime_seconds(void) {
    return (now_ms() - g_boot_ms) / 1000u;
}

/* ---------------------------------------------------------------------------
 * SNTP: la hora la recibe el cliente NTP de lwIP y la deposita aqui mediante
 * el callback sntp_store_system_time() (definido en lwipopts.h). Con la base
 * (epoch) + el contador de ticks mantenemos una hora continua y estable.
 * ------------------------------------------------------------------------- */
#if ENABLE_SNTP
static volatile uint32_t g_epoch_base_sec = 0;
static uint32_t g_epoch_base_ms = 0;
static volatile bool g_time_synced = false;
#endif

extern "C" void sntp_store_system_time(uint32_t sec) {
#if ENABLE_SNTP
    g_epoch_base_sec = sec;
    g_epoch_base_ms = now_ms();
    g_time_synced = true;
#endif
}

uint32_t http_server_get_epoch_seconds(void) {
#if ENABLE_SNTP
    if (g_time_synced) {
        return g_epoch_base_sec + (now_ms() - g_epoch_base_ms) / 1000u;
    }
#else
    (void)0;
#endif
    /* Sin reloj sincronizado: respaldamos con el uptime (segundos desde el
     * arranque). La app conserva el orden y las frecuencias correctas. */
    return http_server_get_uptime_seconds();
}

bool http_server_is_time_synced(void) {
#if ENABLE_SNTP
    return g_time_synced;
#else
    return false;
#endif
}