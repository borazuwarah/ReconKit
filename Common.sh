# lib/common.sh: colores y funciones de salida compartidas por reconkit.
# Este fichero se carga con "." desde reconkit.sh; no se ejecuta directamente.

#Colours
endColour="\033[0m\e[0m"
blueColour="\e[0;34m\033[1m"
greenColour="\e[0;32m\033[1m"
grayColour="\e[0;37m\033[1m"
purpleColour="\e[0;35m\033[1m"
redColour="\e[0;31m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
yellowColour="\e[0;33m\033[1m"

# Formato de salida: [+] Etiqueta : valor
msg_kv()   { echo -e "${yellowColour}[+] ${endColour}${grayColour}$1${endColour}${blueColour} $2${endColour}"; }
msg_info() { echo -e "${yellowColour}[+] ${endColour}${grayColour}$1${endColour}"; }
msg_ok()   { echo -e "${greenColour}[+] $1${endColour}"; }
msg_warn() { echo -e "${yellowColour}[!] $1${endColour}"; }
msg_err()  { echo -e "${redColour}[!] $1${endColour}" >&2; }

# Limpia texto que viene del usuario antes de mostrarlo con "echo -e"
# (evita que secuencias como \e o \033 se interpreten como códigos de terminal).
limpia() { printf '%s' "$1" | tr -cd 'A-Za-z0-9._:/*@=,+ -' | cut -c1-120; }

aviso_legal() {
    msg_warn "Usa esta herramienta SOLO en sistemas propios o con autorización por escrito."
}
