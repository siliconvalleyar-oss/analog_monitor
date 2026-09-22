# 03 - WiFi y arquitectura de red (lwIP)

## Conexion WiFi

El firmware usa el chip CYW43 integrado en la Pico W a traves del SDK:

```
cyw43_arch_init()                        iniciar el controlador WiFi
cyw43_arch_enable_sta_mode()             modo Station (cliente de la red)
cyw43_arch_wifi_connect_timeout_ms(
    WIFI_SSID, WIFI_PASSWORD,
    CYW43_AUTH_WPA2_AES_PSK,
    WIFI_CONNECT_TIMEOUT_MS)             conectar a la red local
```

- Si la conexion falla (credenciales o router), el firmware imprime el error
  por USB y se queda en `main()` retornando. Ajusta `wifi_config.h`.
- La IP se obtiene por **DHCP** y se muestra por USB al conectar.
- El LED integrado de la Pico W se enciende cuando la conexion tiene exito.

## Stack lwIP: modo poll (NO_SYS)

lwIP se configura con `NO_SYS=1` y sin sockets. Toda la pila TCP/IP se
procesa de forma cooperativa cada vez que el loop principal llama a
`cyw43_arch_poll()` (expuesto como `http_server_poll()`):

```
while (true) {
    http_server_poll();          // procesa eventos WiFi + lwIP + timers
    adc_reader_read(&g_reading); // actualiza medicion
    // ... refresco RSSI cada ~5 s ...
    sleep_ms(ADC_SAMPLE_INTERVAL_MS);
}
```

Ventaja: no se necesitan threads ni RTOS; el firmware es simple y
determinista. Requisito: `pico_cyw43_arch_lwip_poll` (ver CMakeLists).

## Opciones relevantes en `lwipopts.h`

| Opcion | Valor | Efecto |
|--------|-------|--------|
| `NO_SYS` | 1 | Sin RTOS, API RAW de lwIP |
| `LWIP_DHCP` | 1 | IP automatica |
| `LWIP_DNS` | 1 | Resolver hostnames (SNTP) |
| `SNTP_SERVER_DNS` | 1 | Servidor NTP por nombre |
| `MEMP_NUM_SYS_TIMEOUT` | 8 | Slots para timers TCP/ARP/DHCP/DNS/SNTP |
| `MEMP_NUM_TCP_PCB` | 12 | Conexiones TCP simultaneas |

## SNTP (hora)

- Habilitado con `ENABLE_SNTP=1` en `wifi_config.h`.
- `main.cpp` llama `sntp_setoperatingmode(SNTP_OPMODE_POLL)`,
  `sntp_setservername(0, SNTP_SERVER)` y `sntp_init()`.
- Al recibir una respuesta NTP valida, lwIP invoca el callback
  `sntp_store_system_time()` (definido en `lwipopts.h` como
  `SNTP_SET_SYSTEM_TIME`), que guarda el **epoch UTC** base.
- La hora "ahora" = epoch base + ms transcurridos. Se reporta en
  `/api/analog` (campo `timestamp`, epoch en segundos).
- Mientras no haya sincronizado, `timestamp` contiene el uptime en segundos
  y la app puede mostrarlo como "hora no sincronizada".

## RSSI

`cyw43_wifi_get_rssi()` se consulta cada ~5 s desde el loop principal (nunca
dentro de callbacks de red) y se publica con `http_server_set_rssi()` para
`/api/status`.