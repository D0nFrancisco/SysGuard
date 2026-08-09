#!/usr/bin/env bash
# lib/report.sh — genera reports/status.html: un snapshot en HTML + CSS
# puro (sin JS, sin frameworks) de las mismas métricas que --check y
# --dashboard, reutilizando lib/metrics.sh, lib/thresholds.sh, lib/history.sh
# y lib/processes.sh como única fuente de datos.

# _html_escape TEXT — escapa &, <, > y " para insertar texto de fuentes del
# sistema (hostname, nombre de proceso, usuario) de forma segura en el HTML.
_html_escape() {
    local s=$1
    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\"/&quot;}
    printf '%s' "$s"
}

_report_status_class() {
    case "$1" in
        OK) echo "ok" ;;
        WARNING) echo "warn" ;;
        CRITICAL) echo "crit" ;;
        *) echo "unknown" ;;
    esac
}

_report_metric_card() {
    local label=$1 pct=$2 status=$3
    local cls
    cls=$(_report_status_class "$status")
    cat <<EOF
      <div class="card">
        <div class="card-head">
          <span class="card-label">${label}</span>
          <span class="badge badge-${cls}">${status}</span>
        </div>
        <div class="bar"><div class="bar-fill fill-${cls}" style="width:${pct}%"></div></div>
        <div class="card-value">${pct}%</div>
      </div>
EOF
}

_report_disk_rows() {
    local entry mnt type used total pct st cls
    for entry in "${DISKS[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r mnt type used total pct <<<"$entry"
        st=$(threshold_status DISK "$pct")
        cls=$(_report_status_class "$st")
        cat <<EOF
        <tr>
          <td>$(_html_escape "$mnt")</td>
          <td>$(_html_escape "$type")</td>
          <td>$(numfmt --from-unit=1024 --to=iec "$used" 2>/dev/null || echo "${used}K") / $(numfmt --from-unit=1024 --to=iec "$total" 2>/dev/null || echo "${total}K")</td>
          <td><span class="badge badge-${cls}">${st} ${pct}%</span></td>
        </tr>
EOF
    done
}

_report_process_rows() {
    local pid user pcpu pmem rss comm rss_h
    while read -r pid user pcpu pmem rss comm; do
        rss_h=$(numfmt --from-unit=1024 --to=iec "$rss" 2>/dev/null || echo "${rss}K")
        cat <<EOF
        <tr>
          <td>${pid}</td>
          <td>$(_html_escape "$user")</td>
          <td>$(_html_escape "$comm")</td>
          <td>${pcpu}%</td>
          <td>${pmem}% (${rss_h})</td>
        </tr>
EOF
    done < <(processes_top cpu 5)
}

_report_history_rows() {
    [[ -f "$HISTORY_FILE" ]] || return 0
    local ts host cpu ram swap disk load rx tx status
    while IFS=, read -r ts host cpu ram swap disk load rx tx status; do
        [[ "$ts" == "timestamp" ]] && continue
        cat <<EOF
        <tr>
          <td>$(_html_escape "$ts")</td>
          <td>${cpu}%</td>
          <td>${ram}%</td>
          <td>${disk}%</td>
          <td><span class="badge badge-$(_report_status_class "$status")">${status}</span></td>
        </tr>
EOF
    done < <(tail -n 10 "$HISTORY_FILE" | tac)
}

_report_history_section() {
    if (( HIST_ROWS == 0 )); then
        cat <<EOF
  <p class="empty">Aún no hay suficientes datos históricos. Ejecuta 'sysguard --check' unas cuantas veces (o espera a que corra por cron) y vuelve a generar el reporte.</p>
EOF
        return
    fi
    cat <<EOF
  <div class="info-grid">
    <div class="info-row"><span>CPU — promedio / pico (24h)</span><span>${HIST_CPU_AVG}% / ${HIST_CPU_MAX}%</span></div>
    <div class="info-row"><span>RAM — promedio / pico (24h)</span><span>${HIST_RAM_AVG}% / ${HIST_RAM_MAX}%</span></div>
    <div class="info-row"><span>Disco — actual / cambio (24h)</span><span>${HIST_DISK_CURRENT}% / ${HIST_DISK_CHANGE}%</span></div>
    <div class="info-row"><span>Muestras consideradas</span><span>${HIST_ROWS}</span></div>
  </div>
  <div class="table-wrap" style="margin-top:.9rem;">
  <table>
    <tr><th>Timestamp</th><th>CPU</th><th>RAM</th><th>Disco</th><th>Estado</th></tr>
$(_report_history_rows)
  </table>
  </div>
EOF
}

# report_generate — recolecta métricas y escribe $REPORT_DIR/status.html.
# Asume que ya se hizo load_config. Igual que cmd_check, hace su propio
# muestreo (metrics_collect_realtime incluye la espera de
# CPU_SAMPLE_INTERVAL segundos).
report_generate() {
    metrics_collect_system
    metrics_collect_ram
    metrics_collect_swap
    metrics_collect_load
    metrics_collect_uptime
    metrics_collect_disks
    metrics_collect_network
    metrics_collect_realtime "${NET_IFACE:-}"
    compute_worst_disk

    local cpu_status ram_status swap_status net_status overall
    cpu_status=$(threshold_status CPU "$CPU_PERCENT")
    ram_status=$(threshold_status RAM "$RAM_PERCENT")
    swap_status=$(threshold_status SWAP "$SWAP_PERCENT")
    net_status=$(network_status "${NET_STATE:-down}")
    overall=$(worst_status "$cpu_status" "$ram_status" "$swap_status" "$WORST_DISK_STATUS" "$net_status")

    history_stats 24

    local report_file="$REPORT_DIR/status.html"
    local overall_cls
    overall_cls=$(_report_status_class "$overall")

    cat <<EOF > "$report_file"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SysGuard Report — $(_html_escape "$SYS_HOSTNAME")</title>
<style>
  :root {
    --bg: #0f1420; --panel: #171d2b; --border: #262e42; --text: #e4e8f1; --muted: #8b93a7;
    --ok: #34d399; --warn: #fbbf24; --crit: #f87171; --accent: #60a5fa;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 2rem 1rem 4rem; background: var(--bg); color: var(--text);
    font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  .wrap { max-width: 980px; margin: 0 auto; }
  header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: .5rem; margin-bottom: .25rem; }
  h1 { font-size: 1.4rem; margin: 0; letter-spacing: .02em; }
  h1 .accent { color: var(--accent); }
  .meta { color: var(--muted); font-size: .85rem; }
  .overall { display: inline-flex; align-items: center; gap: .5rem; margin: .75rem 0 2rem; padding: .5rem .9rem; border-radius: 8px; border: 1px solid var(--border); background: var(--panel); font-size: .9rem; }
  h2 { font-size: .8rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); margin: 2.5rem 0 .9rem; border-bottom: 1px solid var(--border); padding-bottom: .5rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: .9rem; }
  .card { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: .9rem 1rem; }
  .card-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: .6rem; }
  .card-label { font-size: .8rem; color: var(--muted); letter-spacing: .04em; }
  .card-value { margin-top: .4rem; font-size: 1.3rem; font-weight: 600; }
  .bar { height: 8px; border-radius: 4px; background: #0b0f18; overflow: hidden; }
  .bar-fill { height: 100%; border-radius: 4px; }
  .fill-ok { background: var(--ok); }
  .fill-warn { background: var(--warn); }
  .fill-crit { background: var(--crit); }
  .badge { font-size: .7rem; font-weight: 600; padding: .15rem .5rem; border-radius: 999px; text-transform: uppercase; letter-spacing: .03em; }
  .badge-ok { background: rgba(52,211,153,.15); color: var(--ok); }
  .badge-warn { background: rgba(251,191,36,.15); color: var(--warn); }
  .badge-crit { background: rgba(248,113,113,.15); color: var(--crit); }
  .badge-unknown { background: rgba(139,147,167,.15); color: var(--muted); }
  .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .5rem 2rem; background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 1rem 1.2rem; }
  .info-row { display: flex; justify-content: space-between; gap: 1rem; padding: .3rem 0; font-size: .88rem; border-bottom: 1px dashed var(--border); }
  .info-row:last-child { border-bottom: none; }
  .info-row span:first-child { color: var(--muted); }
  table { width: 100%; border-collapse: collapse; background: var(--panel); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; font-size: .85rem; }
  th, td { text-align: left; padding: .55rem .8rem; border-bottom: 1px solid var(--border); }
  th { color: var(--muted); font-weight: 600; text-transform: uppercase; font-size: .72rem; letter-spacing: .05em; }
  tr:last-child td { border-bottom: none; }
  .table-wrap { overflow-x: auto; }
  .empty { color: var(--muted); font-size: .85rem; padding: .5rem 0; }
  footer { margin-top: 3rem; color: var(--muted); font-size: .75rem; text-align: center; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>Sys<span class="accent">Guard</span> Report</h1>
    <div class="meta">Generado: $(_html_escape "$(now_iso)")</div>
  </header>
  <div class="overall">
    <span class="badge badge-${overall_cls}">${overall}</span>
    <span>Estado general del host <strong>$(_html_escape "$SYS_HOSTNAME")</strong></span>
  </div>

  <h2>System Health</h2>
  <div class="grid">
$(_report_metric_card "CPU" "$CPU_PERCENT" "$cpu_status")
$(_report_metric_card "RAM" "$RAM_PERCENT" "$ram_status")
$(_report_metric_card "SWAP" "$SWAP_PERCENT" "$swap_status")
$(_report_metric_card "DISK (${WORST_DISK_MOUNT})" "$WORST_DISK_PCT" "$WORST_DISK_STATUS")
  </div>

  <h2>System Information</h2>
  <div class="info-grid">
    <div class="info-row"><span>Hostname</span><span>$(_html_escape "$SYS_HOSTNAME")</span></div>
    <div class="info-row"><span>Distribución</span><span>$(_html_escape "$SYS_DISTRO")</span></div>
    <div class="info-row"><span>Kernel</span><span>$(_html_escape "$SYS_KERNEL")</span></div>
    <div class="info-row"><span>Arquitectura</span><span>$(_html_escape "$SYS_ARCH")</span></div>
    <div class="info-row"><span>CPU</span><span>$(_html_escape "$SYS_CPU_MODEL") (${SYS_CPU_COUNT} núcleos)</span></div>
    <div class="info-row"><span>Uptime</span><span>$(_html_escape "$UPTIME_HUMAN")</span></div>
    <div class="info-row"><span>Load average</span><span>${LOAD1} / ${LOAD5} / ${LOAD15}</span></div>
    <div class="info-row"><span>Red</span><span>$(_html_escape "${NET_IFACE:-sin interfaz}") — ${NET_STATE:-down} — $(_html_escape "${NET_IP:-n/d}")</span></div>
  </div>

  <h2>Filesystems</h2>
  <div class="table-wrap">
  <table>
    <tr><th>Punto de montaje</th><th>Tipo</th><th>Uso</th><th>Estado</th></tr>
$(_report_disk_rows)
  </table>
  </div>

  <h2>Top Processes (CPU)</h2>
  <div class="table-wrap">
  <table>
    <tr><th>PID</th><th>Usuario</th><th>Comando</th><th>CPU</th><th>RAM</th></tr>
$(_report_process_rows)
  </table>
  </div>

  <h2>Resource History</h2>
$(_report_history_section)

  <footer>SysGuard $SYSGUARD_VERSION — reporte generado localmente, sin JavaScript ni dependencias externas.</footer>
</div>
</body>
</html>
EOF

    log_event INFO "report generated at $report_file"
}
