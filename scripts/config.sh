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
PROJECT_DIR="${PROJECT_DIR:-${REPO_ROOT}/analog_pico}"
PROJECT_CMAKE_TARGET="analog_monitor"
BUILD_DIR="${BUILD_DIR:-${PROJECT_DIR}/build}"
ELF_FILE="${ELF_FILE:-${BUILD_DIR}/${PROJECT_CMAKE_TARGET}.elf}"
UF2_FILE="${UF2_FILE:-${BUILD_DIR}/${PROJECT_CMAKE_TARGET}.uf2}"

# Placa (target de build). Puede venir del entorno (BOARD=pico_w ...); si no,
# flash_nosudo_multi.sh la pide por menú y la persiste en .last-flash-config.
# Combina placas RP2040 (pico/pico_w) y RP2350 (pico2/pico2w).
BOARD="${BOARD:-}"
BOARD_BOARDS=(pico pico_w pico2 pico2w)
BOARD_LABELS=(
    "Pico (RP2040)"
    "Pico W (RP2040 + WiFi)"
    "Pico 2 (RP2350)"
    "Pico 2 W (RP2350 + WiFi)"
)

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

# ---------------------------------------------------------------------------
# Menú BOARD persistente.
# ---------------------------------------------------------------------------
# La última selección (BOARD + ruta del proyecto) se guarda en
# .last-flash-config dentro de scripts/ (no se versiona). Cualquier script que
# haga source de config.sh puede:
#   - leer "${BOARD}" (ya resuelto: entorno > última guardada),
#   - ofrecer pick_board() para re-preguntar y persistir.
LAST_FLASH_CONFIG="${LAST_FLASH_CONFIG:-${REPO_ROOT}/scripts/.last-flash-config}"

load_last_flash_config() {
    [ -r "${LAST_FLASH_CONFIG}" ] || return 0
    LAST_PROJECT_DIR=""
    local _b _p
    _b="$(sed -nE 's/^BOARD=(.*)$/\1/p' "${LAST_FLASH_CONFIG}" | tail -1 || true)"
    _p="$(sed -nE 's/^PROJECT_DIR=(.*)$/\1/p' "${LAST_FLASH_CONFIG}" | tail -1 || true)"
    if [ -n "${_b}" ] && [ -z "${BOARD}" ]; then
        BOARD="${_b}"
    fi
    if [ -n "${_p}" ] && [ -d "${_p}" ]; then
        LAST_PROJECT_DIR="${_p}"
    fi
}

save_last_flash_config() {
    local p="${1:-${LAST_PROJECT_DIR:-${PROJECT_DIR:-}}}"
    umask 077
    cat > "${LAST_FLASH_CONFIG}" <<EOF
# Última selección de flasheo (persistida por pick_board / flash_nosudo_multi).
# No editar a mano.
BOARD=${BOARD}
PROJECT_DIR=${p}
EOF
}

# Pregunta la placa por menú (solo cuando BOARD no viene del entorno) y guarda
# la última selección para que la siguiente invocación no vuelva a preguntar.
# Uso: pick_board [proyecto_dir]
pick_board() {
    local proj="${1:-}"
    if [ -n "${BOARD}" ]; then
        return 0
    fi
    load_last_flash_config
    if [ -n "${BOARD}" ] && [ -z "${proj}" ]; then
        # Ya venía de la config persistente: mantener proyecto guardado si no
        # se pasó uno explícito.
        :
    fi

    echo ""
    echo "=== Seleccione la placa (BOARD) ==="
    local i
    i=1
    for b in "${BOARD_BOARDS[@]}"; do
        printf "  %2d) %s\n" "${i}" "${b}"
        i=$((i + 1))
    done
    echo ""
    echo "Última selección guardada: BOARD=${BOARD:-<ninguna>}"

    while true; do
        printf "Su elección [1-%d] ('q' para salir): " "${#BOARD_BOARDS[@]}"
        read -r sel
        [ -z "${sel}" ] && continue
        if [ "${sel}" = "q" ] || [ "${sel}" = "Q" ]; then
            echo "Saliendo."
            exit 0
        fi
        if [[ "${sel}" =~ ^[0-9]+$ ]] && [ "${sel}" -ge 1 ] && [ "${sel}" -le "${#BOARD_BOARDS[@]}" ]; then
            BOARD="${BOARD_BOARDS[$((sel - 1))]}"
            save_last_flash_config "${proj}"
            return 0
        fi
        echo "  -> Opción inválida (${sel})."
    done
}

# Cargar una última selección existente al hacer source (si BOARD no vino por env)
if [ -z "${BOARD}" ]; then
    load_last_flash_config
fi
