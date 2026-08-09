#!/usr/bin/env bash
# tests/test_thresholds.sh — prueba lib/thresholds.sh en aislamiento,
# definiendo a mano las variables de umbral que normalmente pondría
# config.sh (thresholds.sh no depende de cargar un archivo real).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$HERE")"
source "$HERE/helpers.sh"

CPU_WARNING=70; CPU_CRITICAL=90
RAM_WARNING=75; RAM_CRITICAL=90
SWAP_WARNING=50; SWAP_CRITICAL=80
DISK_WARNING=80; DISK_CRITICAL=90
NETWORK_DOWN=critical
EXIT_OK=0; EXIT_WARNING=1; EXIT_CRITICAL=2; EXIT_ERROR=3

# shellcheck source=../lib/thresholds.sh
source "$PROJECT_ROOT/lib/thresholds.sh"

echo "threshold_status: límites básicos (WARNING/CRITICAL son inclusivos)"
assert_eq "OK" "$(threshold_status CPU 0)" "0% debe ser OK"
assert_eq "OK" "$(threshold_status CPU 69)" "69% debe ser OK"
assert_eq "WARNING" "$(threshold_status CPU 70)" "70% (== warning) debe ser WARNING"
assert_eq "WARNING" "$(threshold_status CPU 89)" "89% debe ser WARNING"
assert_eq "CRITICAL" "$(threshold_status CPU 90)" "90% (== critical) debe ser CRITICAL"
assert_eq "CRITICAL" "$(threshold_status CPU 100)" "100% debe ser CRITICAL"

echo "network_status respeta NETWORK_DOWN"
assert_eq "OK" "$(network_status up)" "interfaz up debe ser OK"
assert_eq "CRITICAL" "$(network_status down)" "NETWORK_DOWN=critical -> down debe ser CRITICAL"
NETWORK_DOWN=warning
assert_eq "WARNING" "$(network_status down)" "NETWORK_DOWN=warning -> down debe ser WARNING"
NETWORK_DOWN=ignore
assert_eq "OK" "$(network_status down)" "NETWORK_DOWN=ignore -> down debe ser OK"
NETWORK_DOWN=critical

echo "worst_status prioriza CRITICAL > WARNING > OK"
assert_eq "OK" "$(worst_status OK OK)" "todos OK -> OK"
assert_eq "WARNING" "$(worst_status OK WARNING OK)" "un WARNING en la lista -> WARNING"
assert_eq "CRITICAL" "$(worst_status OK WARNING CRITICAL)" "hay un CRITICAL -> CRITICAL"
assert_eq "CRITICAL" "$(worst_status CRITICAL OK)" "orden de argumentos no importa"

echo "status_exit_code mapea a los exit codes documentados"
assert_eq "0" "$(status_exit_code OK)" "OK -> 0"
assert_eq "1" "$(status_exit_code WARNING)" "WARNING -> 1"
assert_eq "2" "$(status_exit_code CRITICAL)" "CRITICAL -> 2"
assert_eq "3" "$(status_exit_code GARBAGE)" "estado desconocido -> ERROR (3)"

echo "compute_worst_disk elige el más severo y, en empate, el de mayor uso"
DISKS=("/|btrfs|100|1000|50" "/home|btrfs|900|1000|90" "/boot|vfat|100|1000|10")
compute_worst_disk
assert_eq "CRITICAL" "$WORST_DISK_STATUS" "90% debe ser CRITICAL"
assert_eq "/home" "$WORST_DISK_MOUNT" "debe elegir /home como peor disco"
assert_eq "90" "$WORST_DISK_PCT" "porcentaje del peor disco"

DISKS=("/|btrfs|100|1000|50" "/var|btrfs|100|1000|60")
compute_worst_disk
assert_eq "OK" "$WORST_DISK_STATUS" "ambos discos en OK"
assert_eq "/var" "$WORST_DISK_MOUNT" "entre dos OK, elige el de mayor porcentaje"

DISKS=()
compute_worst_disk
assert_eq "OK" "$WORST_DISK_STATUS" "sin discos detectados, status por defecto OK"
assert_eq "-" "$WORST_DISK_MOUNT" "sin discos detectados, mount por defecto '-'"
assert_eq "0" "$WORST_DISK_PCT" "sin discos detectados, pct por defecto 0"

test_summary
