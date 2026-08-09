#!/usr/bin/env bash
# lib/util.sh — helpers compartidos: exit codes, errores, dependencias, tty, tiempo.
#
# Exit codes de SysGuard (usados por sysguard --check y por cualquier comando
# que evalúe estado): se documentan aquí porque son el contrato con cron/CI.
readonly EXIT_OK=0
readonly EXIT_WARNING=1
readonly EXIT_CRITICAL=2
readonly EXIT_ERROR=3

# die MSG [CODE]
# Imprime un error uniforme a stderr y termina el proceso. CODE por defecto
# es EXIT_ERROR (3) porque die() se usa para fallos de ejecución/config,
# nunca para reportar un estado WARNING/CRITICAL de una métrica.
die() {
    local msg=$1
    local code=${2:-$EXIT_ERROR}
    echo "sysguard: error: $msg" >&2
    exit "$code"
}

# require_cmd CMD — aborta con un mensaje claro si el comando no existe.
require_cmd() {
    local cmd=$1
    command -v "$cmd" >/dev/null 2>&1 || \
        die "falta el comando requerido '$cmd'. Instálalo e intenta de nuevo." "$EXIT_ERROR"
}

# has_cmd CMD — igual que require_cmd pero sin abortar (para dependencias opcionales).
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

is_tty() {
    [[ -t 1 ]]
}

now_iso() {
    date '+%Y-%m-%dT%H:%M:%S%:z'
}

now_epoch() {
    date '+%s'
}
