# 04 - Protocolo de Comunicacion TCP/JSON

## Resumen

El Pico W actua como **servidor TCP** y la app Flutter como **cliente**.
Los datos fluyen en una sola direccion: del Pico a la app. El protocolo
es simple: cada mensaje es una linea JSON terminada en newline (`\n`).

## Configuracion de la Red

| Parametro | Valor | Configurable |
|-----------|-------|--------------|
| Transporte | TCP/IPv4 | No |
| Puerto | 5000 | Si (`TCP_PORT` en `wifi_config.h`) |
| Max. clientes simultaneos | Ilimitado (memoria) | No |
| Keepalive | Deshabilitado | No |
| Buffer de envio | 1024 bytes | No |
| Timeout de conexion | Sin timeout | No |

## Formato del Mensaje

Cada paquete es una **unica linea JSON** terminada con `\n` (0x0A):

```
{"ch0_mv":1650.5,"ch1_mv":330.2,"ch2_mv":0.0,"ch0_raw":2048,"ch1_raw":409,"ch2_raw":0,"temp_c":42.5,"ts_ms":12345678}\n
```

### Campos del JSON

| Campo | Tipo | Unidad | Rango | Descripcion |
|-------|------|--------|-------|-------------|
| `ch0_mv` | float | mV | 0.0 - 3300.0 | Voltaje del canal 0 (GPIO 26) |
| `ch1_mv` | float | mV | 0.0 - 3300.0 | Voltaje del canal 1 (GPIO 27) |
| `ch2_mv` | float | mV | 0.0 - 3300.0 | Voltaje del canal 2 (GPIO 28) |
| `ch0_raw` | int | cuentas | 0 - 4095 | Valor crudo ADC canal 0 |
| `ch1_raw` | int | cuentas | 0 - 4095 | Valor crudo ADC canal 1 |
| `ch2_raw` | int | cuentas | 0 - 4095 | Valor crudo ADC canal 2 |
| `temp_c` | float | °C | ~0 - 85 | Temperatura interna del chip |
| `ts_ms` | int | ms | 0 - 4.29e9 | Milisegundos desde el arranque |

### Ejemplo de Mensaje

```json
{
  "ch0_mv": 1650.5,
  "ch1_mv": 330.2,
  "ch2_mv": 0.0,
  "ch0_raw": 2048,
  "ch1_raw": 409,
  "ch2_raw": 0,
  "temp_c": 42.5,
  "ts_ms": 12345678
}
```

**NOTA:** El JSON se envia en una sola linea (sin saltos de carro intermedios)
para simplificar el parsing del lado del cliente.

## Flujo de Comunicacion

### Conexion Inicial

```
App Flutter                          Pico W (Servidor)
    |                                    |
    |  1. DNS resolve (si aplica)        |
    |  2. TCP SYN ---------------------->|  Puerto 5000
    |  3. TCP SYN-ACK <------------------|
    |  4. TCP ACK ---------------------->|
    |                                    |
    |  <<< Conexión TCP establecida >>>  |
    |                                    |
    |  5. JSON + "\n" ------------------>|  (primer dato)
    |  6. JSON + "\n" ------------------>|
    |  7. JSON + "\n" ------------------>|
    |  ...                               |
```

### Desconexion

```
App Flutter                          Pico W (Servidor)
    |                                    |
    |  1. TCP FIN ---------------------->|  (usuario cierra app)
    |  2. TCP FIN-ACK <------------------|
    |  3. TCP ACK ---------------------->|
    |                                    |
    |  <<< Conexión cerrada >>>          |
    |                                    |
```

El servidor detecta la desconexion cuando `tcp_recv()` recibe `p == NULL`.
Automaticamente limpia los recursos y queda listo para nuevas conexiones.

## Parsing del Lado del Cliente (Flutter)

### Metodo 1: ReadLine (Recomendado)

```dart
// Conexion TCP
final socket = await Socket.connect(ip, port);

// Leer datos como stream de lineas
socket.listen(
  (data) {
    final line = String.fromCharCodes(data).trim();
    if (line.isNotEmpty) {
      final json = jsonDecode(line);
      // Usar json['ch0_mv'], json['ch1_mv'], etc.
    }
  },
);
```

### Metodo 2: Buffer Acumulativo

Si los datos llegan fragmentados (raro con TCP, pero posible):

```dart
String buffer = '';

socket.listen(
  (data) {
    buffer += String.fromCharCodes(data);
    // Separar por newlines
    while (buffer.contains('\n')) {
      final index = buffer.indexOf('\n');
      final line = buffer.substring(0, index).trim();
      buffer = buffer.substring(index + 1);
      if (line.isNotEmpty) {
        final json = jsonDecode(line);
        // Procesar datos...
      }
    }
  },
);
```

## Comandos del Cliente (Futuro)

Actualmente el protocolo es **unidireccional** (solo envio del Pico).
En futuras versiones se podran enviar comandos desde Flutter:

| Comando | Descripcion | Estado |
|---------|-------------|--------|
| `{"cmd":"set_interval","ms":500}` | Cambiar frecuencia de muestreo | Planificado |
| `{"cmd":"set_oversample","n":32}` | Cambiar oversampling | Planificado |
| `{"cmd":"get_config"}` | Obtener configuracion actual | Planificado |
| `{"cmd":"reset"}` | Reiniciar el Pico | Planificado |

## Tamaño de los Mensajes

| Componente | Bytes (aprox) |
|-----------|---------------|
| JSON completo | ~150-200 bytes |
| Cabecera TCP | 20 bytes |
| Ethernet frame | 14 bytes |
| Total por paquete | ~200 bytes |

A 1 Hz de muestreo: ~200 bytes/s = ~1.6 kbps (practicamente nada de ancho de banda).

## Limitaciones

1. **Unidireccional:** Actualmente solo el Pico envia datos. No hay comandos
   desde Flutter hacia el Pico.

2. **Sin autenticacion:** Cualquier dispositivo en la misma red WiFi puede
   conectarse al puerto 5000 y recibir los datos.

3. **Sin encriptacion:** Los datos viajan en texto plano. No usar para
   informacion sensible.

4. **Sin persistencia:** Los datos no se almacenan en el Pico. Si la app
   se reconecta, pierde el historial anterior.

5. **Buffer limitado:** El buffer TCP de lwIP tiene un limite. Si el cliente
   es muy lento leyendo, el Pico puede dejar de enviar datos.
