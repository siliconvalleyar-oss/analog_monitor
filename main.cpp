/**
 * =============================================================================
 * main.cpp - Punto de entrada del firmware Analog Pico Monitor
 * =============================================================================
 *
 * Orquesta los modulos del firmware:
 *   1. Inicializa el ADC (adc_reader_init).
 *   2. Conecta la Pico W a la red WiFi (Station mode).
 *   3. Arranca el cliente SNTP (opcional) para obtener el epoch.
 *   4. Inicia el servidor HTTP (http_server_init) en HTTP_PORT.
 *   5. En el loop principal lee el ADC periodicamente y mantiene viva la pila
 *      WiFi/lwIP con http_server_poll() (modo poll, sin threads).
 *
 * Cada N ms (ADC_SAMPLE_INTERVAL_MS) se actualiza g_reading con la ultima
 * medicion; el servidor HTTP la ofrece en GET /api/analog. Cada ~5 s se
 * refresca tambien el RSSI (se muestra en GET /api/status).
 * =============================================================================
 */

#include <cstdio>

#include "wifi_config.h"

#include "lwip/netif.h"
#include "pico/cyw43_arch.h"
#include "pico/stdlib.h"

#if ENABLE_SNTP
#include "lwip/apps/sntp.h"
#endif

#include "adc_reader.h"
#include "http_server.h"

/* Ultima medicion del ADC (el servidor HTTP la lee para responder /api/analog) */
static AdcReading g_reading;

/* RSSI cacheado: se lee del chip cada ~5 s para no bloquear el bus WiFi
 * dentro de los callbacks de red. */
static int32_t g_rssi = HTTP_RSSI_UNKNOWN;
static uint32_t g_last_rssi_ms = 0;

int main(void) {
    stdio_init_all();
    adc_reader_init();

    printf("\n=== Analog Pico Monitor (firmware) ===\n");

    /* 1. WiFi ------------------------------------------------------ */
    if (cyw43_arch_init()) {
        printf("ERROR: no se pudo inicializar el chip WiFi (CYW43)\n");
        return 1;
    }
    cyw43_arch_enable_sta_mode();

    printf("Conectando a WiFi '%s'...\n", WIFI_SSID);
    if (cyw43_arch_wifi_connect_timeout_ms(
            WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK,
            WIFI_CONNECT_TIMEOUT_MS)) {
        printf("ERROR: no se pudo conectar a la red WiFi\n");
        return 1;
    }
    printf("WiFi conectado. IP: %s\n", http_server_get_ip_str());

    /* LED del Pico W encendido = conectado */
    cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);

    /* 2. SNTP (hora real para el campo "timestamp") ----------------- */
#if ENABLE_SNTP
    printf("Arrancando SNTP (servidor: %s)...\n", SNTP_SERVER);
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    sntp_setservername(0, SNTP_SERVER);
    sntp_init();
    printf("SNTP iniciado (se sincronizara en breve si hay acceso a la red)\n");
#endif

    /* 3. Servidor HTTP ---------------------------------------------- */
    http_server_set_reading(&g_reading);
    if (http_server_init() != 0) {
        printf("ERROR: no se pudo iniciar el servidor HTTP\n");
        return 1;
    }
    printf("Servidor HTTP escuchando en http://%s:%d\n",
           http_server_get_ip_str(), HTTP_PORT);
    printf("Endpoints: GET /api/status   GET /api/analog\n");

    /* 4. Loop principal --------------------------------------------- */
    while (true) {
        /* Mantiene vivas las conexiones (WiFi + lwIP + timers DHCP/SNTP).
         * Obligatorio en modo poll. */
        http_server_poll();

        /* Lee todos los canales ADC y actualiza la medicion en curso */
        adc_reader_read(&g_reading);

        /* Cada ~5 s se refresca el RSSI para /api/status */
        const uint32_t now = to_ms_since_boot(get_absolute_time());
        if (now - g_last_rssi_ms >= 5000u) {
            g_last_rssi_ms = now;
            if (cyw43_wifi_get_rssi(&cyw43_state, &g_rssi) != 0) {
                g_rssi = HTTP_RSSI_UNKNOWN;
            }
            http_server_set_rssi(g_rssi);
        }

        sleep_ms(ADC_SAMPLE_INTERVAL_MS);
    }
}