# lib/discover.sh: descubrimiento de hosts activos dentro del ámbito autorizado.
# Este fichero se carga con "." desde reconkit.sh; no se ejecuta directamente.
# Necesita lib/common.sh y lib/scope.sh cargados antes.
#
# Cada objetivo se comprueba con scope_check ANTES de enviar un solo paquete: si alguno
# está fuera de ámbito no se sondea nada. Objetivos admitidos:
#   192.168.1.50        IPv4 exacta
#   192.168.1.0/24      red CIDR (como máximo /16; sin dirección de red ni broadcast salvo /31 y /32)
#   servidor.lab.local  nombre de host (se resuelve a IPv4 con getent)
#
# Sondeo: un ping (eco ICMP) a cada IP. Si responde, el host está activo y, por el TTL de la
# respuesta, se estima el sistema operativo. El TTL inicial típico es 64 en Linux/Unix, 128 en
# Windows y 255 en equipos de red; cada salto (router) lo reduce en 1, por eso se usan rangos:
#   TTL   1-64   -> Linux/Unix
#   TTL  65-128  -> Windows
#   TTL 129-255  -> Equipo de red (router, switch...)
# Es solo una estimación: el TTL se puede cambiar en el sistema.

DISCOVER_MAX_BITS=16      # red más amplia permitida
DISCOVER_AVISO_BITS=24    # a partir de aquí (más amplia) se avisa

# int_to_ip ENTERO -> a.b.c.d
int_to_ip() {
    echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"
}

# hostname_valido: letras, números, puntos y guiones; no empieza por guion ni punto
hostname_valido() {
    case $1 in
        ""|-*|.*|*..*|*[!a-z0-9.-]*) return 1;;
    esac
    [ ${#1} -le 253 ]
}

# resolver_host NOMBRE -> imprime su primera IPv4
resolver_host() {
    command -v getent >/dev/null 2>&1 || return 1
    getent ahostsv4 "$1" 2>/dev/null | awk 'NR == 1 { print $1 }' | grep .
}

# discover_expandir OBJETIVO -> imprime las IPs a sondear, una por línea; devuelve 2 si hay error
discover_expandir() {
    case $1 in
        */*)
            if ! cidr_valido "$1"; then
                msg_err "Red no válida: $(limpia "$1")"; return 2
            fi
            bits=${1#*/}
            if [ "$bits" -lt "$DISCOVER_MAX_BITS" ]; then
                msg_err "Red demasiado amplia (/$bits): $(limpia "$1"). El máximo es /$DISCOVER_MAX_BITS; divídela en redes más pequeñas."
                return 2
            fi
            size=$((1 << (32 - bits)))
            base=$(( $(ip_to_int "${1%/*}") / size * size ))
            ini=$base; fin=$((base + size - 1))
            if [ "$bits" -lt 31 ]; then ini=$((ini + 1)); fin=$((fin - 1)); fi
            i=$ini
            while [ "$i" -le "$fin" ]; do int_to_ip "$i"; i=$((i + 1)); done;;
        *)
            if ip_to_int "$1" >/dev/null; then
                echo "$1"
            elif hostname_valido "$1"; then
                if ! ip=$(resolver_host "$1"); then
                    msg_err "No se pudo resolver el nombre: $(limpia "$1")"; return 2
                fi
                ip_to_int "$ip" >/dev/null || { msg_err "Resolución no válida para $(limpia "$1")"; return 2; }
                echo "$ip"
            else
                msg_err "Objetivo no válido: $(limpia "$1")"; return 2
            fi;;
    esac
}

# so_por_ttl TTL -> sistema operativo estimado
so_por_ttl() {
    if   [ "$1" -le 64 ];  then echo "Linux/Unix"
    elif [ "$1" -le 128 ]; then echo "Windows"
    else                        echo "Equipo de red"
    fi
}

# sondea_host IP: si responde al ping añade "IP TTL" al fichero de resultados
sondea_host() {
    salida=$(LC_ALL=C ping -c 1 -W "$DISCOVER_TIMEOUT" -n "$1" 2>/dev/null) || return
    ttl=$(printf '%s\n' "$salida" | grep -io 'ttl=[0-9]*' | head -n 1 | cut -d= -f2)
    case $ttl in ""|*[!0-9]*) ttl="?";; esac
    echo "$1 $ttl" >> "$DISCOVER_RES"
}

discover_uso() {
    echo -e "${yellowColour}Uso:${endColour}"
    echo -e "  ${grayColour}./reconkit.sh [-s FICHERO] discover [opciones] <objetivo> [objetivo...]${endColour}"
    echo
    echo -e "${yellowColour}Objetivos:${endColour} ${grayColour}IPv4, red CIDR (hasta /$DISCOVER_MAX_BITS) o nombre de host. Todos deben estar en el ámbito.${endColour}"
    echo -e "${yellowColour}Sondeo:${endColour}    ${grayColour}ping a cada IP; el TTL de la respuesta estima el sistema operativo:${endColour}"
    echo -e "           ${grayColour}<= 64 Linux/Unix, 65-128 Windows, > 128 equipo de red.${endColour}"
    echo
    echo -e "${yellowColour}Opciones:${endColour}"
    echo -e "  ${blueColour}-t, --timeout S${endColour}    ${grayColour}Segundos de espera por ping, 1-10 (por defecto 1).${endColour}"
    echo -e "  ${blueColour}-j, --hilos N${endColour}      ${grayColour}Pings en paralelo, 1-128 (por defecto 32).${endColour}"
    echo -e "  ${blueColour}-o, --salida F${endColour}     ${grayColour}Guarda las IPs activas en F, una por línea.${endColour}"
    echo
    echo -e "${yellowColour}Códigos de salida:${endColour} ${grayColour}0 completado, 1 objetivo fuera de ámbito, 2 error${endColour}"
}

# numero_en_rango VALOR MIN MAX
numero_en_rango() {
    case $1 in ""|*[!0-9]*|0?*) return 1;; esac
    [ ${#1} -le 4 ] && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

cmd_discover() {
    DISCOVER_TIMEOUT=1
    DISCOVER_HILOS=32
    salida_fich=""

    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help) discover_uso; return 0;;
            -t|--timeout|-j|--hilos|-o|--salida)
                if [ -z "${2:-}" ]; then
                    msg_err "La opción $1 necesita un valor. Usa 'discover --help'."; return 2
                fi
                case $1 in
                    -t|--timeout)
                        numero_en_rango "$2" 1 10 || { msg_err "Timeout no válido: $(limpia "$2") (1-10)"; return 2; }
                        DISCOVER_TIMEOUT=$2;;
                    -j|--hilos)
                        numero_en_rango "$2" 1 128 || { msg_err "Número de hilos no válido: $(limpia "$2") (1-128)"; return 2; }
                        DISCOVER_HILOS=$2;;
                    -o|--salida) salida_fich=$2;;
                esac
                shift 2;;
            --) shift; break;;
            -*) msg_err "Opción de 'discover' desconocida: $(limpia "$1")"
                msg_err "Usa './reconkit.sh discover --help' para ver cómo se utiliza."; return 2;;
            *)  break;;
        esac
    done

    if [ $# -eq 0 ]; then
        msg_err "Falta el objetivo. Uso: ./reconkit.sh discover [opciones] <objetivo>"; return 2
    fi
    if ! command -v ping >/dev/null 2>&1; then
        msg_err "No se encuentra el comando 'ping'."; return 2
    fi

    # 1) Validar TODOS los objetivos contra el ámbito antes de sondear nada
    for obj in "$@"; do
        o=$(printf '%s' "$obj" | tr '[:upper:]' '[:lower:]')
        if ! objetivo_valido "$o"; then
            msg_err "Objetivo no válido: $(limpia "$obj")"; return 2
        fi
        scope_check "$o"; rc=$?
        [ $rc -eq 2 ] && return 2
        if [ $rc -ne 0 ]; then
            msg_err "Objetivo FUERA DE ÁMBITO: $(limpia "$obj"). No se sondea nada."
            return 1
        fi
    done

    TMPD=$(mktemp -d) || { msg_err "No se pudo crear un directorio temporal."; return 2; }
    trap 'jobs -p | xargs -r kill 2>/dev/null; rm -rf "$TMPD"' EXIT
    trap 'exit 130' INT TERM
    lista="$TMPD/ips"; DISCOVER_RES="$TMPD/res"
    : > "$lista"; : > "$DISCOVER_RES"

    # 2) Expandir objetivos a IPs
    for obj in "$@"; do
        o=$(printf '%s' "$obj" | tr '[:upper:]' '[:lower:]')
        case $o in
            */*) b=${o#*/}
                 if cidr_valido "$o" && [ "$b" -lt "$DISCOVER_AVISO_BITS" ] && [ "$b" -ge "$DISCOVER_MAX_BITS" ]; then
                     msg_warn "Red amplia (/$b): $(limpia "$o"), el sondeo puede tardar."
                 fi;;
        esac
        discover_expandir "$o" >> "$lista" || return 2
    done
    sort -u -t. -k1,1n -k2,2n -k3,3n -k4,4n "$lista" -o "$lista"
    total=$(wc -l < "$lista" | tr -d ' ')

    msg_kv "Ámbito   :" "$(limpia "$SCOPE_FILE")"
    msg_kv "Objetivo :" "$(limpia "$*")"
    msg_kv "Hosts    :" "$total a sondear con ping (timeout ${DISCOVER_TIMEOUT}s, $DISCOVER_HILOS en paralelo)"
    msg_info "Sondeando..."

    # 3) Ping en paralelo
    inicio=$(date +%s)
    en_curso=0
    while read -r ip; do
        if [ "$en_curso" -ge "$DISCOVER_HILOS" ]; then
            wait -n 2>/dev/null; en_curso=$((en_curso - 1))
        fi
        sondea_host "$ip" &
        en_curso=$((en_curso + 1))
    done < "$lista"
    wait
    dur=$(( $(date +%s) - inicio ))

    # 4) Resultados ordenados
    sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$DISCOVER_RES" -o "$DISCOVER_RES"
    activos=$(wc -l < "$DISCOVER_RES" | tr -d ' ')
    while read -r ip ttl; do
        if [ "$ttl" = "?" ]; then so="desconocido"; else so=$(so_por_ttl "$ttl"); fi
        printf -v col_ip '%-15s' "$ip"
        printf -v col_ttl '%-3s' "$ttl"
        echo -e "${yellowColour}[+] ${endColour}${grayColour}Host activo :${endColour}${greenColour} $col_ip${endColour}${grayColour}  TTL ${col_ttl}  ->${endColour}${blueColour} $so${endColour}"
    done < "$DISCOVER_RES"

    if [ "$activos" -gt 0 ]; then
        msg_ok "$activos de $total host(s) activo(s) en ${dur}s"
    else
        msg_warn "Ningún host respondió al ping ($total sondeado(s) en ${dur}s). Puede que un cortafuegos bloquee ICMP."
    fi

    if [ -n "$salida_fich" ]; then
        if awk '{ print $1 }' "$DISCOVER_RES" > "$salida_fich" 2>/dev/null; then
            msg_kv "Guardado :" "$(limpia "$salida_fich")"
        else
            msg_err "No se pudo escribir en $(limpia "$salida_fich")"; return 2
        fi
    fi
    return 0
}
