/**
 * =============================================================================
 * http_server.h - Servidor HTTP para la API REST de mediciones ADC
 * =============================================================================
 *
 * Este modulo implementa un servidor HTTP embebido (sobre lwIP RAW API, modo
 * poll) que expone la API REST que consume la aplicacion Analog Pico Monitor
 * (Flutter):
 *
 *   GET /api/status   -> estado del dispositivo
 *   GET /api/analog   -> mediciones analogicas del ADC
 *
 * ARQUITECTURA lwIP (NO_SYS):
 *   No hay threads: todo el procesamiento de red ocurre en el contexto de la
 *   funcion de escucha principal. http_server_poll() debe llamarse
 *   periodicamente en el loop principal; internamente llama a cyw43_arch_poll()
 *   para mantener el driver WiFi y lwIP (incluidos los timers de DHCP/SNTP).
 *
 * CONTRATO JSON (idem README de la app Flutter):
 *
 *   GET /api/status
 *   {
 *     "device": "Raspberry Pi Pico W",
 *     "connected": true,
 *     "ip": "192.168.1.100",
 *     "uptime": 12345,
 *     "wifi_rssi": -55
 *   }
 *
 *   GET /api/analog
 *   {
 *     "timestamp": 1698000000,
 *     "channels": [
 *       { "channel": 0, "gpio": 26, "raw": 2048, "voltage": 1.65 },
 *       { "channel": 1, "gpio": 27, "raw": 3000, "voltage": 2.42 },
 *       { "channel": 2, "gpio": 28, "raw": 1024, "voltage": 0.83 }
 *     ]
 *   }
 *
 * Cada respuesta se envia en una sola conexion y se cierra (Connection: close),
 * de modo que nunca quedan sockets colgados y la app puede abrir conexiones
 * nuevas en cada poll.
 * =============================================================================
 */

#ifndef HTTP_SERVER_H
#define HTTP_SERVER_H

#include <cstdint>

#include "adc_reader.h"

/* Numero maximo de clientes atendidos de forma simultanea */
#define HTTP_MAX_CLIENTS 8

/**
 * Inicializa el servidor HTTP y lo pone a escuchar en HTTP_PORT.
 *
 * Pasos realizados:
 *   1. Crea un PCB TCP con tcp_new_ip_type(IPADDR_TYPE_ANY)
 *   2. Lo vincula al puerto HTTP_PORT con tcp_bind()
 *   3. Lo pone en modo escucha con tcp_listen_with_backlog()
 *   4. Registra el callback de aceptacion de conexiones
 *
 * @return 0 si la inicializacion fue exitosa, -1 en caso de error
 *         (sin memoria o puerto en uso).
 */
int http_server_init(void);

/**
 * Mantiene la pila WiFi/lwIP activa. Debe llamarse periodicamente desde el
 * loop principal.
 *
 * Internamente llama a cyw43_arch_poll(), que procesa:
 *   - eventos del driver CYW43 (WiFi)
 *   - eventos pendientes de lwIP (TCP, DHCP, timers de SNTP)
 *
 * IMPORTANTE (modo poll): si no se llama a esta funcion, la red se congela.
 */
void http_server_poll(void);

/**
 * Registra el puntero a la estructura con la ultima medicion ADC.
 *
 * main.cpp actualiza dicha estructura en cada ciclo de muestreo; el servidor
 * la lee para componer la respuesta de /api/analog. Como en modo poll todo el
 * procesamiento ocurre en un unico hilo, leerla desde los callbacks de lwIP
 * es seguro.
 *
 * @param reading Puntero a un AdcReading con vida util permanente
 *                (p. ej. una variable global de main).
 */
void http_server_set_reading(const AdcReading *reading);

/**
 * Registra la intensidad de senal WiFi (RSSI) que main cachea periodicamente.
 *
 * Como leer el RSSI puede bloquear brevemente el bus del CYW43, main lo
 * consulta cada pocos segundos en el loop principal y lo entrega aqui; el
 * servidor lo incluye en /api/status (campo "wifi_rssi", opcional).
 *
 * @param rssi_dbm Intensidad en dBm (negativa). 0 o HTTP_RSSI_UNKNOWN = omitir.
 */
void http_server_set_rssi(int32_t rssi_dbm);

/** Indica que el servidor no tiene un valor de RSSI valido. */
#define HTTP_RSSI_UNKNOWN 127

/**
 * Retorna la IP local del Pico W como string "x.x.x.x".
 * Util para mostrar en serial o para depurar.
 *
 * @return Puntero a buffer estatico con la IP (no liberar).
 */
const char *http_server_get_ip_str(void);

/**
 * Retorna el numero de clientes conectados actualmente.
 *
 * @return Numero de conexiones activas (0 a HTTP_MAX_CLIENTS).
 */
uint32_t http_server_get_client_count(void);

/**
 * Retorna el tiempo transcurrido desde el arranque en segundos.
 *
 * @return Segundos desde el boot.
 */
uint32_t http_server_get_uptime_seconds(void);

/**
 * Retorna la marca de tiempo para el campo "timestamp" de /api/analog.
 *
 * Si ENABLE_SNTP esta activo y el reloj fue sincronizado, devuelve el epoch
 * (segundos desde 1970-01-01). Si no hay tiempo sincronizado, devuelve los
 * segundos desde el arranque (asi el historial de la app mantiene orden y
 * frecuencias correctas).
 *
 * @return Epoch en segundos (o uptime como respaldo).
 */
uint32_t http_server_get_epoch_seconds(void);

/**
 * Retorna true si el reloj SNTP fue sincronizado.
 */
bool http_server_is_time_synced(void);

#endif /* HTTP_SERVER_H */