#!/usr/bin/env bash
# tests/run_all.sh — corre todos los tests/test_*.sh y resume el resultado.
# Sin bats-core ni otra dependencia externa. Uso: ./tests/run_all.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

total_files=0
failed_files=0

for test_file in "$HERE"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    total_files=$((total_files + 1))
    echo "== $(basename "$test_file") =="
    if ! bash "$test_file"; then
        failed_files=$((failed_files + 1))
    fi
    echo
done

if (( total_files == 0 )); then
    echo "sysguard: no se encontró ningún tests/test_*.sh" >&2
    exit 1
fi

if (( failed_files > 0 )); then
    echo "$failed_files de $total_files archivos de test FALLARON"
    exit 1
fi

echo "ALL TESTS PASSED"
exit 0
