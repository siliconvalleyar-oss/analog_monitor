#!/bin/bash
# config.sh - Configuración compartida para el proyecto analog_monitor.
#
# Portable: todas las rutas se resuelven desde la ubicación de este archivo y
# pueden sobre-escribirse con variables de entorno, p. ej.:
#   OPENOCD_BIN=/ruta/openocd     OPENOCD_SCRIPTS=/ruta/tcl
#   PICO_SDK_PATH=/ruta/pico-sdk  HIDAPI_LIB=/ruta/lib
#
# Uso desde cualquier script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.sh"

set -euo pipefail

# Raíz del repositorio (un nivel arriba de scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# Directorio y target del firmware. El proyecto CMake es analog_monitor y el
# binario queda en build/analog_monitor.{elf,uf2} (las fuentes están en la
# raíz del repo, no en src/). PROJECT se usa igual que keyboard_oled para
# poder reutilizar los mismos scripts de flasheo, pero el target es siempre
# analog_monitor.
PROJECT="${PROJECT:-analog_monitor}"
PROJECT_DIR="${PROJECT_DIR:-${REPO_ROOT}}"
PROJECT_CMAKE_TARGET="analog_monitor"
BUILD_DIR="${BUILD_DIR:-${PROJECT_DIR}/build}"
ELF_FILE="${ELF_FILE:-${BUILD_DIR}/${PROJECT_CMAKE_TARGET}.elf}"
UF2_FILE="${UF2_FILE:-${BUILD_DIR}/${PROJECT_CMAKE_TARGET}.uf2}"

# Placa: Pico W (WiFi CYW43 + lwIP).
BOARD="${BOARD:-pico_w}"

# --- Pico SDK -------------------------------------------------------------
if [ -z "${PICO_SDK_PATH:-}" ]; then
    if [ -d "${REPO_ROOT}/../pico-sdk" ]; then
        PICO_SDK_PATH="${REPO_ROOT}/../pico-sdk"
    else
        PICO_SDK_PATH=""
    fi
fi

# --- OpenOCD ---------------------------------------------------------------
if [ -z "${OPENOCD_BIN:-}" ]; then
    if command -v openocd >/dev/null 2>&1; then
        OPENOCD_BIN="$(command -v openocd)"
    else
        OPENOCD_BIN="openocd"
    fi
fi

# Directorio de scripts TCL de OpenOCD (arg -s)
if [ -z "${OPENOCD_SCRIPTS:-}" ]; then
    OPENOCD_SCRIPTS=""
    for d in \
        "$(dirname "$(readlink -f "$OPENOCD_BIN")")/../share/openocd/scripts" \
        "$(dirname "$(readlink -f "$OPENOCD_BIN")")/tcl" \
        "/usr/share/openocd/scripts" \
        "/usr/local/share/openocd/scripts"; do
        if [ -n "$d" ] && [ -d "$d" ]; then
            OPENOCD_SCRIPTS="$d"
            break
        fi
    done
fi

# --- hidapi (requerida por el driver CMSIS-DAP) ---------------------------
if [ -z "${HIDAPI_LIB:-}" ]; then
    HIDAPI_LIB=""
    for d in \
        "${REPO_ROOT}/../hidapi-install/lib" \
        "/usr/local/lib" \
        "/usr/lib/x86_64-linux-gnu"; do
        if [ -n "$d" ] && [ -d "$d" ] && ls "$d"/libhidapi-hidraw.so* >/dev/null 2>&1; then
            HIDAPI_LIB="$d"
            break
        fi
    done
fi

# Ejecutar OpenOCD con la ruta de libhidapi ya incorporada.
# Uso: run_openocd [args...]   (la config se pasa por argumento)
run_openocd() {
    local lib_path="${HIDAPI_LIB}"
    if [ -n "${LD_LIBRARY_PATH:-}" ]; then
        lib_path="${HIDAPI_LIB}:${LD_LIBRARY_PATH}"
    fi
    LD_LIBRARY_PATH="${lib_path}" \
        "${OPENOCD_BIN}" -s "${OPENOCD_SCRIPTS}" "$@"
}

print_toolchain() {
    echo "repo          : ${REPO_ROOT}"
    echo "pico-sdk      : ${PICO_SDK_PATH:-<no definido>}"
    echo "openocd       : ${OPENOCD_BIN}  (scripts: ${OPENOCD_SCRIPTS:-<no hallado>})"
    echo "hidapi libs   : ${HIDAPI_LIB:-<no hallado>}"
    echo "board         : ${BOARD}"
}
