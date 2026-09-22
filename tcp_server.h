/**
 * =============================================================================
 * tcp_server.h - Servidor TCP para transmision de datos ADC
 * =============================================================================
 *
 * Este modulo implementa un servidor TCP que acepta conexiones de clientes
 * (como una app Flutter) y envia periodicamente las mediciones ADC en
 * formato JSON legible.
 *
 * PROTOCOLO DE COMUNICACION:
 *   - Transporte: TCP sobre IPv4
 *   - Puerto: configurable (default: 5000, ver TCP_PORT en wifi_config.h)
 *   - Formato de datos: JSON + newline (\n) como delimitador
 *   - Direccion: El servidor escucha, el cliente se conecta
 *
 * FORMATO JSON ENVIADO:
 *   {
 *     "ch0_mv": 1650.5,
 *     "ch1_mv": 330.2,
 *     "ch2_mv": 0.0,
 *     "ch0_raw": 2048,
 *     "ch1_raw": 409,
 *     "ch2_raw": 0,
 *     "temp_c": 42.5,
 *     "ts_ms": 12345678
 *   }
 *
 * NOTA: Cada mensaje JSON termina con '\n' (newline) para que el cliente
 * pueda delimitar los mensajes facilmente usando readline() o split('\n').
 *
 * CONEXION DESDE FLUTTER:
 *   1. La app Flutter descubre la IP del Pico W (via mDNS o configuracion)
 *   2. Abre un socket TCP al puerto TCP_PORT
 *   3. Recibe stream de lineas JSON
 *   4. Parsea cada linea como un objeto JSON
 *   5. Actualiza la interfaz con los valores de voltaje y temperatura
 *
 * ARQUITECTURA lwIP:
 *   Este servidor usa la API RAW de lwIP (NO_SYS=1 mode), lo cual
 *   significa que todo el procesamiento de red ocurre en el contexto
 *   del calling thread principal. No hay threads separados para red.
 *
 *   El flujo es:
 *     1. main() llama a tcp_server_init() para crear el PCB de escucha
 *     2. En el loop principal, se llama a tcp_server_poll() que:
 *        a. Llama a cyw43_arch_poll() para mantener el driver WiFi
 *        b. Procesa eventos pendientes de lwIP
 *        c. Si hay datos nuevos del ADC, los envia a todos los clientes
 * =============================================================================
 */

#ifndef TCP_SERVER_H
#define TCP_SERVER_H

#include "adc_reader.h"

/**
 * Inicializa el servidor TCP y lo pone en modo escucha.
 *
 * Pasos realizados:
 *   1. Crea un nuevo Protocol Control Block (PCB) TCP con tcp_new_ip_type()
 *   2. Vincula el PCB al puerto TCP_PORT con tcp_bind()
 *   3. Pone el PCB en modo escucha con tcp_listen()
 *   4. Registra la funcion de callback para aceptar conexiones
 *
 * @return 0 si la inicializacion fue exitosa, -1 en caso de error.
 *
 * Errores posibles:
 *   - No se pudo crear el PCB (memoria agotada)
 *   - No se pudo vincular al puerto (puerto en uso)
 *
 * Nota: Esta funcion no bloquea. El servidor esta listo para aceptar
 * conexiones inmediatamente despues de retorna.
 */
int tcp_server_init(void);

/**
 * Funcion de polling del servidor TCP. Debe llamarse periodicamente
 * desde el loop principal (junto con cyw43_arch_poll()).
 *
 * Funciones realizadas:
 *   1. Llama a cyw43_arch_poll() para mantener el driver CYW43 y lwIP
 *   2. No hace nada adicional (el envio se maneja via callbacks lwIP)
 *
 * IMPORTANTE: En modo poll (NO_SYS=1), lwIP no tiene su propio thread.
 * Si no se llama a esta funcion periodicamente, la pila de red se congela
 * y las conexiones TCP se cortaran.
 */
void tcp_server_poll(void);

/**
 * Envia los datos de una medicion ADC a todos los clientes conectados.
 *
 * Formato: Una linea JSON terminada en '\n':
 *   {"ch0_mv":1650.5,"ch1_mv":330.2,...}\n
 *
 * @param reading Puntero a la estructura con los datos a enviar.
 *
 * Comportamiento:
 *   - Si no hay clientes conectados, la funcion no hace nada
 *   - Si hay multiples clientes, envia a todos
 *   - Si un envio falla (cliente desconectado), ese cliente se descarta
 *   - Los datos se copian al buffer TCP (TCP_WRITE_FLAG_COPY)
 *
 * Nota: Esta funcion puede ser llamada desde cualquier contexto, pero
 * los datos solo se transmiten cuando lwIP procesa los eventos pendientes
 * (en la proxima llamada a tcp_server_poll()).
 */
void tcp_server_send_data(const AdcReading *reading);

/**
 * Retorna el numero de clientes actualmente conectados al servidor.
 *
 * @return Numero de clientes conectados (0, 1, o mas).
 */
uint32_t tcp_server_get_client_count(void);

/**
 * Retorna la IP local del Pico W en formato string "x.x.x.x".
 * Util para mostrar en pantalla OLED o para que la app Flutter
 * sepa a que IP conectarse.
 *
 * @return Puntero a string estatico con la IP (no liberar).
 */
const char* tcp_server_get_ip_str(void);

#endif /* TCP_SERVER_H */
