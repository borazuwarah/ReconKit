#!/bin/sh
# Pruebas del descubrimiento de hosts (v1.1.0). Uso: sh tests/test_discover.sh
# Solo sondea 127.0.0.0/8 (el propio equipo); no sale nada a la red.
cd "$(dirname "$0")/.." || exit 1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

printf '%s\n' '127.0.0.0/30' 'localhost' '10.0.0.0/8' > "$TMP/scope.txt"

OK=0; FAIL=0
t() {  # t RC_ESPERADO "descripción" argumentos de reconkit.sh
    esperado=$1; desc=$2; shift 2
    bash ./reconkit.sh "$@" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq "$esperado" ]; then OK=$((OK + 1)); echo "  ok   $desc"
    else FAIL=$((FAIL + 1)); echo "  FAIL $desc (esperado $esperado, salió $rc)"; fi
}
S="-s $TMP/scope.txt"

echo "Discover: ámbito"
t 1 "IP fuera de ámbito"                 $S discover 192.168.1.1
t 1 "red más amplia que el ámbito"       $S discover 127.0.0.0/29
t 1 "uno fuera = no se sondea ninguno"   $S discover 127.0.0.1 192.168.1.1
t 2 "sin fichero de ámbito"              -s "$TMP/no_existe.txt" discover 127.0.0.1

echo "Discover: validación"
t 2 "falta el objetivo"                  $S discover
t 2 "objetivo con caracteres peligrosos" $S discover 'a;b'
t 2 "red demasiado amplia (/8)"          $S discover 10.0.0.0/8
t 2 "opción -m ya no existe"             $S discover -m tcp 127.0.0.1
t 2 "timeout no válido"                  $S discover -t 0 127.0.0.1
t 2 "hilos no válidos"                   $S discover -j abc 127.0.0.1
t 2 "opción sin valor"                   $S discover -t
t 2 "opción desconocida"                 $S discover --foo 127.0.0.1
t 0 "ayuda de discover"                  discover --help

echo "Discover: sondeo local"
t 0 "ping a 127.0.0.1"                   $S discover 127.0.0.1
t 0 "red /30 en ámbito"                  $S discover 127.0.0.0/30
t 0 "nombre de host (localhost)"         $S discover localhost

if bash ./reconkit.sh $S discover 127.0.0.1 2>&1 | grep -q 'Host activo.*TTL 64.*Linux/Unix'; then
    OK=$((OK + 1)); echo "  ok   127.0.0.1 activo con TTL 64 -> Linux/Unix"
else
    FAIL=$((FAIL + 1)); echo "  FAIL 127.0.0.1 activo con TTL 64 -> Linux/Unix"
fi

bash ./reconkit.sh $S discover -o "$TMP/activos.txt" 127.0.0.0/30 >/dev/null 2>&1
if [ "$(cat "$TMP/activos.txt" 2>/dev/null)" = "$(printf '127.0.0.1\n127.0.0.2')" ]; then
    OK=$((OK + 1)); echo "  ok   -o guarda las IPs activas (sin red ni broadcast)"
else
    FAIL=$((FAIL + 1)); echo "  FAIL -o guarda las IPs activas (sin red ni broadcast)"
fi

echo
echo "Resultado: $OK correctas, $FAIL fallidas"
[ "$FAIL" -eq 0 ]
