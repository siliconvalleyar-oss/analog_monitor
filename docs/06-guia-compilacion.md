# 06 - Guia de Compilacion y Flasheo

## Prerequisitos

### Toolchain ARM GCC

```bash
# En Linux (Debian/Ubuntu)
sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi

# Verificar instalacion
arm-none-eabi-gcc --version
# Debe mostrar: arm-none-eabi-gcc (GNU Arm Embedded Toolchain) 10.3-2021.10
```

### CMake

```bash
# En Linux
sudo apt install cmake

# Verificar (se requiere >= 3.13)
cmake --version
```

### Make

```bash
# En Linux
sudo apt install make

# Verificar
make --version
```

### SDK de Pico

El SDK ya esta instalado en `/home/bee/pico/pico-sdk/`.
No se requiere instalacion adicional.

## Paso 1: Configurar Credenciales WiFi

Editar el archivo `src/analog/wifi_config.h`:

```c
#define WIFI_SSID       "MiRedWiFi"
#define WIFI_PASSWORD   "MiContrasena123"
```

**IMPORTANTE:** Si no se edita este archivo, el Pico W intentara conectarse
a una red llamada "TU_SSID_AQUI" y fallara.

## Paso 2: Compilar

### Metodo A: Build manual

```bash
# Navegar al directorio del proyecto
cd /home/bee/pico/src/analog

# Crear directorio de build
mkdir -p build
cd build

# Configurar CMake
cmake -DPICO_SDK_PATH=/home/bee/pico/pico-sdk ..

# Compilar (usar todos los cores disponibles)
make -j$(nproc)
```

### Metodo B: Build con script

Crear un archivo `build.sh` en `src/analog/`:

```bash
#!/bin/bash
set -e

echo "=== Compilando analog_monitor ==="

BUILD_DIR="build"
SDK_PATH="/home/bee/pico/pico-sdk"

# Limpiar build anterior si existe
if [ -d "$BUILD_DIR" ]; then
    echo "Limpiando build anterior..."
    rm -rf "$BUILD_DIR"
fi

# Crear directorio de build
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configurar
echo "Configurando CMake..."
cmake -DPICO_SDK_PATH="$SDK_PATH" ..

# Compilar
echo "Compilando..."
make -j$(nproc)

echo "=== Build completado ==="
echo "Archivo UF2: $BUILD_DIR/analog_monitor.uf2"
echo "Tamano: $(du -h analog_monitor.uf2 | cut -f1)"
```

```bash
chmod +x build.sh
./build.sh
```

### Metodo C: Build con CMake presets (avanzado)

Crear `CMakePresets.json` en `src/analog/`:

```json
{
  "version": 3,
  "configurePresets": [
    {
      "name": "pico",
      "binaryDir": "build",
      "toolchainFile": "/home/bee/pico/pico-sdk/cmake/preload/toolchains/pico_arm_cortex_m0plus_gcc.cmake",
      "cacheVariables": {
        "PICO_SDK_PATH": "/home/bee/pico/pico-sdk",
        "PICO_BOARD": "pico_w"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "release",
      "configurePreset": "pico",
      "configuration": "Release"
    }
  ]
}
```

```bash
cd src/analog
cmake --preset pico
cmake --build build --preset release
```

## Paso 3: Archivos Generados

Despues de compilar, el directorio `build/` contiene:

```
build/
├── analog_monitor.uf2         # Archivo para flashear (copiar a Pico W)
├── analog_monitor.elf         # ELF para depuracion con GDB
├── analog_monitor.bin         # Binario puro
├── analog_monitor.hex         # Formato Intel HEX
├── analog_monitor.map         # Mapa de memoria (para analisis)
├── CMakeCache.txt             # Cache de CMake
├── CMakeFiles/                # Archivos temporales de CMake
└── ...                        # Otros archivos de build
```

**El archivo importante es `analog_monitor.uf2`** (~200-500 KB).

## Paso 4: Flashear la Pico W

### Metodo A: Arrastrar y Soltar (Recomendado)

1. **Mantener presionado** el boton BOOTSEL en la Pico W
2. **Conectar** la Pico W al USB (se enciende el LED)
3. **Soltar** el boton BOOTSEL
4. Aparece una unidad de almacenamiento llamada `RPI-RP2`
5. **Copiar** el archivo `analog_monitor.uf2` a la unidad:

```bash
# En Linux, la unidad suele aparecer en /media/$USER/RPI-RP2/
cp build/analog_monitor.uf2 /media/$USER/RPI-RP2/

# O si aparece en /mnt/:
sudo cp build/analog_monitor.uf2 /media/$USER/RPI-RP2/
```

6. La Pico W se **reinicia sola** y comienza a ejecutar el firmware
7. La unidad `RPI-RP2` desaparece

### Metodo B: picotool (avanzado)

```bash
# Instalar picotool (opcional)
git clone https://github.com/raspberrypi/picotool.git
cd picotool
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo cp picotool /usr/local/bin/

# Flashear (la Pico W debe estar en modo BOOTSEL)
picotool load build/analog_monitor.uf2
picotool reboot
```

### Metodo C: openocd (para depuracion)

```bash
# Requiere un adaptateur SWD (ej: Raspberry Pi Debug Probe)
openocd -f interface/cmsis-dap.cfg \
        -f target/rp2040.cfg \
        -c "program build/analog_monitor.elf verify reset exit"
```

## Paso 5: Verificar Funcionamiento

### Monitor Serial por USB

El firmware esta configurado para enviar `printf` por USB CDC.
Para ver los mensajes:

```bash
# Linux
screen /dev/ttyACM0 115200

# O con minicom
minicom -b 115200 -D /dev/ttyACM0

# O con picocom
picocom -b 115200 /dev/ttyACM0
```

**Mensajes esperados:**

```
=== Analog Monitor - Pico W ===
Inicializando ADC...
WiFi: Conectando a MiRedWiFi...
WiFi: Conectado! IP: 192.168.1.100
TCP Server: Escuchando en puerto 5000
ADC: ch0=1650.5mV ch1=330.2mV ch2=0.0mV T=42.5°C
```

### LED de la Pico W

- **LED fijo:** WiFi conectado, servidor TCP activo
- **LED parpadeando:** Intentando conectar WiFi
- **LED apagado:** Error de inicializacion

## Comandos Utiles de Build

```bash
# Build completo
make -j$(nproc)

# Build solo un target
make analog_monitor

# Limpiar todo
make clean

# Rebuild completo
make clean && cmake -DPICO_SDK_PATH=/home/bee/pico/pico-sdk .. && make -j$(nproc)

# Ver detalle de errores
make VERBOSE=1

# Build en modo Release (optimizado, sin debug)
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build en modo Debug (con simbolos de depuracion)
cmake -DCMAKE_BUILD_TYPE=Debug ..
```

## Tamaño del Firmware

| Build | Tamano UF2 | Notas |
|-------|-----------|-------|
| Debug | ~500 KB | Con simbolos, para depuracion |
| Release | ~200 KB | Optimizado, sin simbolos |
| MinSizeRel | ~180 KB | Minimo tamano (-Os) |

La Pico W tiene 2 MB de flash, asi que cualquier build cabe holgadamente.
