/**
 * =============================================================================
 * wifi_config.h - Configuracion de credenciales WiFi
 * =============================================================================
 *
 * INSTRUCCIONES:
 *   Edita los valores WIFI_SSID y WIFI_PASSWORD con los datos de tu red WiFi.
 *   Estas credenciales se usan para conectar la Pico W en modo Station (STA).
 *
 * NOTA DE SEGURIDAD:
 *   Este archivo contiene credenciales en texto plano. No lo subas a repositorios
 *   publicos. Puedes usar un archivo .gitignore para excluirlo.
 *
 * COMPATIBILIDAD:
 *   - Protocolos soportados: WPA2-PSK (AES), WPA/WPA2-mixed
 *   - El Pico W se conecta como cliente (estacion) al punto de acceso existente
 * =============================================================================
 */

#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

/* ===========================================================================
 * CREDENCIALES WiFi
 * ===========================================================================
 * Cambia estos valores por los de tu red doméstica o de laboratorio.
 * Si tu red no tiene contraseña, deja WIFI_PASSWORD como NULL.
 * =========================================================================== */

// Nombre de la red WiFi (SSID) - maximo 32 caracteres
#define WIFI_SSID       "TU_SSID_AQUI"

// Contrasena de la WiFi - minimo 8 caracteres para WPA2, o NULL si es abierta
#define WIFI_PASSWORD   "TU_PASSWORD_AQUI"

/* ===========================================================================
 * CONFIGURACION DE LA RED
 * =========================================================================== */

// Puerto TCP en el que el servidor escucha conexiones
// La app Flutter se conectara a <IP_del_pico>:<TCP_PORT>
#define TCP_PORT        5000

// Intervalo de muestreo del ADC en milisegundos
// Valores recomendados: 100 (10 Hz) a 5000 (0.2 Hz)
#define ADC_SAMPLE_INTERVAL_MS  1000

// Numero de lecturas ADC a promediar por canal (para reducir ruido)
// Valores: 1 a 100. Mas muestras = mas precision pero mas lento.
#define ADC_OVERSAMPLE_COUNT    16

// Tiempo maximo de conexion WiFi en milisegundos
#define WIFI_CONNECT_TIMEOUT_MS 30000

#endif /* WIFI_CONFIG_H */
