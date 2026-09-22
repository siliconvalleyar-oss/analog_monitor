# 05 - Compilacion y flasheo

## Requisitos

- **Pico SDK v2.x** (por defecto se busca en `../pico-sdk` respecto al
  proyecto; se puede indicar con `-DPICO_SDK_PATH`).
- Toolchain **ARM GCC** (`arm-none-eabi-gcc`/`g++`).
- **CMake >= 3.13** (y `make` o `ninja`).
- La placa es una **Raspberry Pi Pico W** (los pines WiFi `CYW43` se
  habilitan con `PICO_BOARD=pico_w`, ya fijado en el `CMakeLists.txt`).

## Configurar credenciales

Edita `wifi_config.h`:

```c
#define WIFI_SSID            "TU_RED"
#define WIFI_PASSWORD        "TU_CLAVE"
#define WIFI_CONNECT_TIMEOUT_MS 30000
#define HTTP_PORT            80
#define ADC_SAMPLE_INTERVAL_MS 1000
#define ENABLE_SNTP          1
#define SNTP_SERVER          "pool.ntp.org"
```

> No subas credenciales reales a repositorios publicos: usa las de tu red
> local y revisa el archivo antes de hacer commit o push.

## Compilar

```bash
# en la raiz del firmware (rama analog_pico)
cmake -B build
cmake --build build

# si el SDK esta en otra ruta:
cmake -B build -DPICO_SDK_PATH=/ruta/al/pico-sdk
cmake --build build -j$(nproc)
```

Salidas en `build/`:

- `analog_monitor.uf2` -> para flashear por BOOTSEL
- `analog_monitor.elf` / `.bin` / `.hex` / `.dis` -> para depurar con picotool/gdb

## Flashear

1. Con la Pico W **desconectada**, pulsa **BOOTSEL** y conecta el USB.
2. La Pico aparece como un disco de masa (RPI-RP2).
3. Copia/arrastra `build/analog_monitor.uf2` al disco. Se reinicia sola.

Alternativa con `picotool`:

```bash
picotool load build/analog_monitor.uf2 -x
```

## Verificar en el arranque

Con un cable USB conectado, el firmware imprime por **USB CDC (printf)**:

```
=== Analog Pico Monitor (firmware) ===
Conectando a WiFi 'TU_RED'...
WiFi conectado. IP: 192.168.1.100
Arrancando SNTP (servidor: pool.ntp.org)...
Servidor HTTP escuchando en http://192.168.1.100:80
Endpoints: GET /api/status   GET /api/analog
```

Probar en un navegador o con `curl`:

```bash
curl http://192.168.1.100/api/status
curl http://192.168.1.100/api/analog
```

## Solucion de problemas (troubleshooting)

| Sintoma | Causa / solucion |
|---------|------------------|
| "no se pudo inicializar el chip WiFi" | Pico normal en vez de Pico W, o pines CYW43 mal conectados. |
| "no se pudo conectar a la red WiFi" | SSID/contraseña incorrectos, router sin WPA2, o AP fuera de alcance. Aumenta `WIFI_CONNECT_TIMEOUT_MS`. |
| La Pico no asigna IP | DHCP deshabilitado en el router; configura una IP fija. |
| `timestamp` muestra uptime en vez de hora | Sin salida a internet para NTP, o SNTP aun sincronizando. Espera unos segundos. |
| No responde `/api/analog` | Verifica que los GPIO 26-28 esten conectados y dentro de 0-3.3 V. |
| La app Flutter no encuentra la Pico | La IP cambiada (DHCP) o la Pico en otra red. La app permite escribir la IP (puerto 80 por defecto). |