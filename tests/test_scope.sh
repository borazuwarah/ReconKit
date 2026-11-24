#!/bin/sh
# Pruebas de la gestión del ámbito (v1.0.0). Uso: sh tests/test_scope.sh
cd "$(dirname "$0")/.." || exit 1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Fichero de ámbito con saltos de línea de Windows (CRLF) a propósito
printf '%s\r\n' '# comentario' '192.168.1.0/24' '10.0.0.5' '*.lab.local   # comodín' 'Example.Test' '' > "$TMP/scope.txt"
: > "$TMP/vacio.txt"
printf '%s\n' '# solo comentarios' > "$TMP/comentarios.txt"
printf '%s\n' '999.1.1.1/24' 'a;b' '*.*.x' > "$TMP/invalido.txt"

OK=0; FAIL=0
t() {  # t RC_ESPERADO "descripción" argumentos de reconkit.sh
    esperado=$1; desc=$2; shift 2
    bash ./reconkit.sh "$@" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq "$esperado" ]; then OK=$((OK + 1)); echo "  ok   $desc"
    else FAIL=$((FAIL + 1)); echo "  FAIL $desc (esperado $esperado, salió $rc)"; fi
}
S="-s $TMP/scope.txt"

echo "Ámbito: IPs y redes"
t 0 "IP dentro de la red"                $S scope check 192.168.1.50
t 1 "IP fuera de la red"                 $S scope check 192.168.2.1
t 0 "IP exacta"                          $S scope check 10.0.0.5
t 1 "IP contigua a la exacta"            $S scope check 10.0.0.6
t 0 "primera IP de la red"               $S scope check 192.168.1.0
t 0 "última IP de la red"                $S scope check 192.168.1.255
t 1 "IP justo fuera (192.168.0.255)"     $S scope check 192.168.0.255
t 0 "subred contenida (/25)"             $S scope check 192.168.1.0/25
t 0 "misma red (/24)"                    $S scope check 192.168.1.0/24
t 1 "red más amplia (/23)"               $S scope check 192.168.1.0/23
t 1 "red mucho más amplia (/16)"         $S scope check 192.168.0.0/16
t 1 "IP no válida no entra"              $S scope check 999.1.1.1
t 1 "octeto con cero a la izquierda"     $S scope check 192.168.01.5

echo "Ámbito: nombres de host"
t 0 "subdominio con comodín"             $S scope check app.lab.local
t 0 "subdominio profundo"                $S scope check a.b.lab.local
t 1 "el dominio base no cuenta"          $S scope check lab.local
t 1 "sufijo sin punto (notlab.local)"    $S scope check notlab.local
t 1 "dominio atacante con el sufijo"     $S scope check app.lab.local.evil.org
t 0 "mayúsculas/minúsculas"              $S scope check EXAMPLE.test
t 1 "host no listado"                    $S scope check otro.test

echo "Validación y errores"
t 2 "objetivo con caracteres peligrosos" $S scope check 'a;b'
t 2 "objetivo con secuencia de escape"   $S scope check '\e[31mx'
t 2 "objetivo vacío"                     $S scope check ''
t 2 "falta el objetivo"                  $S scope check
t 2 "fichero de ámbito inexistente"      -s "$TMP/no_existe.txt" scope check 10.0.0.5
t 2 "ámbito vacío = no se actúa"         -s "$TMP/vacio.txt" scope check 10.0.0.5
t 2 "ámbito solo comentarios"            -s "$TMP/comentarios.txt" scope check 10.0.0.5
t 2 "ámbito con entradas inválidas"      -s "$TMP/invalido.txt" scope list
t 1 "entrada inválida nunca coincide"    -s "$TMP/invalido.txt" scope check 999.1.1.1
t 0 "scope list correcto"                $S scope list

echo "Interfaz"
t 0 "-h"                                 -h
t 0 "--help"                             --help
t 0 "-v"                                 -v
t 0 "--version"                          --version
t 2 "opción desconocida"                 --foo
t 2 "-s sin fichero"                     -s
t 2 "sin comando"                        $S
t 2 "comando desconocido"                $S hack
t 3 "comando reservado (scan)"           $S scan
t 2 "subcomando de scope desconocido"    $S scope borrar

echo
echo "Resultado: $OK correctas, $FAIL fallidas"
[ "$FAIL" -eq 0 ]
