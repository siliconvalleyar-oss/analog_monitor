/**
 * =============================================================================
 * wifi_config.h - Configuracion del firmware Analog Pico Monitor
 * =============================================================================
 *
 * INSTRUCCIONES:
 *   Edita los valores WIFI_SSID y WIFI_PASSWORD con los datos de tu red WiFi.
 *   Los demas parametros tienen valores por defecto razonables.
 *
 * NOTA DE SEGURIDAD:
 *   Este archivo contiene credenciales en texto plano. No lo subas a
 *   repositorios publicos (esta excluido con .gitignore.
 *
 * COMPATIBILIDAD DEL FIRMWARE:
 *   Firmware para Raspberry Pi Pico W (RP2040 + CYW43). Expone una API HTTP
 *   REST:
 *     GET /api/status   -> estado del dispositivo (IP, uptime, RSSI)
 *     GET /api/analog   -> mediciones analogicas (raw + voltaje)
 *   La aplicacion Analog Pico Monitor (Flutter) consume esta API por WiFi.
 * =============================================================================
 */

#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

/* ===========================================================================
 * CREDENCIALES WiFi
 * =========================================================================== */

// Nombre de la red WiFi (SSID) - maximo 32 caracteres
#define WIFI_SSID        "TU_SSID_AQUI"

// Contrasena de la WiFi - minimo 8 caracteres para WPA2, o NULL si es abierta
#define WIFI_PASSWORD    "TU_PASSWORD_AQUI"

// Tiempo maximo de espera para conectar a WiFi en milisegundos
#define WIFI_CONNECT_TIMEOUT_MS  30000

/* ===========================================================================
 * Servidor HTTP
 * =========================================================================== */

// Puerto HTTP en el que escucha el firmware.
// La app se conecta a http://<IP_del_pico>:<HTTP_PORT>/api/...
// Por defecto 80 (la app usa ese puerto por defecto).
#define HTTP_PORT        80

// Nombre del dispositivo que se reporta en GET /api/status (campo "device")
#define DEVICE_NAME      "Raspberry Pi Pico W"

/* ===========================================================================
 * Muestreo del ADC
 * =========================================================================== */

// Intervalo de muestreo del ADC en milisegundos (cuando se actualiza g_reading)
// Valores recomendados: 100 (10 Hz) a 5000 (0.2 Hz)
#define ADC_SAMPLE_INTERVAL_MS  1000

// Numero de lecturas ADC a promediar por canal (para reducir ruido)
// Valores: 1 a 100. Mas muestras = mas precision pero mas lento.
#define ADC_OVERSAMPLE_COUNT    16

/* ===========================================================================
 * Tiempo (epoch) para el campo "timestamp"
 * =========================================================================== */

// Habilita el cliente SNTP para obtener la hora real (epoch) y reportarla en
// /api/analog (campo "timestamp"). Si la red no tiene acceso a Internet, el
// firmware usa como alternativa los segundos transcurridos desde el arranque.
#define ENABLE_SNTP       1

// Servidor NTP (puede ser un hostname o una IP). Requiere ENABLE_SNTP.
#define SNTP_SERVER       "pool.ntp.org"

#endif /* WIFI_CONFIG_H */