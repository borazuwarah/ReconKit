# reconkit 🔎

Mini framework de reconocimiento para **pruebas de seguridad autorizadas**, escrito en shell.
Se construye por fases y con versiones: cada una añade un módulo y mantiene el historial en la cabecera de `reconkit.sh`.

> ⚠️ **Aviso legal:** usa esta herramienta únicamente en sistemas propios o con autorización
> por escrito del propietario. Acceder o escanear sistemas ajenos sin permiso puede ser ilegal.
> El autor no se hace responsable del mal uso.

## Estado actual: v1.1.0 (descubrimiento de hosts)

| Comando | Estado |
|---|---|
| `scope list` / `scope check <objetivo>` | ✅ Disponible |
| `discover <objetivo>` (hosts activos) | ✅ Disponible (v1.1.0) |
| `scan` (puertos y banners) | ⏳ Próxima versión |
| `web` (reconocimiento web) | ⏳ Planificado |
| `report` (informe Markdown) | ⏳ Planificado |

## Idea clave: el ámbito (scope) es obligatorio

reconkit se niega a actuar sobre cualquier objetivo que no esté en tu fichero de ámbito.
Sin ámbito, o con un ámbito vacío, no hace nada.

```bash
cp scope.txt.example scope.txt     # y edítalo con tus objetivos autorizados
```

Formato (una entrada por línea, `#` para comentarios):

```
127.0.0.1                # IPv4 exacta
192.168.56.0/24          # red CIDR
objetivo.lab.local       # nombre de host
*.lab.local              # cualquier subdominio (no incluye lab.local)
```

## Uso

```bash
./reconkit.sh -h                              # ayuda
./reconkit.sh -v                              # versión
./reconkit.sh scope list                      # muestra el ámbito
./reconkit.sh scope check 192.168.56.10       # ¿está en el ámbito?
./reconkit.sh -s otro_ambito.txt scope check app.lab.local
./reconkit.sh discover 192.168.56.0/24        # hosts activos (ping + SO por TTL)
./reconkit.sh discover -o activos.txt 192.168.56.0/24
./reconkit.sh discover --help                 # opciones de discover
```

### discover

Acepta una o varias IPv4, redes CIDR (hasta `/16`) o nombres de host. **Todos** los objetivos se
comprueban contra el ámbito antes de enviar nada: si uno está fuera, no se sondea ninguno.

Hace ping a cada IP. Si responde, la marca como host activo y estima el sistema operativo por el TTL
de la respuesta (cada router intermedio lo reduce en 1, por eso se usan rangos):

```
[+] Host activo : 192.168.140.1    TTL 255  -> Equipo de red
[+] Host activo : 192.168.140.108  TTL 64   -> Linux/Unix
[+] Host activo : 192.168.140.111  TTL 128  -> Windows
```

| TTL | Sistema estimado |
|---|---|
| 1-64 | Linux/Unix (también macOS, Android...) |
| 65-128 | Windows |
| 129-255 | Equipo de red (router, switch, impresora...) |

Es una estimación: el TTL se puede cambiar, y un host que bloquee ICMP no aparecerá como activo.

| Opción | Descripción |
|---|---|
| `-t, --timeout` | Segundos de espera por ping, 1-10 (por defecto 1). |
| `-j, --hilos` | Pings en paralelo, 1-128 (por defecto 32). |
| `-o, --salida` | Guarda las IPs activas, una por línea (útil para la fase `scan`). |

`-s FICHERO` (o la variable `RECONKIT_SCOPE`) indica otro fichero de ámbito; por defecto `./scope.txt`.

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Correcto / objetivo dentro del ámbito |
| `1` | Objetivo fuera del ámbito |
| `2` | Error de uso, fichero de ámbito ausente o vacío, objetivo no válido, red demasiado amplia |
| `3` | Comando reservado, todavía no implementado |

## Estructura

```
reconkit/
├── reconkit.sh          # punto de entrada, menú y cabecera con historial de versiones
├── lib/
│   ├── common.sh        # colores y formato de salida
│   ├── scope.sh         # gestión del ámbito
│   └── discover.sh      # descubrimiento de hosts activos
├── tests/
│   ├── test_scope.sh    # pruebas del ámbito
│   └── test_discover.sh # pruebas de discover (solo 127.0.0.0/8)
├── scope.txt.example
└── .gitattributes       # fuerza saltos de línea LF en los scripts
```

## Pruebas

```bash
sh tests/test_scope.sh
sh tests/test_discover.sh
```

## Requisitos y notas

- Necesita **bash** (la salida usa `echo -e` y secuencias `\e`) y utilidades estándar: `awk`, `sed`, `grep`, `tr`.
  `discover` usa además `ping` y `getent`; requiere bash ≥ 4.3 (`wait -n`).
  En Windows funciona con WSL o Git Bash.
- Si editas en Windows, guarda los `.sh` con saltos de línea **LF** (el `.gitattributes` ya lo fuerza en Git).
- Los objetivos se validan antes de usarse: solo se admiten letras, números y `. _ : / -`.
- IPv6 aún no está soportado en redes CIDR (las direcciones se comparan como texto).

## Licencia

MIT
