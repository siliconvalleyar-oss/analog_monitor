# 04 - Protocolo HTTP REST

El firmware expone un servidor HTTP (puerto `HTTP_PORT`, por defecto **80**)
con una API JSON de solo lectura consumida por la aplicacion Analog Pico
Monitor (Flutter). No hay autenticacion ni cifrado (red local).

## Endpoints

| Metodo | Ruta          | Descripcion                                        |
|--------|---------------|----------------------------------------------------|
| GET    | `/api/status` | Estado del dispositivo (IP, uptime, RSSI)          |
| GET    | `/api/analog` | Mediciones analogicas del ADC (raw + voltaje)      |
| GET    | `/`           | Texto informativo (para probar en un navegador)    |

Respuestas comunes de error: `400 Bad Request`, `404 Not Found`,
`405 Method Not Allowed`. Las respuestas exitosas llevan
`Content-Type: application/json` y `Connection: close` (el servidor cierra
la conexion al terminar de enviar el `Content-Length` completo).

## GET /api/status

```json
{
  "device": "Raspberry Pi Pico W",
  "connected": true,
  "ip": "192.168.1.100",
  "uptime": 3600,
  "wifi_rssi": -45
}
```

| Campo        | Tipo   | Descripcion                            | Obligatorio |
|--------------|--------|----------------------------------------|-------------|
| `device`     | string | Nombre del dispositivo (`DEVICE_NAME`) | si          |
| `connected`  | bool   | El dispositivo esta operativo          | si          |
| `ip`         | string | IP actual (p. ej. `192.168.1.100`)     | si          |
| `uptime`     | num    | Segundos desde el arranque             | si          |
| `wifi_rssi`  | num    | RSSI WiFi en dBm                       | no*         |

*`wifi_rssi` se omite mientras el valor sea desconocido (`HTTP_RSSI_UNKNOWN`).

## GET /api/analog

```json
{
  "timestamp": 1730000000,
  "channels": [
    { "channel": 0, "gpio": 26, "raw": 4123, "voltage": 3.322 },
    { "channel": 1, "gpio": 27, "raw": 1500, "voltage": 1.209 },
    { "channel": 2, "gpio": 28, "raw":  204, "voltage": 0.164 }
  ]
}
```

| Campo        | Tipo   | Descripcion                                         |
|--------------|--------|-----------------------------------------------------|
| `timestamp`  | num    | Epoch UTC en segundos (SNTP). Hasta sincronizar, lleva el uptime en segundos |
| `channels`   | array  | Lista de canales ADC (orden: GPIO 26, 27, 28)       |
| `channel`    | num    | Indice del canal (0, 1, 2)                          |
| `gpio`       | num    | GPIO fisico (26, 27, 28)                            |
| `raw`        | num    | Valor crudo de 12 bits (0-4095), promedio de N muestras |
| `voltage`    | num    | Voltaje en voltios con 3 decimales (V = raw/4095*3.3) |

## Notas de compatibilidad con la app Flutter

- `raw` siempre es >= 0; la app trata valores fuera de rango como error de
  medicion.
- `voltage` lo envia el firmware directamente en voltios; si faltara, la app
  lo recalcula con su propia conversion `raw -> V`.
- `timestamp`: la app interpreta el campo como epoch en **segundos**. El
  firmware lo emite sincronizado por NTP; si no hay red con salida a
  internet, emite el uptime y la app muestra "hora no sincronizada".

## Ejemplo de uso rapido

```bash
curl http://IP_DE_LA_PICO/api/status
curl http://IP_DE_LA_PICO/api/analog
```