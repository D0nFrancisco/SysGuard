#!/usr/bin/env bash
# tests/helpers.sh — mini framework de aserciones para los tests de
# SysGuard. Deliberadamente pequeño (sin bats-core ni otra dependencia
# externa): cada test_*.sh lo sourcea, hace sus aserciones y termina con
# test_summary.

_assert_count=0
_assert_failed=0

assert_eq() {
    local expected=$1 actual=$2 msg=${3:-assert_eq}
    _assert_count=$((_assert_count + 1))
    if [[ "$expected" != "$actual" ]]; then
        _assert_failed=$((_assert_failed + 1))
        echo "  FAIL: $msg — esperado '$expected', obtenido '$actual'"
    fi
}

assert_ne() {
    local not_expected=$1 actual=$2 msg=${3:-assert_ne}
    _assert_count=$((_assert_count + 1))
    if [[ "$not_expected" == "$actual" ]]; then
        _assert_failed=$((_assert_failed + 1))
        echo "  FAIL: $msg — no se esperaba '$actual'"
    fi
}

# test_summary — se llama al final de cada test_*.sh; termina el proceso
# con exit 0 si todas las aserciones pasaron, o 1 si alguna falló.
test_summary() {
    if (( _assert_failed > 0 )); then
        echo "  -> $_assert_failed/${_assert_count} aserciones fallaron"
        exit 1
    fi
    echo "  -> ${_assert_count} aserciones OK"
    exit 0
}
