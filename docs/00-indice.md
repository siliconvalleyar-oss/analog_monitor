# Analog Pico Monitor - Documentacion del firmware

Firmware para **Raspberry Pi Pico W** que lee el ADC (GPIO 26-28) y expone los
datos por **HTTP REST** para la aplicacion Analog Pico Monitor (Flutter).

## Indice

| Doc | Contenido |
|-----|-----------|
| [01-arquitectura.md](01-arquitectura.md) | Vista general del firmware y flujo de datos |
| [02-hardware-adc.md](02-hardware-adc.md) | Conexionado del ADC, pines y calibracion |
| [03-wifi-lwip.md](03-wifi-lwip.md) | Conexion WiFi y arquitectura de red (lwIP) |
| [04-protocolo-http.md](04-protocolo-http.md) | Contrato HTTP REST (`/api/status`, `/api/analog`) |
| [05-compilacion-flasheo.md](05-compilacion-flasheo.md) | Como compilar y flashear la Pico W |

## Estado del proyecto

- Placa objetivo: Raspberry Pi Pico W (RP2040 + CYW43 WiFi).
- SDK: Raspberry Pi Pico SDK v2.x con lwIP en modo poll (NO_SYS).
- La rama de firmware es `analog_pico` del repositorio `analog_monitor`.

Licencia: MIT (ver `LICENSE`).