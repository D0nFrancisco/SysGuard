#!/usr/bin/env bash
# lib/alerts.sh — evalúa transiciones de estado con cooldown, persistiendo
# el estado en ALERT_STATE_FILE para que sobreviva entre ejecuciones de
# cron (cada invocación de sysguard es un proceso nuevo, así que el
# cooldown no puede vivir solo en memoria). Usa flock sobre ALERT_LOCK_FILE
# para no corromper el estado si dos ejecuciones se solapan.

# _alerts_read KEY — imprime "status last_notified_epoch" para KEY, o
# "OK 0" si no hay registro previo o el archivo aún no existe.
_alerts_read() {
    local key=$1
    [[ -f "$ALERT_STATE_FILE" ]] || { echo "OK 0"; return; }
    awk -v k="$key" '$1==k{print $2, $3; found=1} END{if(!found) print "OK 0"}' "$ALERT_STATE_FILE"
}

# _alerts_update_state KEY STATUS NOTIFIED_EPOCH — reescribe ALERT_STATE_FILE
# con el nuevo valor para KEY, preservando el resto de las métricas.
_alerts_update_state() {
    local key=$1 status=$2 notified=$3
    local tmp="${ALERT_STATE_FILE}.tmp.$$"
    local found=0 k s n
    : > "$tmp"
    if [[ -f "$ALERT_STATE_FILE" ]]; then
        while IFS=' ' read -r k s n; do
            [[ -z "$k" ]] && continue
            if [[ "$k" == "$key" ]]; then
                echo "$key $status $notified" >> "$tmp"
                found=1
            else
                echo "$k $s $n" >> "$tmp"
            fi
        done < "$ALERT_STATE_FILE"
    fi
    (( found == 0 )) && echo "$key $status $notified" >> "$tmp"
    mv -f "$tmp" "$ALERT_STATE_FILE"
}

# alert_evaluate KEY STATUS — imprime una de:
#   NOTIFY_ALERT     primera vez en este estado (o cooldown ya expirado)
#   NOTIFY_RECOVERY  vuelve a OK después de haber estado en WARNING/CRITICAL
#   SUPPRESSED       mismo estado no-OK que la última notificación, dentro
#                    del cooldown — no se repite el aviso
#   NONE             sigue en OK, nada que reportar
alert_evaluate() {
    local key=$1 status=$2
    local result prev_status prev_notified now

    exec 9>"$ALERT_LOCK_FILE"
    flock -x 9

    read -r prev_status prev_notified <<<"$(_alerts_read "$key")"
    [[ "$prev_notified" =~ ^[0-9]+$ ]] || prev_notified=0
    now=$(now_epoch)

    if [[ "$status" == "$prev_status" ]]; then
        if [[ "$status" == "OK" ]]; then
            result="NONE"
        elif (( now - prev_notified >= ALERT_COOLDOWN )); then
            result="NOTIFY_ALERT"
            prev_notified=$now
        else
            result="SUPPRESSED"
        fi
    else
        if [[ "$status" == "OK" ]]; then
            result="NOTIFY_RECOVERY"
        else
            result="NOTIFY_ALERT"
        fi
        prev_notified=$now
    fi

    _alerts_update_state "$key" "$status" "$prev_notified"

    flock -u 9
    exec 9>&-

    echo "$result"
}
