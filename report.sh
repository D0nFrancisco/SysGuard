#!/bin/bash
source "$(dirname "$0")/config/settings.conf"

generate_html() {
    local cpu=$1
    local ram=$2
    local disk=$3
    local net=$4
    local date=$(date)
    local report_file="$REPORT_DIR/status.html"

    cat <<EOF > "$report_file"
<!DOCTYPE html>
<html>
<head>
    <title>SysGuard Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f4f4f4; text-align: center; }
        .card { background: white; padding: 20px; border-radius: 10px; display: inline-block; margin: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 200px; }
        .status-ok { color: green; font-weight: bold; }
        .status-alert { color: red; font-weight: bold; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Reporte de Servidor - SysGuard</h1>
    <p>Última actualización: $date</p>
    <div class="card"><h3>CPU</h3><p>$cpu%</p></div>
    <div class="card"><h3>RAM</h3><p>$ram%</p></div>
    <div class="card"><h3>Disco</h3><p>$disk%</p></div>
    <div class="card"><h3>Red</h3><p>$net</p></div>
</body>
</html>
EOF
    echo "Reporte HTML generado en $report_file"
}

# Permitir que el script principal llame a esta función
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_html "$1" "$2" "$3" "$4"
fi
