#!/usr/bin/env bash
# lib/log.sh — logging estructurado (ISO8601 + nivel + mensaje) con rotación
# por tamaño. Requiere LOG_FILE, LOG_MAX_SIZE_KB (de config.sh) y now_iso
# (de util.sh) ya disponibles.

# _log_rotate_if_needed — si LOG_FILE supera LOG_MAX_SIZE_KB, lo mueve a
# .1 (sobrescribiendo el anterior). Sin dependencias externas (logrotate no
# es asumible en todos los sistemas); basta para un log de una sola app.
_log_rotate_if_needed() {
    [[ -f "$LOG_FILE" ]] || return 0
    local size_kb
    size_kb=$(du -k "$LOG_FILE" 2>/dev/null | awk '{print $1}')
    [[ -n "$size_kb" ]] || return 0
    if (( size_kb >= LOG_MAX_SIZE_KB )); then
        mv -f "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

# log_event LEVEL MESSAGE — escribe "timestamp LEVEL message" en LOG_FILE.
# LEVEL: INFO | WARN | CRITICAL | ERROR
log_event() {
    local level=$1 msg=$2
    _log_rotate_if_needed
    printf '%s %s %s\n' "$(now_iso)" "$level" "$msg" >> "$LOG_FILE"
}

# log_purge_old — borra logs rotados con más de LOG_RETENTION_DAYS de
# antigüedad. Se llama una vez por --check, es barato (find sobre un
# directorio pequeño).
log_purge_old() {
    find "$LOG_DIR" -maxdepth 1 -name 'sysguard.log.*' -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null || true
}
