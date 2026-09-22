 =============================================================================
 * CMakeLists.txt - Proyecto de medicion analogica con WiFi para Pico W
 * =============================================================================
 *
 * Proyecto: analog_monitor
 * Plataforma: Raspberry Pi Pico W (RP2040 + CYW43 WiFi)
 * Funcion: Lee voltajes analogicos (GPIO 26-28) y los sirve via TCP
 *          para ser monitoreados desde una aplicacion Flutter.
 *
 * Estructura del proyecto:
 *   src/analog/
 *   ├── CMakeLists.txt        (este archivo)
 *   ├── wifi_config.h         (credenciales WiFi del usuario)
 *   ├── main.cpp              (punto de entrada)
 *   ├── adc_reader.h          (modulo de lectura ADC - cabecera)
 *   ├── adc_reader.cpp        (modulo de lectura ADC - implementacion)
 *   ├── tcp_server.h          (servidor TCP - cabecera)
 *   └── tcp_server.cpp        (servidor TCP - implementacion)
 *
 * Prerequisitos:
 *   - Pico SDK v2.3.1 instalado en /home/bee/pico/pico-sdk/
 *   - Pico W (placa con chip CYW43 para WiFi)
 *   - ARM GCC toolchain instalado
 *
 * Para compilar:
 *   cd src/analog
 *   mkdir build && cd build
 *   cmake -DPICO_SDK_PATH=/home/bee/pico/pico-sdk ..
 *   make -j$(nproc)
 *
 * El archivo .uf2 resultante se carga en la Pico W manteniendo el boton BOOT.
 * ============================================================================= */

cmake_minimum_required(VERSION 3.13)

# Copia del pico_sdk_import.cmake para localizar el SDK
include(/home/bee/pico/pico-sdk/external/pico_sdk_import.cmake)

# Proyecto: lenguajes C y C++ (ASM necesario para el boot stage2 del SDK)
project(analog_monitor C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Inicializar el SDK de Pico (debe ir despues de project())
pico_sdk_init()

# ===========================================================================
 * Ejecutable principal
 * =========================================================================== */
add_executable(analog_monitor
    main.cpp
    adc_reader.cpp
    tcp_server.cpp
)

# ===========================================================================
 * Librerias enlazadas
 * ===========================================================================
 *
 * pico_stdlib:
 *   Abstraction de nivel alto del hardware (GPIO, UART, sleep, etc.)
 *
 * hardware_adc:
 *   Driver del convertidor analogico-digital del RP2040.
 *   Permite leer los canales ADC0-ADC2 (GPIO 26-28).
 *
 * pico_cyw43_arch_lwip_poll:
 *   Integra el driver CYW43 (WiFi) con lwIP (stack TCP/IP) en modo poll.
 *   El usuario debe llamar a cyw43_arch_poll() periodicamente en el loop
 *   principal para mantener la pila de red operativa.
 *
 * pico_lwip_headers:
 *   Cabeceras de lwIP para usar la API RAW de TCP (tcp_new, tcp_bind, etc.)
 * =========================================================================== */
target_link_libraries(analog_monitor
    pico_stdlib
    hardware_adc
    pico_cyw43_arch_lwip_poll
)

# Genera archivos adicionales: .uf2 para flashear, .elf para debug, .bin, .hex
pico_add_extra_outputs(analog_monitor)

# Habilitar salida USB CDC (printf por USB) y UART por defecto
pico_enable_stdio_usb(analog_monitor 1)
pico_enable_stdio_uart(analog_monitor 0)

# ===========================================================================
 * Definiciones de compilacion (macros C/C++)
 * ===========================================================================
 *
 * WIFI_SSID / WIFI_PASSWORD:
 *   Se pasan desde wifi_config.h via el include en main.cpp.
 *   El usuario debe editar wifi_config.h con sus credenciales.
 *
 * TCP_PORT:
 *   Puerto en el que el Pico W escucha conexiones TCP.
 *   La app Flutter se conecta a <IP_del_pico>:<TCP_PORT>.
 * =========================================================================== */
