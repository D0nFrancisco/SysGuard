#!/usr/bin/env bash
# lib/processes.sh — vista top de procesos por CPU/RAM. No pretende
# reemplazar top/htop: es una lectura puntual pensada para --check/--report.

# processes_top SORT_KEY LIMIT — imprime "pid user pcpu pmem rss_kb comm"
# (sin encabezado) para los LIMIT procesos con mayor uso.
processes_top() {
    local sort_key=$1 limit=$2
    local ps_sort
    case "$sort_key" in
        cpu) ps_sort="-pcpu" ;;
        mem) ps_sort="-pmem" ;;
        *) die "processes_top: sort_key inválido '$sort_key' (usa cpu|mem)" "$EXIT_ERROR" ;;
    esac
    ps -eo pid=,user=,pcpu=,pmem=,rss=,comm= --sort="$ps_sort" 2>/dev/null | head -n "$limit"
}
