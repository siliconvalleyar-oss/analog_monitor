# 01 - Arquitectura del firmware

El firmware es un programa _bare-metal_ (sin sistema operativo) para una
**Raspberry Pi Pico W**. Se divide en modulos con responsabilidades claras:

```
                 ┌───────────────┐
   GPIO 26-28 ──▶│  adc_reader   │  mediciones raw + voltaje
                 └──────┬────────┘
                        │ AdcReading
                 ┌──────▼────────┐
                 │   main.cpp    │  orquesta + loop principal
                 └──────┬────────┘
          WiFi/SNTP     │ g_reading (compartida)
                 ┌──────▼────────┐
                 │ http_server   │  servidor HTTP REST (lwIP RAW)
                 └──────┬────────┘
                        │ GET /api/status  GET /api/analog
                        ▼
                 App Flutter (Analog Pico Monitor)
```

## Modulos

| Modulo | Responsabilidad |
|--------|-----------------|
| `main.cpp` | Inicializa ADC, conecta WiFi, arranca SNTP y el servidor HTTP. En el loop lee el ADC, refresca el RSSI cada ~5 s y mantiene viva la pila lwIP con `http_server_poll()`. |
| `adc_reader` | Configura el ADC del RP2040, hace oversampling (media de `ADC_OVERSAMPLE_COUNT` muestras por canal) y convierte la lectura cruda (12 bits) a voltaje. |
| `http_server` | Servidor HTTP sobre la API RAW de lwIP (modo poll, sin threads). Sirve `/api/status` y `/api/analog` en JSON. |
| `wifi_config.h` | Constantes de configuracion: credenciales WiFi, puerto HTTP, periodo del ADC, SNTP. |
| `lwipopts.h` | Opciones de compilacion de lwIP (NO_SYS, TCP, DHCP, DNS, SNTP). |

## Flujo de datos en tiempo real

1. **ADC** (`adc_reader_read`) captura los 3 canales con oversampling y los
   deja en una estructura `AdcReading` (`raw_ch0..ch2`, `voltage_ch0..ch2`
   en voltios).
2. **Comparticion**: `main.cpp` llama `http_server_set_reading(&g_reading)` y
   actualiza `g_reading` en cada iteracion del loop. El servidor HTTP solo
   **lee** esa estructura al responder, por lo que no hay condiciones de
   carrera entre los callbacks de red y el loop.
3. **Hora** (`timestamp`): al sincronizar via SNTP, el callback
   `sntp_store_system_time()` guarda el epoch base; la hora "actual" se
   deriva del epoch + ticks transcurridos.
4. **RSSI**: `main.cpp` consulta `cyw43_wifi_get_rssi()` cada ~5 s y lo
   publica con `http_server_set_rssi()` (la lectura directa del chip dentro
   de callbacks de red bloquearia el bus de radio).

## Modelo de concurrencia

- lwIP corre en **modo poll** (`pico_cyw43_arch_lwip_poll`): no hay threads;
  todos los eventos de red se procesan cuando se llama a `cyw43_arch_poll()`
  (a traves de `http_server_poll()`) desde el loop principal.
- Cada conexion TCP activa es un slot de `HTTP_MAX_CLIENTS`; termina tan
  pronto como el `Content-Length` completo es enviado y confirmado por el
  cliente (respuesta `Connection: close`).

## Dependencias

- `pico_stdlib`, `hardware_adc`
- `pico_cyw43_arch_lwip_poll` (WiFi + lwIP modo poll)
- `pico_lwip_sntp` (cliente SNTP para la hora)