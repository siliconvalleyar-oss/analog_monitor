# =============================================================================
# CMakeLists.txt - Firmware Analog Pico Monitor para Raspberry Pi Pico W
# =============================================================================
#
# Proyecto:   analog_monitor
# Plataforma: Raspberry Pi Pico W (RP2040 + CYW43 WiFi)
# Funcion:    Lee voltajes analogicos (GPIO 26-28) y los sirve via HTTP REST
#             para la aplicacion Analog Pico Monitor (Flutter).
#
# API expuesta:
#   GET /api/status   -> estado del dispositivo (IP, uptime, RSSI)
#   GET /api/analog   -> mediciones analogicas (raw + voltaje)
#
# Estructura del proyecto:
#   CMakeLists.txt    (este archivo)
#   pico_sdk_import.cmake  (copia local del helper del SDK)
#   wifi_config.h     (credenciales WiFi y parametros, editame)
#   main.cpp          (punto de entrada + loop principal)
#   adc_reader.h/.cpp (modulo de lectura ADC)
#   http_server.h/.cpp(servidor HTTP REST sobre lwIP RAW)
#   lwipopts.h        (opciones de lwIP: NO_SYS/poll, TCP, DHCP, SNTP)
#
# Como compilar (con una toolchain ARM):
#   cmake -B build -DPICO_SDK_PATH=/ruta/a/pico-sdk
#   cmake --build build
#
# Si PICO_SDK_PATH no se especifica, se busca por defecto en '../../pico-sdk'
# (layout tipico: <proyecto>/../../pico-sdk).
#
# El archivo build/analog_monitor.uf2 se arrastra a la Pico W en modo BOOTSEL.
# =============================================================================

cmake_minimum_required(VERSION 3.13)

# Placa Raspberry Pi Pico W (RP2040 + CYW43 WiFi). Sin esta opcion la pila
# lwIP no se enlaza y los headers pico/cyw43_arch.h ni lwip/* no se incluyen.
set(PICO_BOARD pico_w CACHE STRING "Placa Raspberry Pi Pico W")

# Ruta al SDK: primero honor a PICO_SDK_PATH (env o -D), luego ruta por defecto
if (NOT DEFINED ENV{PICO_SDK_PATH} AND NOT DEFINED PICO_SDK_PATH)
    set(PICO_SDK_PATH "${CMAKE_CURRENT_LIST_DIR}/../pico-sdk")
    message(STATUS "PICO_SDK_PATH no definido; usando ${PICO_SDK_PATH}")
endif ()

# Helper oficial para localizar el SDK (copia del SDK /external)
include(pico_sdk_import.cmake)

# Proyecto: lenguajes C y C++ (ASM necesario para el boot stage2 del SDK)
project(analog_monitor C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Inicializa el SDK de Pico (debe ir despues de project())
pico_sdk_init()

# ===========================================================================
# Ejecutable principal
# ===========================================================================
add_executable(analog_monitor
    main.cpp
    adc_reader.cpp
    http_server.cpp
)

# Incluir el directorio del proyecto para que lwIP encuentre lwipopts.h
target_include_directories(analog_monitor PRIVATE ${CMAKE_CURRENT_LIST_DIR})

# ===========================================================================
# Librerias enlazadas
# ===========================================================================
# pico_stdlib:
#   Abstraction de alto nivel del hardware (GPIO, UART, sleep, tiempo).
#
# hardware_adc:
#   Driver del ADC del RP2040 (canales ADC0-ADC2 = GPIO 26-28).
#
# pico_cyw43_arch_lwip_poll:
#   WiFi CYW43 + pila lwIP en modo poll (NO_SYS, RAW API). Requiere llamar a
#   cyw43_arch_poll() en el loop principal.
#
# pico_lwip_sntp:
#   Cliente SNTP de lwIP, usado para sincronizar la hora (epoch) y reportarla
#   en el campo "timestamp" de /api/analog.
# ===========================================================================
target_link_libraries(analog_monitor
    pico_stdlib
    hardware_adc
    pico_cyw43_arch_lwip_poll
    pico_lwip_sntp
)

# Genera archivos adicionales: .uf2 (flash), .elf, .bin, .hex, .dis
pico_add_extra_outputs(analog_monitor)

# Salida de depuracion: USB CDC (printf por USB) y UART desactivado
pico_enable_stdio_usb(analog_monitor 1)
pico_enable_stdio_uart(analog_monitor 0)

# ===========================================================================
# Definiciones de compilacion (macros)
# ===========================================================================
# WIFI_SSID / WIFI_PASSWORD: se editan en wifi_config.h (no se versiona nada
# sensible; wifi_config.h debe revisarse antes de publicar).
#
# HTTP_PORT: puerto del servidor HTTP (por defecto 80).
#
# ENABLE_SNTP / SNTP_SERVER: sincronizacion NTP para el campo "timestamp".
# ===========================================================================