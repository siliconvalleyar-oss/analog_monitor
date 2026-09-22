# Analog Pico Monitor - Firmware (Raspberry Pi Pico W)

Firmware para **Raspberry Pi Pico W** (RP2040 + CYW43) que lee las entradas
analogicas del ADC (GPIO 26, 27 y 28), calcula el voltaje de cada canal y
expone los datos por **HTTP REST** dentro de la red WiFi local para ser
consumidos por la aplicacion **Analog Pico Monitor** (Flutter).

## Endpoints HTTP

| Metodo | Ruta          | Descripcion                                          |
|--------|---------------|------------------------------------------------------|
| GET    | `/api/status` | Estado del dispositivo (IP, uptime, RSSI, conectado) |
| GET    | `/api/analog` | Mediciones analogicas del ADC (raw + voltaje)        |

La API sigue el contrato JSON documentado en el README de la aplicacion
Flutter (`analog_monitor/analog_monitor_flt`, seccion "API HTTP REST") y en
`docs/04-protocolo-http.md`.

## Estructura del proyecto

```
analog_pico/
  CMakeLists.txt          Build con Pico SDK (placa pico_w)
  pico_sdk_import.cmake   Helper oficial para localizar el SDK
  wifi_config.h           Credenciales WiFi y parametros (SSID, password, puerto)
  main.cpp                Punto de entrada + loop principal (WiFi, SNTP, HTTP)
  adc_reader.h/.cpp       Modulo de lectura del ADC (12 bits, oversampling)
  http_server.h/.cpp      Servidor HTTP REST sobre lwIP (RAW, modo poll)
  lwipopts.h              Opciones de lwIP (NO_SYS, TCP, DHCP, DNS, SNTP)
  docs/                   Documentacion del firmware
```

## Como compilar

Requisitos: Pico SDK (v2.x), toolchain ARM GCC y CMake (>= 3.13).

```bash
# PICO_SDK_PATH se auto-detecta en ../pico-sdk si no se indica
cmake -B build            # o: -DPICO_SDK_PATH=/ruta/al/pico-sdk
cmake --build build
```

El archivo `build/analog_monitor.uf2` se arrastra a la Pico W en modo BOOTSEL
para flashearla. Durante el arranque, por USB (printf) se muestra el estado
de la conexion WiFi, la IP asignada y los endpoints disponibles.

## Configuracion

Edita `wifi_config.h` antes de compilar:

- `WIFI_SSID` / `WIFI_PASSWORD`: credenciales de tu red WiFi.
- `HTTP_PORT`: puerto del servidor HTTP (por defecto 80).
- `ADC_SAMPLE_INTERVAL_MS`: periodo de refresco de las mediciones.
- `ENABLE_SNTP` / `SNTP_SERVER`: hora sincronizada (epoch) para `timestamp`.

Licencia: MIT (ver LICENSE).