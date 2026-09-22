#!/bin/bash
# Flasheo del firmware analog_monitor (Pico W) sin sudo por SWD (PicoProbe).
# Uso:
#   BOARD=pico_w ./scripts/exec.sh                          # compila + programa
#   BUILD_ONLY=1 ./scripts/exec.sh                          # solo compilar
#   BOARD=pico_w PROJECT_DIR=/ruta/otro ./scripts/exec.sh   # proyecto custom

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== analog_monitor :: Pico W (analog_monitor) ==="
echo "Toolchain:"
print_toolchain
echo "Target   : ${PROJECT_CMAKE_TARGET}  (ELF: ${ELF_FILE})"
echo ""

if [ -z "${BUILD_ONLY:-}" ]; then
    "${SCRIPT_DIR}/build.sh"
    "${SCRIPT_DIR}/flash_nosudo_multi.sh"
else
    "${SCRIPT_DIR}/build.sh"
fi
