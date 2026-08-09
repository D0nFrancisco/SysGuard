#!/usr/bin/env bash
# lib/metrics.sh — única fuente de verdad para obtener métricas del sistema.
# check, dashboard, report e history llaman todos a estas mismas funciones,
# para que un cambio en cómo se mide algo no tenga que replicarse.

# ---- CPU + red: muestreo combinado -----------------------------------------
# Tanto CPU como el throughput de red son contadores acumulativos: hace falta
# una diferencia entre dos muestras separadas en el tiempo para obtener un
# valor instantáneo real (no el promedio desde el arranque del sistema, que
# es el bug que tenía la versión anterior). Se combinan en una sola espera
# de CPU_SAMPLE_INTERVAL para no penalizar el doble a --check.

_cpu_snapshot() {
    local line user nice system idle iowait irq softirq steal
    line=$(grep -m1 '^cpu ' /proc/stat) || die "no se pudo leer /proc/stat" "$EXIT_ERROR"
    read -r _ user nice system idle iowait irq softirq steal _ _ <<<"$line"
    local total=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
    local idle_all=$(( idle + iowait ))
    echo "$idle_all $total"
}

_net_snapshot() {
    local iface=$1
    if [[ -z "$iface" || ! -r "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
        echo "0 0"
        return
    fi
    echo "$(<"/sys/class/net/$iface/statistics/rx_bytes") $(<"/sys/class/net/$iface/statistics/tx_bytes")"
}

metrics_detect_iface() {
    ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

metrics_detect_gateway() {
    ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}'
}

# metrics_collect_realtime IFACE — exporta CPU_PERCENT, NET_RX_RATE y
# NET_TX_RATE (bytes/seg) tras esperar CPU_SAMPLE_INTERVAL segundos.
metrics_collect_realtime() {
    local iface=$1
    local idle0 total0 idle1 total1 rx0 tx0 rx1 tx1

    read -r idle0 total0 <<<"$(_cpu_snapshot)"
    read -r rx0 tx0 <<<"$(_net_snapshot "$iface")"

    sleep "$CPU_SAMPLE_INTERVAL"

    read -r idle1 total1 <<<"$(_cpu_snapshot)"
    read -r rx1 tx1 <<<"$(_net_snapshot "$iface")"

    local diff_idle=$(( idle1 - idle0 ))
    local diff_total=$(( total1 - total0 ))
    if (( diff_total <= 0 )); then
        CPU_PERCENT=0
    else
        CPU_PERCENT=$(awk -v di="$diff_idle" -v dt="$diff_total" 'BEGIN{printf "%.0f", (dt-di)*100/dt}')
    fi

    NET_RX_RATE=$(awk -v a="$rx0" -v b="$rx1" -v t="$CPU_SAMPLE_INTERVAL" 'BEGIN{d=b-a; if(d<0)d=0; printf "%.0f", d/t}')
    NET_TX_RATE=$(awk -v a="$tx0" -v b="$tx1" -v t="$CPU_SAMPLE_INTERVAL" 'BEGIN{d=b-a; if(d<0)d=0; printf "%.0f", d/t}')
}

# ---- RAM / Swap -------------------------------------------------------------

metrics_collect_ram() {
    local total avail
    total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    [[ -n "$total" && -n "$avail" ]] || die "no se pudo leer /proc/meminfo" "$EXIT_ERROR"
    RAM_TOTAL_KB=$total
    RAM_AVAILABLE_KB=$avail
    RAM_USED_KB=$(( total - avail ))
    RAM_PERCENT=$(awk -v u="$RAM_USED_KB" -v t="$total" 'BEGIN{ if(t==0){print 0} else {printf "%.0f", u*100/t} }')
}

metrics_collect_swap() {
    local total free
    total=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
    free=$(awk '/^SwapFree:/{print $2}' /proc/meminfo)
    total=${total:-0}
    free=${free:-0}
    SWAP_TOTAL_KB=$total
    SWAP_USED_KB=$(( total - free ))
    if (( total == 0 )); then
        SWAP_PERCENT=0
    else
        SWAP_PERCENT=$(awk -v u="$SWAP_USED_KB" -v t="$total" 'BEGIN{printf "%.0f", u*100/t}')
    fi
}

# ---- Load / uptime -----------------------------------------------------------

metrics_collect_load() {
    read -r LOAD1 LOAD5 LOAD15 _ _ < /proc/loadavg
}

metrics_collect_uptime() {
    local secs
    secs=$(awk '{print int($1)}' /proc/uptime)
    UPTIME_SECONDS=$secs
    local d=$(( secs / 86400 )) h=$(( (secs % 86400) / 3600 )) m=$(( (secs % 3600) / 60 ))
    if (( d > 0 )); then
        UPTIME_HUMAN="${d}d ${h}h ${m}m"
    elif (( h > 0 )); then
        UPTIME_HUMAN="${h}h ${m}m"
    else
        UPTIME_HUMAN="${m}m"
    fi
}

# ---- Disco --------------------------------------------------------------
# metrics_collect_disks — llena el array DISKS[] con entradas
# "mountpoint|fstype|used_kb|total_kb|percent". Autodetecta filesystems
# reales excluyendo pseudo-filesystems (DISK_EXCLUDE_TYPES); si DISK_PATHS
# no está vacío, limita la salida a esos puntos de montaje.
# Nota: puntos de montaje con espacios en el nombre no se soportan (caso
# extremadamente raro, fuera de alcance).
metrics_collect_disks() {
    DISKS=()
    local line fs type total used avail pct mnt
    local exclude=" $DISK_EXCLUDE_TYPES "
    local -A wanted=()
    local p
    if [[ -n "${DISK_PATHS:-}" ]]; then
        for p in $DISK_PATHS; do wanted["$p"]=1; done
    fi

    local lineno=0
    while IFS= read -r line; do
        lineno=$(( lineno + 1 ))
        # La primera línea de "df -T" es siempre el encabezado; se descarta
        # por posición, no por texto (el texto puede venir traducido según
        # el locale, p. ej. "Capacidad" en vez de "Capacity").
        (( lineno == 1 )) && continue
        read -r fs type total used avail pct mnt <<<"$line"
        [[ -z "$fs" ]] && continue
        pct=${pct%\%}
        [[ "$exclude" == *" $type "* ]] && continue
        if [[ -n "${DISK_PATHS:-}" ]] && [[ -z "${wanted[$mnt]:-}" ]]; then
            continue
        fi
        DISKS+=("$mnt|$type|$used|$total|$pct")
    done < <(df -P -T -k 2>/dev/null)
}

# ---- Red (estado, IP, gateway, velocidad) ------------------------------------

metrics_collect_network() {
    NET_IFACE=$(metrics_detect_iface)
    NET_GATEWAY=$(metrics_detect_gateway)

    if [[ -z "$NET_IFACE" ]]; then
        NET_STATE="down"
        NET_IP=""
        NET_SPEED="n/d"
        return
    fi

    NET_STATE=$(cat "/sys/class/net/$NET_IFACE/operstate" 2>/dev/null || echo "unknown")
    NET_IP=$(ip -4 -o addr show dev "$NET_IFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)

    if [[ -r "/sys/class/net/$NET_IFACE/speed" ]]; then
        NET_SPEED=$(cat "/sys/class/net/$NET_IFACE/speed" 2>/dev/null || echo "")
        [[ "$NET_SPEED" =~ ^[0-9]+$ ]] || NET_SPEED="n/d"
    else
        NET_SPEED="n/d"
    fi
}

# ---- Información general del sistema -----------------------------------------

metrics_collect_system() {
    SYS_HOSTNAME=$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo "desconocido")
    SYS_KERNEL=$(uname -r)
    SYS_ARCH=$(uname -m)

    if [[ -r /etc/os-release ]]; then
        SYS_DISTRO=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
    fi
    SYS_DISTRO=${SYS_DISTRO:-"desconocida"}

    SYS_CPU_MODEL=$(awk -F: '/^model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
    SYS_CPU_MODEL=${SYS_CPU_MODEL:-"desconocido"}
    SYS_CPU_COUNT=$(grep -c '^processor' /proc/cpuinfo)
    (( SYS_CPU_COUNT > 0 )) || SYS_CPU_COUNT=1
}
