#!/usr/bin/env bash
# tests/test_notify.sh — valida el escapado JSON de notify.sh y que
# notify_dispatch con NOTIFICATION_METHOD=none (el default) nunca invoque
# comandos externos (curl, hostname, ...): no debe hacer falta red para el
# camino por defecto.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$HERE")"
source "$HERE/helpers.sh"

source "$PROJECT_ROOT/lib/util.sh"
source "$PROJECT_ROOT/lib/notify.sh"

echo "_notify_json_escape escapa backslash"
assert_eq 'a\\b' "$(_notify_json_escape 'a\b')" "un backslash debe duplicarse"

echo "_notify_json_escape escapa comillas dobles"
assert_eq '\"cita\"' "$(_notify_json_escape '"cita"')" "las comillas dobles deben escaparse"

echo "_notify_json_escape escapa saltos de línea"
assert_eq 'linea1\nlinea2' "$(_notify_json_escape "$(printf 'linea1\nlinea2')")" "el salto de línea real debe volverse '\\n' literal"

echo "notify_dispatch(none) no invoca comandos externos (PATH vacío no debe romperlo)"
PROJECT_ROOT="$PROJECT_ROOT" bash -c '
    set -uo pipefail
    source "$PROJECT_ROOT/lib/util.sh"
    source "$PROJECT_ROOT/lib/notify.sh"
    export PATH=
    NOTIFICATION_METHOD=none notify_dispatch KEY OK "detail"
'
assert_eq "0" "$?" "notify_dispatch(none) debe salir 0 sin depender de PATH"

test_summary
