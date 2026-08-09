#!/usr/bin/env bash
# tests/test_metrics.sh — prueba lib/metrics.sh. Las métricas de RAM/swap/
# load/uptime se verifican por rango contra el sistema real (son lecturas
# directas de /proc, no tiene sentido mockearlas). Los casos de borde —sin
# interfaz de red, df con encabezado traducido— se prueban sustituyendo
# 'ip'/'df' por binarios falsos al frente del PATH.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$HERE")"
source "$HERE/helpers.sh"

EXIT_OK=0; EXIT_WARNING=1; EXIT_CRITICAL=2; EXIT_ERROR=3
die() { echo "sysguard: error: $1" >&2; exit "${2:-$EXIT_ERROR}"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

DISK_PATHS=""
DISK_EXCLUDE_TYPES="proc sysfs tmpfs devtmpfs overlay squashfs cgroup cgroup2 devpts mqueue tracefs debugfs configfs fusectl pstore binfmt_misc autofs"

# shellcheck source=../lib/metrics.sh
source "$PROJECT_ROOT/lib/metrics.sh"

_in_range_0_100() {
    awk -v v="$1" 'BEGIN{ exit !(v >= 0 && v <= 100) }'
}

echo "RAM: porcentaje entre 0 y 100 contra /proc/meminfo real"
metrics_collect_ram
_in_range_0_100 "$RAM_PERCENT"
assert_eq "0" "$?" "RAM_PERCENT fuera de rango: $RAM_PERCENT"

echo "SWAP: porcentaje entre 0 y 100"
metrics_collect_swap
_in_range_0_100 "$SWAP_PERCENT"
assert_eq "0" "$?" "SWAP_PERCENT fuera de rango: $SWAP_PERCENT"

echo "LOAD/UPTIME no truenan y devuelven valores no vacíos"
metrics_collect_load
assert_ne "" "$LOAD1" "LOAD1 no debería estar vacío"
metrics_collect_uptime
assert_ne "" "$UPTIME_HUMAN" "UPTIME_HUMAN no debería estar vacío"

echo "sin ruta default -> metrics_detect_iface devuelve vacío"
FAKEBIN_NOIFACE="$HERE/fixtures/fakebin_no_iface"
mkdir -p "$FAKEBIN_NOIFACE"
cat > "$FAKEBIN_NOIFACE/ip" <<'EOF'
#!/usr/bin/env bash
# Simula un host sin ninguna ruta default (sin red configurada).
exit 0
EOF
chmod +x "$FAKEBIN_NOIFACE/ip"
iface=$(PATH="$FAKEBIN_NOIFACE:$PATH" metrics_detect_iface)
assert_eq "" "$iface" "sin ruta default, metrics_detect_iface debe devolver vacío"
rm -rf "$FAKEBIN_NOIFACE"

echo "df con encabezado traducido no debe colarse como fila de disco (regresión)"
FAKEBIN_DF="$HERE/fixtures/fakebin_df_translated"
mkdir -p "$FAKEBIN_DF"
cat > "$FAKEBIN_DF/df" <<'EOF'
#!/usr/bin/env bash
cat <<DF
S.ficheros     Tipo     1024-bloques    Usados Disponibles Capacidad Montado en
/dev/fake      ext4         1000000    500000      500000       50% /
DF
EOF
chmod +x "$FAKEBIN_DF/df"
count=$(
    PATH="$FAKEBIN_DF:$PATH"
    metrics_collect_disks
    echo "${#DISKS[@]}"
)
assert_eq "1" "$count" "debe detectar exactamente 1 disco; la fila de encabezado no debe colarse"
rm -rf "$FAKEBIN_DF"

echo "metrics_collect_disks respeta DISK_EXCLUDE_TYPES"
FAKEBIN_DF2="$HERE/fixtures/fakebin_df_pseudo"
mkdir -p "$FAKEBIN_DF2"
cat > "$FAKEBIN_DF2/df" <<'EOF'
#!/usr/bin/env bash
cat <<DF
Filesystem     Type     1024-blocks    Used Available Capacity Mounted on
/dev/fake      ext4         1000000  500000    500000       50% /
tmpfs          tmpfs         100000       0    100000        0% /dev/shm
DF
EOF
chmod +x "$FAKEBIN_DF2/df"
count2=$(
    PATH="$FAKEBIN_DF2:$PATH"
    metrics_collect_disks
    echo "${#DISKS[@]}"
)
assert_eq "1" "$count2" "tmpfs debe excluirse, solo debe quedar 1 disco real"
rm -rf "$FAKEBIN_DF2"

test_summary
