# SysGuard

SysGuard es una herramienta de monitoreo de sistemas Linux escrita enteramente en Bash: CPU, RAM, swap, disco, red, procesos y estado general del host, con alertas por umbral, historial en CSV, un dashboard interactivo en terminal y reportes HTML. Sin frameworks, sin base de datos, sin dependencias pesadas — pensada para instalarse en un servidor real y correr por cron o systemd sin fricción.

## Qué problema resuelve

Un servidor pequeño no necesita Prometheus+Grafana para saber si el disco se está llenando. SysGuard cubre ese punto intermedio: más que un script que imprime porcentajes, pero sin la complejidad operativa de una pila de observability completa. Se instala copiando el directorio, se configura editando un archivo de texto, y se integra con `cron`/`systemd`/scripts de automatización a través de exit codes estándar.

## Features

- **CLI con subcomandos**: `check`, `dashboard`, `report`, `history`, `processes`, `network`, `system`.
- **Alertas de tres niveles** (OK/WARNING/CRITICAL) con **cooldown persistente** — no repite el mismo aviso cada minuto, y registra la recuperación cuando la métrica vuelve a la normalidad.
- **Historial ligero en CSV**, con agregados (promedio/mínimo/pico) para las últimas 24h o 7 días.
- **Dashboard interactivo** en terminal, con barras de progreso y colores, degradado automáticamente en terminales sin UTF-8/color.
- **Reportes HTML** autocontenidos (HTML+CSS puro, sin JavaScript) con historial y procesos incluidos.
- **Notificaciones desacopladas** vía webhook (JSON sobre HTTP), con arquitectura preparada para sumar proveedores sin tocar el resto del código.
- **Exit codes estándar** (0/1/2/3) pensados para integrarse con cron, systemd o cualquier sistema de monitorización externo.
- **Disco multi-filesystem**: autodetecta todos los puntos de montaje reales, ignorando pseudo-filesystems (`tmpfs`, `proc`, `overlay`, etc.).
- **Logging estructurado** (ISO8601 + nivel + mensaje) con rotación por tamaño.

## Architecture

```
sysguard (entrypoint)
   │
   ├── lib/util.sh        exit codes, die(), require_cmd(), tiempo
   ├── lib/colors.sh      ANSI + símbolos + caracteres de caja/barra (con fallback ASCII)
   ├── lib/config.sh      carga y valida config/sysguard.conf (+ secrets.conf opcional)
   ├── lib/metrics.sh     única fuente de verdad: cpu/ram/swap/disco/red/load/uptime/sistema
   ├── lib/thresholds.sh  OK/WARNING/CRITICAL + selección de "peor disco"
   ├── lib/alerts.sh      cooldown persistente (data/alerts.state, con flock)
   ├── lib/log.sh         logging estructurado + rotación
   ├── lib/notify.sh      NOTIFICATION_METHOD=none|webhook
   ├── lib/history.sh     historial CSV + agregados
   ├── lib/processes.sh   top procesos (ps)
   ├── lib/dashboard.sh   panel interactivo en terminal
   └── lib/report.sh      generación de reports/status.html
```

Cada comando de la CLI (`check`, `dashboard`, `report`, `history`) reutiliza las mismas funciones de `lib/metrics.sh` y `lib/thresholds.sh` — la forma de calcular el uso de CPU o de decidir si un disco está en WARNING vive en un único lugar.

```
SysGuard
   │
   ├── CLI (check / dashboard / report / history / processes / network / system)
   └── Notifications
          ├── webhook (curl, JSON sobre HTTP)
          └── (nuevos proveedores futuros se agregan aquí, sin tocar alerts.sh)
```

## Requirements

Solo herramientas estándar de cualquier distribución Linux moderna:

`bash` (4+), `awk`, `sed`, `grep`, `df`, `ps`, `ip`, `date`, `numfmt`, `flock`, `find`, `du`, `head`, `tail`.

Opcional: `curl` (solo si `NOTIFICATION_METHOD=webhook`; si falta, la notificación se omite con un aviso claro en el log, el resto de SysGuard sigue funcionando).

No requiere Python, Node, Docker, ni ninguna base de datos.

## Installation

```bash
git clone https://github.com/D0nFrancisco/sysguard.git
cd sysguard
./sysguard --check
```

No hay paso de "instalación" real: `sysguard` resuelve su propia ubicación (siguiendo symlinks) y calcula todas sus rutas (logs, reportes, datos) a partir de ahí, así que funciona igual si lo cloneas en `/opt/sysguard`, lo enlazas a `/usr/local/bin/sysguard`, o lo ejecutas por ruta relativa.

## Configuration

Toda la configuración vive en `config/sysguard.conf` (versionado en git) y, opcionalmente, `config/secrets.conf` (gitignored, para datos sensibles como la URL del webhook — copia `config/secrets.conf.example`).

```ini
CPU_WARNING=70
CPU_CRITICAL=90

RAM_WARNING=75
RAM_CRITICAL=90

SWAP_WARNING=50
SWAP_CRITICAL=80

DISK_WARNING=80
DISK_CRITICAL=90

NETWORK_DOWN=critical        # critical | warning | ignore

DISK_PATHS=""                # vacío = autodetectar todos los filesystems reales
DISK_EXCLUDE_TYPES="proc sysfs tmpfs devtmpfs overlay squashfs cgroup cgroup2 devpts mqueue tracefs debugfs configfs fusectl pstore binfmt_misc autofs"
                              # tipos de filesystem a ignorar en la autodetección (solo aplica si DISK_PATHS="")
CPU_SAMPLE_INTERVAL=1        # segundos entre las dos muestras usadas para el delta de CPU

ALERT_COOLDOWN=300           # segundos mínimos entre avisos repetidos del mismo estado

HISTORY_ENABLED=true
HISTORY_RETENTION_DAYS=7

LOG_MAX_SIZE_KB=5120
LOG_RETENTION_DAYS=14

NOTIFICATION_METHOD=none     # none | webhook
```

La configuración se valida al vuelo: un valor fuera de rango (`CPU_WARNING=120`), un WARNING mayor o igual que su CRITICAL, o `NOTIFICATION_METHOD=webhook` sin `WEBHOOK_URL` definido, hacen que SysGuard termine con un mensaje claro y exit code 3 — nunca falla en silencio.

## CLI Usage

```
sysguard [COMANDO]
sysguard [--COMANDO]
```

| Comando | Alias | Qué hace |
|---|---|---|
| `check` | `--check` | Chequeo único no interactivo (para cron/systemd/scripts) |
| `dashboard` | `--dashboard` | Panel interactivo en terminal |
| `report` | `--report` | Genera `reports/status.html` |
| `history` | `--history` | Consulta el historial (`--last 24h\|7d`) |
| `processes` | `--processes` | Top procesos por CPU y por RAM |
| `network` | `--network` | Estado de la interfaz principal, IP, gateway, throughput |
| `system` | `--system` | Información general del host |
| `help` | `--help` / sin argumentos | Ayuda |
| `version` | `--version` | Versión |

```bash
./sysguard --check
./sysguard network
./sysguard --history --last 7d
./sysguard --check ; echo "exit: $?"
```

## Dashboard

```bash
./sysguard --dashboard
```

```
┌────────────────────────────────────────────────────────────┐
│ hostname: server01                    uptime: 3h 14m       │
├────────────────────────────────────────────────────────────┤
│ CPU      ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 7%      ✓ OK       │
│ RAM      █████░░░░░░░░░░░░░░░░░░░░░░░░░ 17%     ✓ OK       │
│ SWAP     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0%      ✓ OK       │
│ DISK     ████████████████████░░░░░░░░░░ 68%     ✓ OK       │
├────────────────────────────────────────────────────────────┤
│ LOAD    1.26 / 1.42 / 1.82                                 │
│ NETWORK  enp42s0   UP      RX: 4.2K/s      TX: 6.1K/s      │
├────────────────────────────────────────────────────────────┤
│ PROCESSES (top CPU)                                        │
│ brave            10.2% CPU     751M RAM                    │
│ claude           4.6% CPU      457M RAM                    │
└────────────────────────────────────────────────────────────┘
```

En una terminal real se refresca automáticamente (cada `CPU_SAMPLE_INTERVAL` segundos, que es el mismo intervalo que ya usa para medir CPU/red, sin overhead extra) hasta que se presiona `Ctrl+C`. Si la salida no es una terminal (pipe, redirección, tests), dibuja un único frame y termina — nunca queda colgado en un script.

Los colores y los caracteres de caja/barra se degradan automáticamente a ASCII si la terminal no anuncia soporte UTF-8, o se desactivan del todo si `NO_COLOR` está definida o no hay TTY.

## Alerts

Cada métrica se evalúa contra dos umbrales (`*_WARNING`, `*_CRITICAL`) y se le asigna un estado: `OK`, `WARNING` o `CRITICAL`.

```
CPU:       OK
RAM:       WARNING
Disk:      CRITICAL
Network:   OK
```

El estado de cada métrica se persiste en `data/alerts.state` (protegido con `flock` para evitar carreras si dos ejecuciones se solapan). El comportamiento es:

- Primera vez que se cruza un umbral → se notifica y se registra en el log.
- Mientras siga en el mismo estado no-OK → no se repite el aviso hasta que pase `ALERT_COOLDOWN` segundos.
- Cuando vuelve a `OK` → se registra la recuperación (una sola vez).
- Si vuelve a cruzar el umbral después de recuperarse → se trata como una alerta nueva.

Esto es lo que hace seguro correr `sysguard --check` cada minuto por cron sin inundar el log ni el webhook.

## History

```bash
./sysguard --check          # cada ejecución agrega una fila a data/history.csv
./sysguard --history
./sysguard --history --last 7d
```

Columnas del CSV: `timestamp,hostname,cpu,ram,swap,disk,load,rx,tx,status`. Sin base de datos — es un CSV plano que se poda automáticamente según `HISTORY_RETENTION_DAYS`.

```
Últimas 24 horas (287 muestras)

CPU
  Promedio: 41%
  Mínimo:   12%
  Pico:     89%

RAM
  Promedio: 57%
  Mínimo:   48%
  Pico:     82%

Disco (peor punto de montaje en cada check)
  Actual: 78%
  Cambio en el período: 3.2%
```

## HTML Reports

```bash
./sysguard --report
```

Genera `reports/status.html`: un dashboard estático (HTML + CSS, sin JavaScript ni frameworks) con estado general, tarjetas de CPU/RAM/swap/disco con barra de progreso, información del sistema, tabla de filesystems, top procesos, e historial reciente con sus agregados. Pensado para servirse con cualquier servidor web estático o abrirse directamente en el navegador.

## Cron

```cron
*/5 * * * * /opt/sysguard/sysguard --check
```

`--check` es no interactivo por diseño: no usa `clear`, no asume TTY, y todas sus rutas son absolutas (calculadas a partir de la ubicación real del script, no del directorio de trabajo). Probado explícitamente con un entorno mínimo tipo cron (`PATH` reducido, sin variables de entorno, sin terminal).

## Systemd

Alternativa opcional a cron, en `systemd/`:

```bash
sudo cp systemd/sysguard.service systemd/sysguard.timer /etc/systemd/system/
# Edita ExecStart en sysguard.service para apuntar a tu ruta real de instalación.
sudo systemctl daemon-reload
sudo systemctl enable --now sysguard.timer
```

`sysguard.timer` corre `sysguard --check` cada 5 minutos (`OnUnitActiveSec=5min`, `Persistent=true` para recuperar el chequeo perdido tras un apagado).

## Testing

```bash
./tests/run_all.sh
```

Sin bats-core ni ningún framework externo: `tests/helpers.sh` es un mini framework de aserciones de ~30 líneas. Cubre:

- `test_config.sh` — config válida carga; rango inválido, orden WARNING≥CRITICAL y archivo ausente fallan con exit 3.
- `test_thresholds.sh` — límites de `threshold_status`, `network_status` según `NETWORK_DOWN`, prioridad de `worst_status`, mapeo de `status_exit_code`, selección de "peor disco".
- `test_metrics.sh` — rangos de RAM/swap contra `/proc` real; sin interfaz de red (ruta default vacía); regresión del bug de `df` con encabezado traducido por locale; exclusión de pseudo-filesystems.

## Exit Codes

| Code | Significado |
|---|---|
| `0` | OK — todas las métricas evaluadas están dentro de rango |
| `1` | WARNING — alguna métrica superó su umbral WARNING |
| `2` | CRITICAL — alguna métrica superó su umbral CRITICAL |
| `3` | ERROR — fallo de ejecución, dependencia faltante o configuración inválida |

```bash
./sysguard --check
echo $?
```

## Project Structure

```
sysguard/
├── sysguard                  # entrypoint (CLI)
├── lib/                      # una función, un archivo — ver Architecture
├── config/
│   ├── sysguard.conf          # versionado en git
│   └── secrets.conf.example   # plantilla; secrets.conf real es gitignored
├── data/                      # history.csv, alerts.state (gitignored)
├── logs/                      # sysguard.log (gitignored)
├── reports/                   # status.html (gitignored)
├── systemd/                   # unidades opcionales
├── tests/                     # test_*.sh + run_all.sh + fixtures/
└── README.md
```

## Example Output

```
$ ./sysguard --check
SysGuard CHECK — 2026-08-08T14:53:15-05:00
CPU       2%                       ✓ OK
RAM       20%                      ✓ OK
SWAP      0%                       ✓ OK
DISK      68% (/)                  ✓ OK
NETWORK   up (enp42s0)             ✓ OK

STATUS: OK
```

## Troubleshooting

- **`falta el comando requerido 'X'`** — instala esa herramienta; SysGuard valida sus dependencias al inicio y no ejecuta nada a medias.
- **Config inválida al arrancar** — el mensaje indica exactamente qué variable y por qué (fuera de rango, WARNING≥CRITICAL, falta WEBHOOK_URL, etc.). Corrige `config/sysguard.conf`.
- **`--dashboard` no se refresca** — solo lo hace con una terminal real adjunta; si la salida está redirigida a un archivo o pipe, es intencional que dibuje un único frame y termine.
- **El webhook no llega** — revisa `logs/sysguard.log`: los fallos de notificación (servidor caído, `curl` ausente, URL mal configurada) se registran ahí sin interrumpir el check.
- **Cron no genera nada** — usa siempre la ruta absoluta al binario `sysguard` en el crontab; verifica con `*/5 * * * * /ruta/completa/sysguard --check >> /tmp/sysguard-cron.log 2>&1` mientras depuras.

## Future Improvements

Deliberadamente fuera de alcance por ahora (ver criterio de diseño: preferir pocas funciones bien hechas):

- Proveedores de notificación adicionales (Slack, Telegram, email) — la arquitectura de `lib/notify.sh` ya lo permite sin refactor.
- Chequeo de conectividad a Internet/DNS/gateway — se evaluó y se descartó: depende de que el entorno tenga salida a red, lo que da falsos positivos en sandboxes/CI.
- Monitoreo multi-host — SysGuard es, por diseño, una herramienta de un solo host.
- Gráficos en el reporte HTML más allá de las barras de progreso actuales.
