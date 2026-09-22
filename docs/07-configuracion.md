# 07 - Configuracion del Sistema

Todos los parametros configurables se encuentran en el archivo
`src/analog/wifi_config.h`. Deben editarse **antes** de compilar.

## WiFi

```c
#define WIFI_SSID       "TU_SSID_AQUI"
#define WIFI_PASSWORD   "TU_PASSWORD_AQUI"
```

| Parametro | Tipo | Max | Default | Descripcion |
|-----------|------|-----|---------|-------------|
| `WIFI_SSID` | string | 32 chars | `TU_SSID_AQUI` | Nombre de la red WiFi |
| `WIFI_PASSWORD` | string | 63 chars / NULL | `TU_PASSWORD_AQUI` | Contrasena WiFi (NULL si abierta) |

### Protocolos Soportados

| Protocolo | Constante SDK | Soportado |
|-----------|--------------|-----------|
| WPA2-PSK (AES) | `CYW43_AUTH_WPA2_AES_PSK` | Si (recomendado) |
| WPA/WPA2-mixed | `CYW43_AUTH_WPA2_MIXED_PSK` | Si |
| WPA-PSK (TKIP) | `CYW43_AUTH_WPA_TKIP_PSK` | Si (no recomendado) |
| WEP | - | No |
| Abierto | NULL | Si |

### Notas de Seguridad

- **WPA2-PSK (AES)** es el protocolo mas seguro y recomendado
- Las credenciales estan en texto plano en el codigo fuente
- No subir `wifi_config.h` a repositorios publicos
- Usar `.gitignore` para excluir este archivo

## Red

```c
#define TCP_PORT        5000
```

| Parametro | Tipo | Rango | Default | Descripcion |
|-----------|------|-------|---------|-------------|
| `TCP_PORT` | int | 1-65535 | 5000 | Puerto TCP del servidor |

### Puertos Recomendados

| Puerto | Uso | Recomendado |
|--------|-----|-------------|
| 5000 | Desarrollo y pruebas | Si |
| 8080 | HTTP alternativo | No |
| 80 | HTTP estandar | No (requiere root en Linux) |
| 50000+ | Puertos efimeros | Si (para evitar conflictos) |

**NOTA:** Evitar puertos menores a 1024 (requieren privilegios elevados
en algunos sistemas operativos).

## ADC (Converter Analogico-Digital)

```c
#define ADC_SAMPLE_INTERVAL_MS  1000
#define ADC_OVERSAMPLE_COUNT    16
```

| Parametro | Tipo | Rango | Default | Descripcion |
|-----------|------|-------|---------|-------------|
| `ADC_SAMPLE_INTERVAL_MS` | int | 100-10000 | 1000 | Intervalo entre muestreos (ms) |
| `ADC_OVERSAMPLE_COUNT` | int | 1-100 | 16 | Muestras por canal por ciclo |

### Frecuencia de Muestreo

| Intervalo (ms) | Frecuencia | Uso Recomendado |
|----------------|-----------|-----------------|
| 100 | 10 Hz | Senales rapidas (vibracion, audio) |
| 200 | 5 Hz | Senales moderadas (potenciometros) |
| 500 | 2 Hz | Senales lentas (temperatura, luz) |
| 1000 | 1 Hz | Default, monitoreo general |
| 2000 | 0.5 Hz | Bateria, ambiente |
| 5000 | 0.2 Hz | Ahorro de energia |

### Oversampling

El oversampling promedia N muestras para reducir el ruido:

| Muestras | Reduccion de ruido | Tiempo por canal | Precision extra |
|----------|-------------------|-----------------|-----------------|
| 1 | 1.0x (sin cambio) | ~2 us | 0 bits |
| 4 | 2.0x | ~8 us | +1 bit |
| 16 | 4.0x (default) | ~32 us | +2 bits |
| 64 | 8.0x | ~128 us | +3 bits |
| 100 | 10.0x | ~200 us | +3.3 bits |

**Formula:** Precision extra = log2(sqrt(N)) bits

### Impacto en Performance

Con ADC_OVERSAMPLE_COUNT=16 y 3 canales:

```
Tiempo por ciclo = 3 canales * 16 muestras * ~2 us = ~96 us
Overhead por ciclo = ~0.1 ms (despreciable)
```

Incluso a 100 ms de intervalo, el ADC consume menos del 0.1% del tiempo.

## WiFi Timeout

```c
#define WIFI_CONNECT_TIMEOUT_MS 30000
```

| Parametro | Tipo | Rango | Default | Descripcion |
|-----------|------|-------|---------|-------------|
| `WIFI_CONNECT_TIMEOUT_MS` | int | 5000-120000 | 30000 | Maximo tiempo de conexion WiFi (ms) |

Si la conexion WiFi falla despues de este tiempo, el Pico W se reinicia
automaticamente e intenta conectarse de nuevo.

## Tabla Resumen de Configuracion

```c
/* === WIFI === */
#define WIFI_SSID               "MiRed"          // Nombre de red
#define WIFI_PASSWORD           "MiPass123"       // Contrasena

/* === RED === */
#define TCP_PORT                5000              // Puerto TCP

/* === ADC === */
#define ADC_SAMPLE_INTERVAL_MS  1000              // Frecuencia 1 Hz
#define ADC_OVERSAMPLE_COUNT    16                // 16 muestras promediadas

/* === SEGURIDAD === */
#define WIFI_CONNECT_TIMEOUT_MS 30000             // 30 segundos timeout
```

## Configuracion Avanzada (Requiere Modificar Codigo)

Estos parametros NO estan en `wifi_config.h` y requieren editar el
codigo fuente directamente:

| Parametro | Archivo | Default | Descripcion |
|-----------|---------|---------|-------------|
| VREF del ADC | `adc_reader.cpp` | 3300.0 mV | Voltaje de referencia |
| Max. clientes TCP | `tcp_server.cpp` | Ilimitado | Limite de conexiones simultaneas |
| Buffer TCP | `tcp_server.cpp` | 1024 bytes | Tamano del buffer de envio |
| Led de status | `main.cpp` | CYW43 LED | Pin del LED indicador |

### Cambiar el Voltaje de Referencia

Si se ha calibrado el ADC midiendo el voltaje real en un pin:

```cpp
// En adc_reader.cpp, cambiar:
static const float ADC_VREF_MV = 3300.0f;
// Por el valor medido, por ejemplo:
static const float ADC_VREF_MV = 3285.0f;  // Valor calibrado
```

### Cambiar el Puerto TCP

```c
// En wifi_config.h:
#define TCP_PORT 8080  // En lugar de 5000
```

Luego recompilar y flashear.
