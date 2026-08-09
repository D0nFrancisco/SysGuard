#!/usr/bin/env bash
# lib/config.sh — carga y valida config/sysguard.conf (+ secrets.conf opcional).
# Requiere que SYSGUARD_ROOT y lib/util.sh ya estén cargados.

readonly CONFIG_DIR="$SYSGUARD_ROOT/config"
readonly CONFIG_FILE="$CONFIG_DIR/sysguard.conf"
readonly SECRETS_FILE="$CONFIG_DIR/secrets.conf"

# Rutas fijas basadas en la ubicación del proyecto, nunca configurables como
# string relativo: esa fue la causa de que la versión anterior rompiera al
# ejecutarse desde un cwd distinto (p. ej. cron).
readonly LOG_DIR="$SYSGUARD_ROOT/logs"
readonly REPORT_DIR="$SYSGUARD_ROOT/reports"
readonly DATA_DIR="$SYSGUARD_ROOT/data"
readonly LOG_FILE="$LOG_DIR/sysguard.log"
readonly HISTORY_FILE="$DATA_DIR/history.csv"
readonly ALERT_STATE_FILE="$DATA_DIR/alerts.state"
readonly ALERT_LOCK_FILE="$DATA_DIR/alerts.lock"

_is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
_is_num() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; }

_validate_percent() {
    local name=$1 value=$2
    [[ -n "$value" ]] || die "config inválida: falta '$name' en $CONFIG_FILE" "$EXIT_ERROR"
    _is_int "$value" || die "config inválida: $name='$value' debe ser un entero" "$EXIT_ERROR"
    (( value >= 0 && value <= 100 )) || \
        die "config inválida: $name=$value debe estar entre 0 y 100" "$EXIT_ERROR"
}

_validate_pair() {
    local warn_name=$1 warn_val=$2 crit_name=$3 crit_val=$4
    _validate_percent "$warn_name" "$warn_val"
    _validate_percent "$crit_name" "$crit_val"
    (( warn_val < crit_val )) || \
        die "config inválida: $warn_name ($warn_val) debe ser menor que $crit_name ($crit_val)" "$EXIT_ERROR"
}

_validate_positive_int() {
    local name=$1 value=$2
    [[ -n "$value" ]] || die "config inválida: falta '$name' en $CONFIG_FILE" "$EXIT_ERROR"
    _is_int "$value" || die "config inválida: $name='$value' debe ser un entero" "$EXIT_ERROR"
}

_validate_config() {
    _validate_pair CPU_WARNING "${CPU_WARNING:-}" CPU_CRITICAL "${CPU_CRITICAL:-}"
    _validate_pair RAM_WARNING "${RAM_WARNING:-}" RAM_CRITICAL "${RAM_CRITICAL:-}"
    _validate_pair SWAP_WARNING "${SWAP_WARNING:-}" SWAP_CRITICAL "${SWAP_CRITICAL:-}"
    _validate_pair DISK_WARNING "${DISK_WARNING:-}" DISK_CRITICAL "${DISK_CRITICAL:-}"

    case "${NETWORK_DOWN:-}" in
        critical|warning|ignore) ;;
        *) die "config inválida: NETWORK_DOWN='${NETWORK_DOWN:-}' debe ser critical|warning|ignore" "$EXIT_ERROR" ;;
    esac

    [[ -n "${CPU_SAMPLE_INTERVAL:-}" ]] || die "config inválida: falta 'CPU_SAMPLE_INTERVAL' en $CONFIG_FILE" "$EXIT_ERROR"
    _is_num "$CPU_SAMPLE_INTERVAL" || die "config inválida: CPU_SAMPLE_INTERVAL='$CPU_SAMPLE_INTERVAL' debe ser numérico" "$EXIT_ERROR"
    awk -v v="$CPU_SAMPLE_INTERVAL" 'BEGIN{ exit !(v > 0) }' || \
        die "config inválida: CPU_SAMPLE_INTERVAL debe ser mayor que 0" "$EXIT_ERROR"

    _validate_positive_int ALERT_COOLDOWN "${ALERT_COOLDOWN:-}"

    case "${HISTORY_ENABLED:-}" in
        true|false) ;;
        *) die "config inválida: HISTORY_ENABLED='${HISTORY_ENABLED:-}' debe ser true|false" "$EXIT_ERROR" ;;
    esac
    _validate_positive_int HISTORY_RETENTION_DAYS "${HISTORY_RETENTION_DAYS:-}"

    _validate_positive_int LOG_MAX_SIZE_KB "${LOG_MAX_SIZE_KB:-}"
    _validate_positive_int LOG_RETENTION_DAYS "${LOG_RETENTION_DAYS:-}"

    case "${NOTIFICATION_METHOD:-none}" in
        none|webhook) ;;
        *) die "config inválida: NOTIFICATION_METHOD='${NOTIFICATION_METHOD}' debe ser none|webhook" "$EXIT_ERROR" ;;
    esac

    if [[ "${NOTIFICATION_METHOD:-none}" == "webhook" && -z "${WEBHOOK_URL:-}" ]]; then
        die "NOTIFICATION_METHOD=webhook pero WEBHOOK_URL no está definido. Crea $SECRETS_FILE a partir de secrets.conf.example." "$EXIT_ERROR"
    fi
}

# load_config — source de sysguard.conf (+ secrets.conf si existe), crea los
# directorios de datos/logs/reportes y valida todos los valores.
load_config() {
    [[ -f "$CONFIG_FILE" ]] || die "no se encontró el archivo de configuración: $CONFIG_FILE" "$EXIT_ERROR"
    [[ -r "$CONFIG_FILE" ]] || die "no se puede leer $CONFIG_FILE (revisa permisos)" "$EXIT_ERROR"

    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    if [[ -f "$SECRETS_FILE" ]]; then
        [[ -r "$SECRETS_FILE" ]] || die "no se puede leer $SECRETS_FILE (revisa permisos)" "$EXIT_ERROR"
        # shellcheck source=/dev/null
        source "$SECRETS_FILE"
    fi

    mkdir -p "$LOG_DIR" "$REPORT_DIR" "$DATA_DIR" 2>/dev/null || \
        die "no se pudieron crear los directorios de datos ($LOG_DIR, $REPORT_DIR, $DATA_DIR) — revisa permisos" "$EXIT_ERROR"

    local d
    for d in "$LOG_DIR" "$REPORT_DIR" "$DATA_DIR"; do
        [[ -w "$d" ]] || die "sin permiso de escritura en $d" "$EXIT_ERROR"
    done

    _validate_config
}
