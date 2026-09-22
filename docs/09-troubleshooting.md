# 09 - Solucion de Problemas

## Problemas de Compilacion

### "PICO_SDK_PATH not set or not found"

```
CMake Error at /home/bee/pico/pico-sdk/external/pico_sdk_import.cmake:...
  SDK location was not specified.
```

**Causa:** CMake no encuentra el SDK de Pico.

**Solucion:**
```bash
# Opcion 1: Definir variable de entorno
export PICO_SDK_PATH=/home/bee/pico/pico-sdk

# Opcion 2: Pasar al cmake
cmake -DPICO_SDK_PATH=/home/bee/pico/pico-sdk ..

# Opcion 3: Verificar que el SDK existe
ls /home/bee/pico/pico-sdk/CMakeLists.txt
```

### "arm-none-eabi-gcc: command not found"

```
bash: arm-none-eabi-gcc: command not found
```

**Causa:** No esta instalado el toolchain ARM GCC.

**Solucion:**
```bash
sudo apt update
sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi
```

### "pico_sdk_init has already been called"

```
CMake Error: pico_sdk_init() has already been called
```

**Causa:** `pico_sdk_init()` se llama antes de `project()`.

**Solucion:** Verificar el orden en CMakeLists.txt:
```cmake
include(...)           # Primero el include
project(...)           # Segundo project()
pico_sdk_init()        # Tercero pico_sdk_init()
```

### "No rule to make target 'hardware_adc'"

```
make: *** No rule to make target 'hardware_adc'.
```

**Causa:** Falta enlazar la libreria en CMakeLists.txt.

**Solucion:**
```cmake
target_link_libraries(analog_monitor
    pico_stdlib
    hardware_adc          # <-- Agregar esta linea
    pico_cyw43_arch_lwip_poll
)
```

### "undefined reference to `__aeabi_uidiv'"

**Causa:** Falta el linker del modulo de division.

**Solucion:** Agregar `pico_divider` a las dependencias:
```cmake
target_link_libraries(analog_monitor
    pico_stdlib
    hardware_adc
    pico_cyw43_arch_lwip_poll
    pico_divider           # <-- Agregar
)
```

## Problemas de WiFi

### No se conecta a la red WiFi

**Causas posibles:**

1. Credenciales incorrectas en `wifi_config.h`
2. La red no esta en rango
3. La red usa un protocolo no soportado (WPA3, Enterprise)

**Diagnostico:**
```bash
# Ver mensaje en monitor serial
screen /dev/ttyACM0 115200

# Mensajes esperados:
# WiFi: Conectando a MiRed...
# WiFi: Conectado! IP: 192.168.1.100

# Si falla:
# WiFi: Error de autenticacion (bad auth)
# WiFi: Timeout de conexion
```

**Soluciones:**

```c
// 1. Verificar credenciales (case-sensitive)
#define WIFI_SSID       "MiRed"          // No "mired" ni "MRED"
#define WIFI_PASSWORD   "MiPass123"      // No "mipass123"

// 2. Aumentar timeout
#define WIFI_CONNECT_TIMEOUT_MS 60000    // 60 segundos

// 3. Verificar que la red es 2.4 GHz (el CYW43 NO soporta 5 GHz)
```

### La IP no aparece en el monitor serial

**Causa:** La conexion USB CDC no funciona.

**Soluciones:**

```bash
# 1. Verificar que el USB esta conectado
lsusb | grep "2e8a"  # Vendor ID de Raspberry Pi

# 2. Verificar permisos del puerto serial
sudo chmod 666 /dev/ttyACM0

# 3. Probar otro cable USB (algunos son solo de carga)

# 4. Probar otro terminal
minicom -b 115200 -D /dev/ttyACM0
```

### La IP es 0.0.0.0 o no asignada

**Causa:** El DHCP del router no asigno IP.

**Soluciones:**

```bash
# 1. Verificar que el router esta encendido y funcionando
# 2. Reiniciar el Pico W (desconectar y reconectar USB)
# 3. Verificar que el SSID coincide exactamente con el de tu red
# 4. Si el router tiene MAC filtering, agregar la MAC del Pico W
```

## Problemas de TCP

### "Connection refused" desde Flutter

```
SocketException: Connection refused
```

**Causa:** El servidor TCP no esta escuchando.

**Soluciones:**

```bash
# 1. Verificar que el Pico W esta ejecutando el firmware
# (LED encendido, monitor serial mostrando mensajes)

# 2. Verificar que el puerto es correcto (default: 5000)
# En flutter, usar el mismo puerto que TCP_PORT en wifi_config.h

# 3. Verificar que no hay firewall bloqueando
# En Linux:
sudo iptables -A INPUT -p tcp --dport 5000 -j ACCEPT

# 4. Probar conexion local desde la misma red
nc -v 192.168.1.100 5000
```

### Se desconecta despues de unos segundos

**Causa:** El `cyw43_arch_poll()` no se llama suficiente.

**Solucion:** Verificar que el loop principal llama a `tcp_server_poll()`
periodicamente:

```cpp
// En main.cpp, el loop debe ser:
while (true) {
    tcp_server_poll();    // <-- CRITICO: sin esto, la red se congela
    // ... resto del codigo ...
    sleep_ms(intervalo);
}
```

### No recibe datos en Flutter

**Causa:** El parser JSON falla.

**Diagnostico:**

```bash
# 1. Probar con netcat (Linux)
nc 192.168.1.100 5000

# Debe ver algo como:
# {"ch0_mv":1650.5,"ch1_mv":330.2,...}

# 2. Verificar que cada linea termina en \n
# El JSON DEBE tener un newline al final
```

**Solucion en Flutter:**

```dart
// Asegurar que se procesan TODOS los bytes entrantes
socket.listen(
  (data) {
    buffer += String.fromCharCodes(data);
    // Buscar por \n, no por longitud fija
    while (buffer.contains('\n')) {
      // ... parsear linea ...
    }
  },
);
```

### Solo recibe un dato y se detiene

**Causa:** El cliente consume datos mas rapido de lo que el servidor envia,
o hay un problema con el buffer TCP.

**Solucion:** Aumentar el intervalo de muestreo temporalmente:
```c
#define ADC_SAMPLE_INTERVAL_MS 5000  // 5 segundos (para pruebas)
```

## Problemas de Medicion

### Valores ADC muy ruidosos

**Soluciones:**

```c
// 1. Aumentar oversampling (redundar el ruido)
#define ADC_OVERSAMPLE_COUNT 64   // En vez de 16

// 2. Agregar capacitor de filtro en hardware
// Colocar 100nF ceramico entre el pin ADC y GND (lo mas cerca posible del pin)

// 3. Separar cables analogicos de cables de alimentacion/digital
```

### Valores ADC estan en 0 o en 4095

**Causas:**

- **Siempre 0:** El pin no esta conectado o el sensor esta apagado
- **Siempre 4095:** El voltaje excede 3.3V (usar divisor resistivo)
- **Fluctua entre 0 y 4095:** El cable esta suelto

**Soluciones:**

```bash
# 1. Verificar el voltaje en el pin con un multímetro
# Debe ser entre 0V y 3.3V

# 2. Verificar que adc_gpio_init() se llama para el pin correcto
adc_gpio_init(26);  // GPIO 26 = Canal 0
adc_gpio_init(27);  // GPIO 27 = Canal 1
adc_gpio_init(28);  // GPIO 28 = Canal 2
```

### Valores ADC siempre en ~1650mV (mitad del rango)

**Causa:** El pin ADC tiene un pull-up interno activado.

**Solucion:** Asegurar que `adc_gpio_init()` se ejecuta correctamente,
que desabilita pulls y receptor digital:

```cpp
// Esto ya esta en adc_reader.cpp:
adc_gpio_init(26);  // Desactiva GPIO_FUNC_NULL, pulls, y receptor digital
```

### La temperatura interna siempre es ~27°C

**Causa:** El sensor de temperatura del RP2040 no es preciso.

**Es normal.** La precision es ±2°C y solo es para monitoreo de temperatura
del chip. No usar para medicion de temperatura externa.

### La temperatura interna fluctua mucho

**Causa:** El sensor de temperatura esta cerca del WiFi chip CYW43,
que genera calor cuando transmite.

**Es normal.** La temperatura interna varia con la actividad WiFi.
Si la temperatura fluctua mucho, puede ser por transmisiones WiFi
frecuentes.

## Problemas de Energia

### La Pico W se reinicia sola

**Causas posibles:**

1. **Alimentacion insuficiente:** El USB no entrega suficiente corriente
   - Solucion: Usar un cable USB de buena calidad o un hub con alimentacion

2. **Watchdog reinicia:** El codigo no llama a `cyw43_arch_poll()` suficiente
   - Solucion: Verificar el loop principal

3. **Brown-out:** El voltaje de alimentacion cae por debajo del umbral
   - Solucion: Usar alimentacion estabilizada (5V USB)

### Alto consumo de energia

El Pico W consume ~100mA con WiFi activo. Para ahorrar energia:

```cpp
// 1. Usar sleep entre muestreos (dormir el procesador)
sleep_ms(intervalo);  // El WiFi se mantiene activo

// 2. Reducir frecuencia de muestreo
#define ADC_SAMPLE_INTERVAL_MS 5000  // 1 Hz -> 0.2 Hz
```

## Herramientas de Diagnostico

### Netcat (probar conexion TCP)

```bash
# Conectar al servidor TCP
nc 192.168.1.100 5000

# Debe mostrar lineas JSON cada segundo
# Presionar Ctrl+C para salir
```

### Wireshark (analizar trafico)

```bash
# Capturar trafico TCP en la interfaz WiFi
sudo wireshark -i wlan0 -f "tcp port 5000"

# Buscar paquetes SYN-ACK para verificar que el Pico acepta conexiones
```

### picotool (depuracion avanzada)

```bash
# Leer registers del RP2040
picotool info

# Leer temperatura del chip
picotool tempsense

# Reiniciar el Pico
picotool reboot
```

### Monitor serial con timestamps

```bash
# Usar minicom con timestamps
minicom -b 115200 -D /dev/ttyACM0 -C /tmp/pico_log.txt

# O con python
python3 -c "
import serial, time
s = serial.Serial('/dev/ttyACM0', 115200)
while True:
    line = s.readline().decode('utf-8', errors='replace').strip()
    print(f'{time.strftime(\"%H:%M:%S\")} {line}')
"
```

## Referencia Rapida

| Problema | Ver seccion |
|----------|------------|
| No compila | "Problemas de Compilacion" |
| No conecta WiFi | "Problemas de WiFi" |
| No acepta conexiones TCP | "Problemas de TCP" |
| Valores incorrectos del ADC | "Problemas de Medicion" |
| Se reinicia solo | "Problemas de Energia" |
| No aparece /dev/ttyACM0 | Reconectar USB, verificar cable |
