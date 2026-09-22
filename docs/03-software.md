# 03 - Estructura del Software (C++)

## Arquitectura de Modulos

El firmware esta organizado en 3 modulos independientes con responsabilidades
claramente definidas:

```
+------------------+     +------------------+     +------------------+
|   wifi_config.h  |     |   adc_reader     |     |   tcp_server     |
|                  |     |   .h / .cpp      |     |   .h / .cpp      |
| - SSID           |     |                  |     |                  |
| - Password       |     | - adc_reader_init|     | - tcp_server_init|
| - TCP port       |     | - adc_reader_read|     | - tcp_server_poll|
| - Intervalo      |     | - get_vref       |     | - send_data      |
| - Oversampling   |     | - raw_to_mV      |     | - get_client_cnt |
+------------------+     +------------------+     | - get_ip_str     |
         |                      |                 +------------------+
         |                      |                        |
         +----------------------+------------------------+
                                |
                          main.cpp
                         (punto de entrada)
```

## Descripcion de Modulos

### 1. `wifi_config.h` - Configuracion

Archivo de unicamente definiciones (`#define`) que el usuario edita
antes de compilar. Contiene:

- Credenciales WiFi (SSID y password)
- Puerto TCP del servidor
- Intervalo de muestreo del ADC
- Cantidad de muestras para oversampling
- Timeout de conexion WiFi

**No tiene implementacion** - solo cabecera con macros.

### 2. `adc_reader.h` / `adc_reader.cpp` - Lector ADC

Responsabilidad: Leer los canales analogicos y convertirlos a voltajes.

**API publica:**

```cpp
// Inicializar hardware ADC (llamar una vez al inicio)
void adc_reader_init(void);

// Leer todos los canales y almacenar en la estructura
void adc_reader_read(AdcReading *reading);

// Obtener voltaje de referencia (3300 mV)
float adc_reader_get_vref(void);

// Convertir valor crudo a milivoltios
float adc_reader_raw_to_millivolts(uint16_t raw_value);
```

**Estructura de datos:**

```cpp
struct AdcReading {
    float    voltage_ch0;    // Voltaje canal 0 en mV (GPIO 26)
    float    voltage_ch1;    // Voltaje canal 1 en mV (GPIO 27)
    float    voltage_ch2;    // Voltaje canal 2 en mV (GPIO 28)
    uint16_t raw_ch0;        // Valor crudo ADC canal 0 (0-4095)
    uint16_t raw_ch1;        // Valor crudo ADC canal 1 (0-4095)
    uint16_t raw_ch2;        // Valor crudo ADC canal 2 (0-4095)
    float    temperature;    // Temperatura interna del chip en °C
    uint32_t timestamp;      // Milisegundos desde el arranque
};
```

**Flujo interno de `adc_reader_read()`:**

```
1. Para cada canal (0, 1, 2):
   a. Seleccionar canal con adc_select_input()
   b. Leer ADC_OVERSAMPLE_COUNT veces
   c. Acumular valores crudos
2. Calcular promedio por canal
3. Convertir a milivoltios: (raw_avg / 4095) * 3300
4. Leer sensor de temperatura interno (canal 4)
5. Convertir temperatura: 27 - (V - 0.706) / 0.001721
6. Registrar timestamp con time_us_64()
```

### 3. `tcp_server.h` / `tcp_server.cpp` - Servidor TCP

Responsabilidad: Gestionar conexiones de red y enviar datos a clientes.

**API publica:**

```cpp
// Inicializar servidor TCP en el puerto configurado
int tcp_server_init(void);

// Mantener el driver WiFi y lwIP activos (llamar en loop)
void tcp_server_poll(void);

// Enviar medicion ADC a todos los clientes conectados
void tcp_server_send_data(const AdcReading *reading);

// Obtener numero de clientes conectados
uint32_t tcp_server_get_client_count(void);

// Obtener IP del Pico W como string "x.x.x.x"
const char* tcp_server_get_ip_str(void);
```

**Flujo interno:**

```
tcp_server_init():
  1. tcp_new_ip_type()     -> Crear PCB TCP
  2. tcp_bind()            -> Vincular al puerto 5000
  3. tcp_listen()          -> Poner en modo escucha
  4. tcp_accept()          -> Registrar callback de aceptacion

Callback de aceptacion (on_accept):
  1. Crear estado para el nuevo cliente
  2. Registrar callbacks: recv, err, poll, sent
  3. Agregar cliente a la lista

Callback de recepcion (on_recv):
  - Si p == NULL: cliente cerró conexion
  - Si hay datos: procesar comandos del cliente (reservado)

tcp_server_send_data():
  1. Formatear JSON con los valores del ADC
  2. Para cada cliente conectado:
     a. tcp_write() con TCP_WRITE_FLAG_COPY
     b. tcp_output() para forzar envio inmediato

tcp_server_poll():
  1. cyw43_arch_poll()  -> Servicio del driver WiFi
```

### 4. `main.cpp` - Punto de Entrada

Responsabilidad: Orquestar la inicializacion y el loop principal.

**Flujo de ejecucion:**

```
main():
  1. stdio_init_all()          -> Inicializar UART/USB para printf
  2. adc_reader_init()         -> Inicializar hardware ADC
  3. wifi_connect()            -> Conectar a WiFi (bloqueante)
  4. tcp_server_init()         -> Iniciar servidor TCP
  5. printf(IP del Pico)       -> Mostrar IP en serial

  LOOP:
    while (true):
      1. tcp_server_poll()        -> Mantener red activa
      2. adc_reader_read()        -> Leer canales ADC
      3. tcp_server_send_data()   -> Enviar a clientes
      4. sleep_ms(intervalo)      -> Esperar siguiente ciclo
```

## Dependencias del SDK

| Libreria | Proposito | Uso en el proyecto |
|----------|-----------|-------------------|
| `pico_stdlib` | Abstracciones generales | GPIO, sleep, printf, time |
| `hardware_adc` | Driver del ADC | adc_init, adc_read, adc_select_input |
| `pico_cyw43_arch_lwip_poll` | WiFi + TCP/IP | cyw43_arch_init, cyw43_arch_poll |
| `lwip` (RAW API) | Stack TCP/IP | tcp_new, tcp_bind, tcp_listen, tcp_write |

## Convenciones de Codigo

- **Nomenclatura:** snake_case para funciones y variables (`adc_reader_read`)
- **Prefijos:** Cada funcion empieza con el nombre del modulo (`adc_reader_*`, `tcp_server_*`)
- **Estructuras:** PascalCase (`AdcReading`)
- **Constantes:** UPPER_SNAKE_CASE con `static const` (`ADC_VREF_MV`)
- **Comentarios:** Blocos `/** ... */` en cabeceras, lineas `/* ... */` en .cpp
- **Includes:** Propios primero, luego SDK, luego estandar
- **Encoding:** UTF-8 con acentos en comentarios
