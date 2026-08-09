#!/usr/bin/env bash
# lib/notify.sh — despacho de notificaciones desacoplado del resto de
# sysguard. Hoy soporta NOTIFICATION_METHOD=none|webhook; agregar un nuevo
# proveedor implica sumar un "case" aquí, sin tocar alerts.sh ni sysguard.
#
#   SysGuard
#      │
#      ├── CLI (check/dashboard/report/history/...)
#      └── notify_dispatch
#             └── webhook (curl, opcional, degrada sin romper el check)

# _notify_json_escape TEXT — escapa \, " y saltos de línea para insertar
# TEXT de forma segura dentro de un valor de string JSON.
_notify_json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

_notify_webhook() {
    local key=$1 status=$2 detail=$3

    if ! has_cmd curl; then
        log_event ERROR "notify: NOTIFICATION_METHOD=webhook pero 'curl' no está instalado; notificación no enviada"
        return 0
    fi

    local host payload
    host=$(hostname 2>/dev/null || echo "unknown")
    payload=$(printf '{"host":"%s","key":"%s","status":"%s","detail":"%s","timestamp":"%s"}' \
        "$(_notify_json_escape "$host")" \
        "$(_notify_json_escape "$key")" \
        "$(_notify_json_escape "$status")" \
        "$(_notify_json_escape "$detail")" \
        "$(_notify_json_escape "$(now_iso)")")

    local http_code
    http_code=$(curl -sS -o /dev/null -w '%{http_code}' -m 10 \
        -X POST -H 'Content-Type: application/json' \
        -d "$payload" "$WEBHOOK_URL" 2>/dev/null) || http_code="000"

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        log_event INFO "notify: webhook enviado ($key=$status, http=$http_code)"
    else
        log_event ERROR "notify: webhook falló ($key=$status, http=$http_code) — revisa WEBHOOK_URL en config/secrets.conf"
    fi
}

# notify_dispatch KEY STATUS DETAIL — envía la notificación según
# NOTIFICATION_METHOD. Nunca debe interrumpir sysguard: cualquier fallo se
# registra en el log estructurado y la ejecución continúa.
notify_dispatch() {
    local key=$1 status=$2 detail=$3
    case "${NOTIFICATION_METHOD:-none}" in
        none) ;;
        webhook) _notify_webhook "$key" "$status" "$detail" ;;
    esac
}
