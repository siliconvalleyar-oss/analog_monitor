# Analog Pico Monitor - Firmware (Raspberry Pi Pico W)

Firmware para **Raspberry Pi Pico W** (RP2040 + CYW43) que lee las entradas
analogicas del ADC (GPIO 26, 27 y 28), calcula el voltaje y la temperatura
interna del chip, y expone los datos por **HTTP REST** dentro de la red WiFi
local para ser consumidos por la aplicacion **Analog Pico Monitor** (Flutter).

## Endpoints HTTP

| Metodo | Ruta          | Descripcion                                         |
|--------|---------------|-----------------------------------------------------|
| GET    | `/api/status` | Estado del dispositivo (IP, uptime, RSSI, conectado)|
| GET    | `/api/analog` | Mediciones analogicas del ADC (raw + voltaje)       |

La API sigue el contrato JSON documentado en la seccion 5 del README de la
aplicacion Flutter (`analog_monitor/analog_monitor_flt`).

## Estructura del proyecto

```
analog_pico/
  adc_reader.h/.cpp   Modulo de lectura del ADC (12 bits, oversampling)
  tcp_server.h        (antiguo servidor TCP) - ver docs
  wifi_config.h       Credenciales WiFi y parametros (SSID, password)
  CMakeLists.txt      Build con Pico SDK
  docs/               Documentacion del firmware
```

## Como compilar

Requisitos: Pico SDK (v2.x), toolchain ARM GCC y CMake.

```bash
cmake -B build -DPICO_SDK_PATH=/ruta/al/pico-sdk
cmake --build build
```

El archivo `build/analog_monitor.uf2` se arrastra a la Pico W en modo BOOTSEL
para flashearla.

## Configuracion

Edita `wifi_config.h` antes de compilar:

- `WIFI_SSID` / `WIFI_PASSWORD`: credenciales de tu red WiFi.

Licencia: MIT (ver LICENSE).