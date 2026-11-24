# Reconkit Framework

Mini framework de reconocimiento para **pruebas de seguridad autorizadas**, escrito en shell.
Se construye por fases y con versiones: cada una añade un módulo y mantiene el historial en la cabecera de `reconkit.sh`.

> **Aviso legal:** usa esta herramienta únicamente en sistemas propios o con autorización
> por escrito del propietario. Acceder o escanear sistemas ajenos sin permiso puede ser ilegal.
> El autor no se hace responsable del mal uso.

## Estado actual: v1.0.0 (núcleo)

| Comando | Estado |
|---|---|
| `scope list` / `scope check <objetivo>` | ✅ Disponible |
| `discover` (hosts activos) | ⏳ Próxima versión |
| `scan` (puertos y banners) | ⏳ Planificado |
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
```

`-s FICHERO` (o la variable `RECONKIT_SCOPE`) indica otro fichero de ámbito; por defecto `./scope.txt`.

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Correcto / objetivo dentro del ámbito |
| `1` | Objetivo fuera del ámbito |
| `2` | Error de uso, fichero de ámbito ausente o vacío, objetivo no válido |
| `3` | Comando reservado, todavía no implementado |

## Estructura

```
reconkit/
├── reconkit.sh          # punto de entrada, menú y cabecera con historial de versiones
├── lib/
│   ├── common.sh        # colores y formato de salida
│   └── scope.sh         # gestión del ámbito
├── tests/test_scope.sh  # pruebas
├── scope.txt.example
└── .gitattributes       # fuerza saltos de línea LF en los scripts
```

## Pruebas

```bash
sh tests/test_scope.sh
```

## Requisitos y notas

- Necesita **bash** (la salida usa `echo -e` y secuencias `\e`) y utilidades estándar: `awk`, `sed`, `grep`, `tr`.
  En Windows funciona con WSL o Git Bash.
- Si editas en Windows, guarda los `.sh` con saltos de línea **LF** (el `.gitattributes` ya lo fuerza en Git).
- Los objetivos se validan antes de usarse: solo se admiten letras, números y `. _ : / -`.
- IPv6 aún no está soportado en redes CIDR (las direcciones se comparan como texto).

## Licencia

MIT
