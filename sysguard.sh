#!/bin/bash
# ==========================================================
# SysGuard v1.0 - Monitor de Sistema Profesional
# Autor: FrankGualdron
# Descripción: Monitorea métricas clave y genera alertas.
# ==========================================================

# 1. Cargar la configuración que acabamos de crear
# $(dirname "$0") asegura que encuentre el archivo sin importar desde dónde corras el script
source "$(dirname "$0")/config/settings.conf"

# 2. Definición de colores para una interfaz atractiva (ANSI colors)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color (Reset)

# 3. Variables de tiempo y archivos
LOG_FILE="$LOG_DIR/sysguard_$(date +%Y%m%d).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 4. FUNCIÓN: Registrar en log
# Esta función escribe en el archivo y muestra en pantalla al mismo tiempo
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}
# 5. FUNCIÓN: Obtener uso de CPU
get_cpu_usage() {
    # 1. Obtenemos el valor del CPU (usando /proc/stat que es más estable)
    # 2. sed 's/[,.].*//' elimina la coma o el punto y todo lo que sigue
    CPU_VALUE=$(grep 'cpu ' /proc/stat | awk '{print ($2+$4)*100/($2+$4+$5)}' | sed 's/[,.].*//')
    
    # Si por alguna razón el valor queda vacío, ponemos 0
    if [ -z "$CPU_VALUE" ]; then
        echo "0"
    else
        echo "$CPU_VALUE"
    fi
}

# 6. FUNCIÓN: Obtener uso de RAM
get_ram_usage() {
    # Extrae total y disponible de /proc/meminfo [cite: 64, 65, 66]
    TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED=$((TOTAL - AVAILABLE))
    # Calcula el porcentaje usando bc (calculadora de línea de comandos) [cite: 67, 69]
    RAM_PERCENT=$(echo "scale=0; $USED * 100 / $TOTAL" | bc)
    echo "$RAM_PERCENT"
}

# 7. FUNCIÓN: Obtener uso de Disco
get_disk_usage() {
    # Analiza el uso de la partición raíz (/) [cite: 74, 75]
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    echo "$DISK_USAGE"
}

# 8. FUNCIÓN: Obtener info de Red
get_network_info() {
    # Identifica la interfaz de red activa y mide tráfico [cite: 80]
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    RX=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $2}')
    TX=$(cat /proc/net/dev | grep "$INTERFACE" | awk '{print $10}')
    echo "$INTERFACE RX: $(numfmt --to=iec $RX) TX: $(numfmt --to=iec $TX)"
}


# 9. FUNCIÓN: Verificar umbrales y alertar
check_threshold() {
    local metric=$1
    local value=$2
    local threshold=$3
    local unit=$4

    # Si el valor supera el umbral configurado [cite: 89]
    if [ "$value" -gt "$threshold" ]; then
        log "! ALERTA: $metric al ${value}${unit} (umbral: ${threshold}${unit})" [cite: 91]
        echo -e "${RED}[ALERTA] $metric: ${value}${unit} > umbral ${threshold}${unit}${NC}" [cite: 91, 92]
        return 1
    else
        echo -e "${GREEN}[OK] $metric: ${value}${unit}${NC}" [cite: 95]
        return 0
    fi
}


# 10. BUCLE DE EJECUCIÓN
echo -e "${CYAN}--- Iniciando SysGuard Monitoring ---${NC}"

while true; do
    # Obtener valores actuales
    current_cpu=$(get_cpu_usage)
    current_ram=$(get_ram_usage)
    current_disk=$(get_disk_usage)
    current_net=$(get_network_info)

    clear
    echo -e "${CYAN}SysGuard - $(date)${NC}"
    echo "-----------------------------------"

    # Verificar cada métrica contra los umbrales
    check_threshold "CPU" "$current_cpu" "$CPU_THRESHOLD" "%"
    check_threshold "RAM" "$current_ram" "$RAM_THRESHOLD" "%"
    check_threshold "Disco" "$current_disk" "$DISK_THRESHOLD" "%"
    
    echo -e "Red: $current_net"
    echo "-----------------------------------"
    log "Chequeo completado. CPU: $current_cpu%, RAM: $current_ram%, Disco: $current_disk%"

    # Llamar al generador de reporte HTML
    ./report.sh "$current_cpu" "$current_ram" "$current_disk" "$current_net"

    echo -e "${YELLOW}Presiona [CTRL+C] para detener.${NC}"
    
    # Esperar el tiempo definido en la configuración
    sleep "$CHECK_INTERVAL"
done
