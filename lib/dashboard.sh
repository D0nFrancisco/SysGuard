#!/usr/bin/env bash
# lib/dashboard.sh — panel interactivo en terminal. Construido con un ancho
# de contenido fijo (DASH_INNER) para que las barras y símbolos Unicode
# (que no tienen un ancho de "caracteres" fiable bajo LC_ALL=C) nunca se
# midan en tiempo de ejecución: cada campo se trunca/rellena a un ancho
# constante conocido de antemano con _fit, y solo entonces se decora con
# color o se concatena junto a caracteres de barra/caja, que se generan
# repitiendo un carácter un número exacto de veces (nunca midiendo strings
# que ya los contienen).

readonly DASH_INNER=58
readonly DASH_BAR_WIDTH=30

# _repeat_char CHAR COUNT — imprime CHAR repetido COUNT veces.
_repeat_char() {
    local char=$1 count=$2 out="" i
    for (( i = 0; i < count; i++ )); do out+="$char"; done
    printf '%s' "$out"
}

# _fit TEXT WIDTH — trunca o rellena TEXT (ASCII plano, sin color ni
# símbolos) a exactamente WIDTH columnas.
_fit() {
    local text=$1 width=$2
    printf '%-*s' "$width" "${text:0:width}"
}

_dash_top()    { printf '%s%s%s\n' "$BOX_TL" "$(_repeat_char "$BOX_H" $((DASH_INNER + 2)))" "$BOX_TR"; }
_dash_mid()    { printf '%s%s%s\n' "$BOX_ML" "$(_repeat_char "$BOX_H" $((DASH_INNER + 2)))" "$BOX_MR"; }
_dash_bottom() { printf '%s%s%s\n' "$BOX_BL" "$(_repeat_char "$BOX_H" $((DASH_INNER + 2)))" "$BOX_BR"; }
_dash_row()    { printf '%s %s %s\n' "$BOX_V" "$1" "$BOX_V"; }

_dash_header_row() {
    local host=$1 uptime=$2
    _dash_row "$(_fit "hostname: $host" 38)$(_fit "uptime: $uptime" 20)"
}

_dash_metric_row() {
    local label=$1 pct=$2 status=$3
    local filled=$(( pct * DASH_BAR_WIDTH / 100 ))
    (( filled > DASH_BAR_WIDTH )) && filled=$DASH_BAR_WIDTH
    (( filled < 0 )) && filled=0
    local bar
    bar="$(_repeat_char "$BAR_FULL" "$filled")$(_repeat_char "$BAR_EMPTY" $((DASH_BAR_WIDTH - filled)))"
    local content
    content="$(_fit "$label" 8) ${bar} $(_fit "${pct}%" 6)  "
    content+="$(status_color "$status")$(status_symbol "$status") $(_fit "$status" 8)${COLOR_RESET}"
    _dash_row "$content"
}

_dash_load_row() {
    _dash_row "$(_fit "LOAD" 8)$(_fit "$1 / $2 / $3" 50)"
}

_dash_network_row() {
    local iface=$1 state=$2 status=$3 rx=$4 tx=$5
    local content
    content="$(_fit "NETWORK" 8) $(_fit "$iface" 9) "
    content+="$(status_color "$status")$(_fit "${state^^}" 7)${COLOR_RESET} "
    content+="$(_fit "RX: $rx" 15) $(_fit "TX: $tx" 15)"
    _dash_row "$content"
}

_dash_process_header() {
    _dash_row "$(_fit "PROCESSES (top CPU)" "$DASH_INNER")"
}

_dash_process_row() {
    local comm=$1 pcpu=$2 mem_human=$3
    _dash_row "$(_fit "$comm" 16) $(_fit "${pcpu}% CPU" 12)  $(_fit "${mem_human} RAM" 27)"
}

# dashboard_render — pinta un frame completo. Asume que metrics_collect_* y
# compute_worst_disk ya corrieron y que las variables globales (CPU_PERCENT,
# RAM_PERCENT, WORST_DISK_PCT, ...) están pobladas, igual que en cmd_check:
# dashboard no vuelve a calcular nada, solo reutiliza lib/metrics.sh y
# lib/thresholds.sh.
dashboard_render() {
    local cpu_status ram_status swap_status net_status
    cpu_status=$(threshold_status CPU "$CPU_PERCENT")
    ram_status=$(threshold_status RAM "$RAM_PERCENT")
    swap_status=$(threshold_status SWAP "$SWAP_PERCENT")
    net_status=$(network_status "${NET_STATE:-down}")

    _dash_top
    _dash_header_row "$SYS_HOSTNAME" "$UPTIME_HUMAN"
    _dash_mid
    _dash_metric_row "CPU" "$CPU_PERCENT" "$cpu_status"
    _dash_metric_row "RAM" "$RAM_PERCENT" "$ram_status"
    _dash_metric_row "SWAP" "$SWAP_PERCENT" "$swap_status"
    _dash_metric_row "DISK" "$WORST_DISK_PCT" "$WORST_DISK_STATUS"
    _dash_mid
    _dash_load_row "$LOAD1" "$LOAD5" "$LOAD15"
    _dash_network_row "${NET_IFACE:-none}" "${NET_STATE:-down}" "$net_status" \
        "$(numfmt --to=iec --suffix=/s "$NET_RX_RATE" 2>/dev/null || echo "${NET_RX_RATE}B/s")" \
        "$(numfmt --to=iec --suffix=/s "$NET_TX_RATE" 2>/dev/null || echo "${NET_TX_RATE}B/s")"
    _dash_mid
    _dash_process_header
    local line pid user pcpu pmem rss comm rss_h
    while IFS= read -r line; do
        read -r pid user pcpu pmem rss comm <<<"$line"
        rss_h=$(numfmt --from-unit=1024 --to=iec "$rss" 2>/dev/null || echo "${rss}K")
        _dash_process_row "$comm" "$pcpu" "$rss_h"
    done < <(processes_top cpu 5)
    _dash_bottom
}
