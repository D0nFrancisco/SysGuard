#!/usr/bin/env bash
# lib/colors.sh — ANSI y símbolos de estado, con degradación automática.
#
# Se desactivan los colores si: stdout no es una terminal, NO_COLOR está
# definida (https://no-color.org), o TERM=dumb. Así --check en cron o con
# stdout redirigido a un archivo nunca escribe secuencias de escape.
if is_tty && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    COLOR_RED=$'\033[0;31m'
    COLOR_YELLOW=$'\033[1;33m'
    COLOR_GREEN=$'\033[0;32m'
    COLOR_CYAN=$'\033[0;36m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_RED=''
    COLOR_YELLOW=''
    COLOR_GREEN=''
    COLOR_CYAN=''
    COLOR_BOLD=''
    COLOR_DIM=''
    COLOR_RESET=''
fi

# Símbolos y caracteres de caja/barra: se usa UTF-8 solo si el locale
# ORIGINAL (antes de que el entrypoint forzara LC_ALL=C para el parsing
# numérico) lo anunciaba, para no romper terminales/consolas con juego de
# caracteres limitado.
if [[ "${SYSGUARD_ORIGINAL_LOCALE:-}" == *[Uu][Tt][Ff]-8* ]]; then
    SYM_OK="✓"
    SYM_WARN="⚠"
    SYM_CRIT="✗"
    SYM_DOT="●"
    BOX_TL="┌"; BOX_TR="┐"; BOX_BL="└"; BOX_BR="┘"
    BOX_H="─"; BOX_V="│"; BOX_ML="├"; BOX_MR="┤"
    BAR_FULL="█"; BAR_EMPTY="░"
else
    # Símbolos distintos de las palabras de estado (OK/WARNING/CRITICAL):
    # si SYM_OK fuera literalmente "OK" se duplicaría con la palabra de
    # estado en cualquier salida que muestre símbolo + palabra juntos.
    SYM_OK="*"
    SYM_WARN="!"
    SYM_CRIT="X"
    SYM_DOT="o"
    BOX_TL="+"; BOX_TR="+"; BOX_BL="+"; BOX_BR="+"
    BOX_H="-"; BOX_V="|"; BOX_ML="+"; BOX_MR="+"
    BAR_FULL="#"; BAR_EMPTY="-"
fi

# status_color STATUS — imprime el color ANSI correspondiente a OK/WARNING/CRITICAL.
status_color() {
    case "$1" in
        OK) printf '%s' "$COLOR_GREEN" ;;
        WARNING) printf '%s' "$COLOR_YELLOW" ;;
        CRITICAL) printf '%s' "$COLOR_RED" ;;
        *) printf '%s' "$COLOR_RESET" ;;
    esac
}

# status_symbol STATUS — imprime el símbolo correspondiente a OK/WARNING/CRITICAL.
status_symbol() {
    case "$1" in
        OK) printf '%s' "$SYM_OK" ;;
        WARNING) printf '%s' "$SYM_WARN" ;;
        CRITICAL) printf '%s' "$SYM_CRIT" ;;
        *) printf '%s' "?" ;;
    esac
}
