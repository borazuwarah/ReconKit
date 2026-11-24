#!/bin/bash
# reconkit.sh: mini framework de reconocimiento para pruebas de seguridad AUTORIZADAS.
# Estructura modular (lib/), ámbito obligatorio (scope) e informe final por fases.
# Uso: ./reconkit.sh [opciones] <comando> [argumentos]    (usa -h para ver la ayuda)
#
#
# Ultima Versión         1.0.0
#
# Historial de versiones (la más reciente arriba):
#
#    1.0.0 (2026-11-23) Primera versión. Estructura base del proyecto: punto de entrada con menú de ayuda
#                       (-h / --help) y versión (-v / --version), colores y formato de salida comunes
#                       (lib/common.sh) y gestión del ámbito autorizado (lib/scope.sh): comandos
#                       'scope list' y 'scope check <objetivo>' con soporte de IPv4, redes CIDR, nombres
#                       de host y comodín '*.dominio'. Los objetivos se validan y sin ámbito no se actúa.
#                       Los comandos discover, scan, web y report están reservados para próximas versiones.

VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/common.sh" || { echo "No se pudo cargar lib/common.sh" >&2; exit 1; }
. "$SCRIPT_DIR/lib/scope.sh"  || { echo "No se pudo cargar lib/scope.sh" >&2; exit 1; }

SCOPE_FILE=${RECONKIT_SCOPE:-./scope.txt}

# Ayuda
uso() {
    echo -e "${yellowColour}reconkit${endColour}${grayColour} v${VERSION} - Mini framework de reconocimiento para pruebas de seguridad autorizadas${endColour}"
    echo
    echo -e "${yellowColour}Uso:${endColour}"
    echo -e "  ${grayColour}./reconkit.sh [opciones] <comando> [argumentos]${endColour}"
    echo
    echo -e "${yellowColour}Opciones:${endColour}"
    echo -e "  ${blueColour}-s, --scope FICHERO${endColour}  ${grayColour}Fichero de ámbito autorizado (por defecto ./scope.txt${endColour}"
    echo -e "                       ${grayColour}o la variable de entorno RECONKIT_SCOPE).${endColour}"
    echo -e "  ${blueColour}-h, --help${endColour}           ${grayColour}Muestra esta ayuda y sale.${endColour}"
    echo -e "  ${blueColour}-v, --version${endColour}        ${grayColour}Muestra la versión y sale.${endColour}"
    echo
    echo -e "${yellowColour}Comandos:${endColour}"
    echo -e "  ${blueColour}scope list${endColour}              ${grayColour}Muestra las entradas del ámbito autorizado.${endColour}"
    echo -e "  ${blueColour}scope check <objetivo>${endColour}  ${grayColour}Comprueba si una IP, host o red está dentro del ámbito.${endColour}"
    echo -e "  ${blueColour}discover${endColour}                ${grayColour}(próximamente) Descubrimiento de hosts activos.${endColour}"
    echo -e "  ${blueColour}scan${endColour}                    ${grayColour}(próximamente) Escaneo de puertos y banners.${endColour}"
    echo -e "  ${blueColour}web${endColour}                     ${grayColour}(próximamente) Reconocimiento web.${endColour}"
    echo -e "  ${blueColour}report${endColour}                  ${grayColour}(próximamente) Informe en Markdown.${endColour}"
    echo
    echo -e "${yellowColour}Formato del fichero de ámbito${endColour} ${grayColour}(una entrada por línea, # para comentarios):${endColour}"
    echo -e "  ${grayColour}192.168.1.50         IPv4 exacta${endColour}"
    echo -e "  ${grayColour}192.168.1.0/24       red CIDR${endColour}"
    echo -e "  ${grayColour}servidor.lab.local   nombre de host${endColour}"
    echo -e "  ${grayColour}*.lab.local          cualquier subdominio de lab.local${endColour}"
    echo
    echo -e "${yellowColour}Ejemplos:${endColour}"
    echo -e "  ${grayColour}./reconkit.sh scope list${endColour}"
    echo -e "  ${grayColour}./reconkit.sh -s mi_ambito.txt scope check 192.168.1.50${endColour}"
    echo
    aviso_legal
}

# Opciones globales
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)    uso; exit 0;;
        -v|--version) msg_kv "reconkit :" "v$VERSION"; exit 0;;
        -s|--scope)   if [ -z "${2:-}" ]; then
                          msg_err "La opción $1 necesita un fichero. Usa -h para ver cómo se utiliza."; exit 2
                      fi
                      SCOPE_FILE=$2; shift 2;;
        -*)           msg_err "Opción desconocida: $(limpia "$1")"
                      msg_err "Usa -h para ver cómo se utiliza."; exit 2;;
        *)            break;;
    esac
done

COMANDO=${1:-}
[ $# -gt 0 ] && shift

case $COMANDO in
    scope)
        cmd_scope "$@"; exit $?;;
    discover|scan|web|report)
        msg_warn "El comando '$COMANDO' todavía no está implementado (llegará en próximas versiones)."
        exit 3;;
    "")
        msg_err "Falta el comando. Usa -h para ver cómo se utiliza."; exit 2;;
    *)
        msg_err "Comando desconocido: $(limpia "$COMANDO")"
        msg_err "Usa -h para ver cómo se utiliza."; exit 2;;
esac
