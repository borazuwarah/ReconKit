# lib/scope.sh: gestión del ámbito (scope) autorizado.
# Una herramienta de pentest no debe tocar nada que no esté en el ámbito: todas las
# fases futuras (discover, scan, web) tendrán que pasar primero por scope_check.
#
# Formato de cada línea del fichero de ámbito (# inicia un comentario):
#   192.168.1.50        IPv4 exacta
#   192.168.1.0/24      red en notación CIDR (IPv4)
#   servidor.lab.local  nombre de host exacto
#   *.lab.local         cualquier subdominio de lab.local (no incluye lab.local)

# ip_to_int a.b.c.d -> imprime el entero de 32 bits; falla si no es una IPv4 válida
ip_to_int() {
    printf '%s\n' "$1" | LC_ALL=C awk -F. '
        NF != 4 { exit 1 }
        { for (i = 1; i <= 4; i++)
              if ($i !~ /^(0|[1-9][0-9]*)$/ || $i + 0 > 255) exit 1
          printf "%.0f", (($1 * 256 + $2) * 256 + $3) * 256 + $4 }'
}

# cidr_valido a.b.c.d/n
cidr_valido() {
    net=${1%/*}; bits=${1#*/}
    case $bits in ""|*[!0-9]*|0?*) return 1;; esac
    [ "$bits" -le 32 ] || return 1
    ip_to_int "$net" >/dev/null
}

# ip_en_cidr IP CIDR
ip_en_cidr() {
    ip_i=$(ip_to_int "$1") || return 1
    net_i=$(ip_to_int "${2%/*}") || return 1
    size=$((1 << (32 - ${2#*/})))
    [ $((ip_i / size)) -eq $((net_i / size)) ]
}

# cidr_dentro_de_cidr RED_OBJETIVO RED_AMBITO: la red objetivo debe estar contenida
cidr_dentro_de_cidr() {
    cidr_valido "$1" || return 1
    [ "${1#*/}" -ge "${2#*/}" ] || return 1
    ip_en_cidr "${1%/*}" "$2"
}

# entrada_valida: comprueba una línea del fichero de ámbito (ya en minúsculas)
entrada_valida() {
    case $1 in
        ""|*[!a-z0-9._:/*-]*) return 1;;
    esac
    case $1 in
        *\**)  # el comodín solo se admite como prefijo "*." y una sola vez
            case $1 in
                \*.?*) case ${1#\*} in *\**) return 1;; esac; return 0;;
                *) return 1;;
            esac;;
        */*)   cidr_valido "$1"; return $?;;
    esac
    return 0
}

# objetivo_valido: lo que el usuario pide comprobar (sin comodines)
objetivo_valido() {
    case $1 in
        ""|*[!A-Za-z0-9._:/-]*) return 1;;
    esac
    [ ${#1} -le 253 ]
}

# scope_entries: imprime las entradas del fichero, sin comentarios, vacías ni \r, en minúsculas
scope_entries() {
    tr -d '\r' < "$SCOPE_FILE" \
        | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | grep -v '^$' \
        | tr '[:upper:]' '[:lower:]'
}

# entrada_coincide OBJETIVO ENTRADA
entrada_coincide() {
    case $2 in
        */*)
            case $1 in
                */*) cidr_dentro_de_cidr "$1" "$2";;
                *)   ip_en_cidr "$1" "$2";;
            esac;;
        \*.*)
            case $1 in *"${2#\*}") return 0;; esac
            return 1;;
        *)  [ "$1" = "$2" ];;
    esac
}

# scope_leer: carga las entradas en $ENTRADAS; devuelve 2 si no hay ámbito utilizable
scope_leer() {
    if [ ! -r "$SCOPE_FILE" ]; then
        msg_err "No se puede leer el fichero de ámbito: $(limpia "$SCOPE_FILE")"
        msg_err "Crea uno a partir de scope.txt.example o indica otro con -s FICHERO."
        return 2
    fi
    ENTRADAS=$(scope_entries)
    if [ -z "$ENTRADAS" ]; then
        msg_err "El fichero de ámbito no tiene ninguna entrada: sin ámbito no se actúa sobre nada."
        return 2
    fi
}

# scope_check OBJETIVO -> 0 dentro del ámbito, 1 fuera, 2 error
scope_check() {
    objetivo=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    scope_leer || return 2
    while read -r entrada; do
        entrada_valida "$entrada" || continue
        entrada_coincide "$objetivo" "$entrada" && return 0
    done <<EOF
$ENTRADAS
EOF
    return 1
}

scope_list() {
    scope_leer || return 2
    msg_kv "Fichero :" "$(limpia "$SCOPE_FILE")"
    validas=0
    while read -r entrada; do
        if ! entrada_valida "$entrada"; then
            msg_err "Entrada inválida (se ignora): $(limpia "$entrada")"
            continue
        fi
        validas=$((validas + 1))
        case $entrada in
            */*) tipo="red     "
                 if [ "${entrada#*/}" -lt 16 ]; then
                     msg_warn "Red muy amplia (/${entrada#*/}): $(limpia "$entrada"), revisa que sea intencionado."
                 fi;;
            \*.*) tipo="comodín ";;
            *)    tipo="host    ";;
        esac
        msg_kv "Entrada :" "$tipo $(limpia "$entrada")"
    done <<EOF
$ENTRADAS
EOF
    msg_kv "Total   :" "$validas entrada(s) válida(s)"
    [ "$validas" -gt 0 ] || { msg_err "Ninguna entrada es válida: no hay ámbito utilizable."; return 2; }
}

scope_check_cmd() {
    if ! objetivo_valido "$1"; then
        msg_err "Objetivo no válido: $(limpia "$1")"
        return 2
    fi
    scope_check "$1"; rc=$?
    [ $rc -eq 2 ] && return 2
    msg_kv "Objetivo :" "$(limpia "$1")"
    if [ $rc -eq 0 ]; then
        echo -e "${yellowColour}[+] ${endColour}${grayColour}Ámbito   :${endColour}${greenColour} EN ÁMBITO${endColour}"
        return 0
    fi
    echo -e "${yellowColour}[+] ${endColour}${grayColour}Ámbito   :${endColour}${redColour} FUERA DE ÁMBITO${endColour}"
    return 1
}

scope_uso() {
    echo -e "${yellowColour}Uso:${endColour}"
    echo -e "  ${grayColour}./reconkit.sh [-s FICHERO] scope list${endColour}"
    echo -e "  ${grayColour}./reconkit.sh [-s FICHERO] scope check <objetivo>${endColour}"
    echo
    echo -e "${yellowColour}Códigos de salida de 'scope check':${endColour} ${grayColour}0 en ámbito, 1 fuera de ámbito, 2 error${endColour}"
}

cmd_scope() {
    sub=${1:-}; [ $# -gt 0 ] && shift
    case $sub in
        list)  scope_list;;
        check) if [ $# -ne 1 ]; then
                   msg_err "Uso: ./reconkit.sh scope check <objetivo>"; return 2
               fi
               scope_check_cmd "$1";;
        ""|-h|--help) scope_uso;;
        *)     msg_err "Subcomando de 'scope' desconocido: $(limpia "$sub")"
               msg_err "Usa './reconkit.sh scope --help' para ver cómo se utiliza."
               return 2;;
    esac
}
