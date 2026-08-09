#!/usr/bin/env bash
# tests/test_config.sh — valida que config.sh acepte configuración correcta
# y rechace (con exit code 3) rangos inválidos, orden warning>=critical y
# archivo de config ausente.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$HERE")"
FIXTURES="$HERE/fixtures"
source "$HERE/helpers.sh"

# _config_exit_code FIXTURE_ROOT — corre load_config en un subproceso
# aislado con SYSGUARD_ROOT apuntando al fixture, e imprime su exit code.
_config_exit_code() {
    local fixture_root=$1
    SYSGUARD_ROOT="$fixture_root" PROJECT_LIB="$PROJECT_ROOT/lib" bash -c '
        set -uo pipefail
        source "$PROJECT_LIB/util.sh"
        source "$PROJECT_LIB/config.sh"
        load_config
    ' >/dev/null 2>&1
    echo $?
}

echo "config válida carga sin error"
assert_eq "0" "$(_config_exit_code "$FIXTURES/config_valid")" "config válida debe cargar (exit 0)"

echo "CPU_WARNING fuera de rango (150) falla con exit 3"
assert_eq "3" "$(_config_exit_code "$FIXTURES/config_invalid_range")" "CPU_WARNING=150 debe fallar"

echo "CPU_WARNING >= CPU_CRITICAL falla con exit 3"
assert_eq "3" "$(_config_exit_code "$FIXTURES/config_invalid_order")" "CPU_WARNING=95 >= CPU_CRITICAL=90 debe fallar"

echo "config ausente falla con exit 3"
assert_eq "3" "$(_config_exit_code "$FIXTURES/config_missing")" "sin config/sysguard.conf debe fallar"

# Limpieza: load_config crea logs/reports/data dentro de cada fixture.
rm -rf "$FIXTURES"/config_valid/{logs,reports,data} \
       "$FIXTURES"/config_invalid_range/{logs,reports,data} \
       "$FIXTURES"/config_invalid_order/{logs,reports,data} \
       "$FIXTURES"/config_missing/{logs,reports,data} 2>/dev/null

test_summary
