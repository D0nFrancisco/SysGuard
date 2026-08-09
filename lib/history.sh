#!/usr/bin/env bash
# lib/history.sh — historial ligero en CSV (sin base de datos). Una fila por
# --check: timestamp,hostname,cpu,ram,swap,disk,load,rx,tx,status.
# Requiere HISTORY_FILE, HISTORY_RETENTION_DAYS (config.sh) y now_iso (util.sh).

readonly HISTORY_HEADER="timestamp,hostname,cpu,ram,swap,disk,load,rx,tx,status"

# history_record CPU RAM SWAP DISK LOAD1 RX TX STATUS — agrega una fila.
history_record() {
    local cpu=$1 ram=$2 swap=$3 disk=$4 load=$5 rx=$6 tx=$7 status=$8
    local host
    host=$(hostname 2>/dev/null || echo "unknown")

    [[ -f "$HISTORY_FILE" ]] || echo "$HISTORY_HEADER" > "$HISTORY_FILE"
    echo "$(now_iso),$host,$cpu,$ram,$swap,$disk,$load,$rx,$tx,$status" >> "$HISTORY_FILE"
}

# history_prune — elimina filas más antiguas que HISTORY_RETENTION_DAYS.
# Compara el prefijo de fecha (YYYY-MM-DD) como string: como todas las
# filas se generan en el mismo host con el mismo offset de zona horaria,
# la comparación lexicográfica de ISO8601 es equivalente a comparar fechas
# reales, sin tener que parsear cada timestamp a epoch.
history_prune() {
    [[ -f "$HISTORY_FILE" ]] || return 0
    local cutoff
    cutoff=$(date -d "-${HISTORY_RETENTION_DAYS} days" '+%Y-%m-%d')
    local tmp="${HISTORY_FILE}.tmp.$$"
    {
        echo "$HISTORY_HEADER"
        tail -n +2 "$HISTORY_FILE" | awk -F, -v c="$cutoff" 'substr($1,1,10) >= c'
    } > "$tmp"
    mv -f "$tmp" "$HISTORY_FILE"
}

# history_stats HOURS — exporta agregados de las filas de los últimos HOURS:
# HIST_ROWS, HIST_CPU_AVG/MIN/MAX, HIST_RAM_AVG/MIN/MAX, HIST_DISK_FIRST,
# HIST_DISK_CURRENT, HIST_DISK_CHANGE.
history_stats() {
    local hours=$1
    HIST_ROWS=0
    HIST_CPU_AVG=0; HIST_CPU_MIN=0; HIST_CPU_MAX=0
    HIST_RAM_AVG=0; HIST_RAM_MIN=0; HIST_RAM_MAX=0
    HIST_DISK_FIRST=0; HIST_DISK_CURRENT=0; HIST_DISK_CHANGE=0

    [[ -f "$HISTORY_FILE" ]] || return 0

    local cutoff stats
    cutoff=$(date -d "-${hours} hours" '+%Y-%m-%dT%H:%M:%S')

    stats=$(tail -n +2 "$HISTORY_FILE" | awk -F, -v c="$cutoff" '
        substr($1,1,19) >= c {
            n++
            cpu=$3+0; ram=$4+0; disk=$6+0
            cpu_sum+=cpu; ram_sum+=ram
            if (n==1 || cpu<cpu_min) cpu_min=cpu
            if (n==1 || cpu>cpu_max) cpu_max=cpu
            if (n==1 || ram<ram_min) ram_min=ram
            if (n==1 || ram>ram_max) ram_max=ram
            if (n==1) disk_first=disk
            disk_last=disk
        }
        END {
            if (n>0) {
                printf "%d %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f\n", \
                    n, cpu_sum/n, cpu_min, cpu_max, ram_sum/n, ram_min, ram_max, disk_first, disk_last
            } else {
                print "0 0 0 0 0 0 0 0 0"
            }
        }
    ')
    read -r HIST_ROWS HIST_CPU_AVG HIST_CPU_MIN HIST_CPU_MAX HIST_RAM_AVG HIST_RAM_MIN HIST_RAM_MAX HIST_DISK_FIRST HIST_DISK_CURRENT <<<"$stats"
    HIST_DISK_CHANGE=$(awk -v a="$HIST_DISK_FIRST" -v b="$HIST_DISK_CURRENT" 'BEGIN{printf "%.1f", b-a}')
}
