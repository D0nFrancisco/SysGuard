#!/usr/bin/env bash
# lib/thresholds.sh — evalúa métricas contra los thresholds cargados por
# lib/config.sh y traduce estados a los exit codes documentados.

# threshold_status NAME VALUE — imprime OK|WARNING|CRITICAL comparando VALUE
# (entero) contra las variables <NAME>_WARNING/<NAME>_CRITICAL. NAME debe ser
# CPU|RAM|SWAP|DISK (coincide con los nombres usados en sysguard.conf).
threshold_status() {
    local name=$1 value=$2
    local warn_var="${name}_WARNING" crit_var="${name}_CRITICAL"
    local warn=${!warn_var} crit=${!crit_var}
    if (( value >= crit )); then
        echo "CRITICAL"
    elif (( value >= warn )); then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# network_status STATE — traduce el operstate de la interfaz a OK/WARNING/
# CRITICAL según NETWORK_DOWN de la config.
network_status() {
    local state=$1
    if [[ "$state" == "up" ]]; then
        echo "OK"
        return
    fi
    case "${NETWORK_DOWN:-critical}" in
        critical) echo "CRITICAL" ;;
        warning) echo "WARNING" ;;
        ignore) echo "OK" ;;
        *) echo "WARNING" ;;
    esac
}

# worst_status S1 S2 ... — imprime el peor estado de la lista (CRITICAL > WARNING > OK).
worst_status() {
    local worst="OK" s
    for s in "$@"; do
        case "$s" in
            CRITICAL) worst="CRITICAL" ;;
            WARNING) [[ "$worst" != "CRITICAL" ]] && worst="WARNING" ;;
        esac
    done
    echo "$worst"
}

# compute_worst_disk — recorre el array DISKS[] (poblado por
# metrics_collect_disks) y exporta WORST_DISK_STATUS, WORST_DISK_MOUNT y
# WORST_DISK_PCT: el disco más severo y, en caso de empate de severidad, el
# de mayor porcentaje de uso. Única fuente de esta selección: la usan tanto
# --check como --dashboard para no duplicar el criterio de "peor disco".
compute_worst_disk() {
    WORST_DISK_STATUS="OK"
    WORST_DISK_MOUNT=""
    WORST_DISK_PCT=-1
    local entry mnt type used total pct st
    for entry in "${DISKS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r mnt type used total pct <<<"$entry"
        st=$(threshold_status DISK "$pct")
        if (( WORST_DISK_PCT < 0 )) || \
           [[ "$(worst_status "$WORST_DISK_STATUS" "$st")" != "$WORST_DISK_STATUS" ]] || \
           { [[ "$st" == "$WORST_DISK_STATUS" ]] && (( pct > WORST_DISK_PCT )); }; then
            WORST_DISK_STATUS=$st
            WORST_DISK_MOUNT=$mnt
            WORST_DISK_PCT=$pct
        fi
    done
    if (( WORST_DISK_PCT < 0 )); then
        WORST_DISK_MOUNT="-"
        WORST_DISK_PCT=0
    fi
}

# status_exit_code STATUS — mapea OK/WARNING/CRITICAL al exit code de sysguard.
status_exit_code() {
    case "$1" in
        OK) echo "$EXIT_OK" ;;
        WARNING) echo "$EXIT_WARNING" ;;
        CRITICAL) echo "$EXIT_CRITICAL" ;;
        *) echo "$EXIT_ERROR" ;;
    esac
}
