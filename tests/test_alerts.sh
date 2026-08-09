#!/usr/bin/env bash
# tests/test_alerts.sh — valida las transiciones de alert_evaluate
# (NOTIFY_ALERT/NOTIFY_RECOVERY/SUPPRESSED/NONE), el cooldown y que el
# estado persista en ALERT_STATE_FILE entre invocaciones separadas (cada
# check de sysguard es un proceso nuevo, igual que en cron).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$HERE")"
source "$HERE/helpers.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# _alert_eval STATE_FILE COOLDOWN KEY STATUS — corre alert_evaluate en un
# proceso aislado (simula una invocación real de sysguard --check) e
# imprime el resultado.
_alert_eval() {
    local state_file=$1 cooldown=$2 key=$3 status=$4
    ALERT_STATE_FILE="$state_file" ALERT_LOCK_FILE="${state_file}.lock" \
    ALERT_COOLDOWN="$cooldown" PROJECT_LIB="$PROJECT_ROOT/lib" \
    KEY="$key" STATUS="$status" bash -c '
        set -uo pipefail
        source "$PROJECT_LIB/util.sh"
        source "$PROJECT_LIB/alerts.sh"
        alert_evaluate "$KEY" "$STATUS"
    '
}

state="$WORKDIR/alerts.state"

echo "primera transición a WARNING dispara NOTIFY_ALERT"
assert_eq "NOTIFY_ALERT" "$(_alert_eval "$state" 300 CPU WARNING)" "primer WARNING debe notificar"

echo "mismo estado WARNING dentro del cooldown queda SUPPRESSED"
assert_eq "SUPPRESSED" "$(_alert_eval "$state" 300 CPU WARNING)" "segundo WARNING inmediato debe suprimirse (evita spam)"

echo "escalar WARNING -> CRITICAL notifica aunque el cooldown siga activo"
assert_eq "NOTIFY_ALERT" "$(_alert_eval "$state" 300 CPU CRITICAL)" "cambio de estado ignora el cooldown"

echo "volver a OK dispara NOTIFY_RECOVERY"
assert_eq "NOTIFY_RECOVERY" "$(_alert_eval "$state" 300 CPU OK)" "recuperación debe notificarse una vez"

echo "OK repetido no genera ruido"
assert_eq "NONE" "$(_alert_eval "$state" 300 CPU OK)" "OK consecutivo no debe notificar"

echo "con ALERT_COOLDOWN=0 cada check re-notifica el mismo estado"
state2="$WORKDIR/alerts_nocooldown.state"
_alert_eval "$state2" 0 RAM WARNING >/dev/null
assert_eq "NOTIFY_ALERT" "$(_alert_eval "$state2" 0 RAM WARNING)" "cooldown=0 no debe suprimir"

echo "el estado persiste en ALERT_STATE_FILE (una sola línea por key)"
assert_eq "1" "$(grep -c '^CPU ' "$state")" "no debe haber líneas duplicadas para la key CPU"

test_summary
