# Homelab Apraghatyus

Infraestructura de homelabbing para aprendizaje de administración de servidores, redes y despliegue de servicios autoalojados.

## Hardware

| Dispositivo | Specs | Rol |
|---|---|---|
| Servidor Apraghatyus | Core 2 Duo E8400 · 3.8 GB RAM · 298 GB HDD | Servidor principal |
| ASUS TUF Gaming A15 | Ryzen 5 7535HS · 24 GB RAM · 512 GB NVMe | Administración y desarrollo |
| Samsung Galaxy J6 | Android 10 | Panel de control móvil |
| Lenovo IdeaPad Slim 3 | hostname: walx | Dispositivo cliente (Camila) |

**SO:** Ubuntu Server 24.04.3 LTS
**IP Tailscale del servidor:** 100.122.46.43

## Servicios

### Sistema (no Docker)

| Servicio | Función | Estado |
|---|---|---|
| Tailscale VPN | Acceso remoto cifrado (mesh VPN basada en WireGuard) | Operativo |
| UFW Firewall | Todo el tráfico entrante bloqueado excepto interfaz `tailscale0` | Operativo |
| Cockpit | Administración web del sistema (CPU, RAM, discos, red) — `cockpit.home.local` | Operativo |
| Restic | Backup cifrado, comprimido y deduplicado (CLI, no Docker) | Operativo |

### Docker — Fase 0 (Fundamentos)

| Servicio | Puerto | Dominio Local | Función | Control |
|---|---|---|---|---|
| Portainer CE | 9443 | portainer.home.local | Gestión visual de contenedores Docker | Limited (CLI) |
| Nginx Proxy Manager | 80/443/81 | — | Reverse proxy centralizado con SSL wildcard | Limited (CLI) |
| Samba NAS | 445/139 | — | Compartición de archivos SMB | Full Control |
| Home Assistant | 8123 | ha.home.local | Automatización del hogar | Full Control |
| FileBrowser | 8080 | files.home.local | Gestión de archivos vía web (multi-usuario) | Full Control |

### Docker — Fase 1 (Observabilidad y Servicios Esenciales)

| Servicio | Puerto | Dominio Local | Función | Control |
|---|---|---|---|---|
| Uptime Kuma | 3001 | uptime.home.local | Monitoreo de disponibilidad (18 monitores + Status Page) | Full Control |
| Dozzle | 9999 | logs.home.local | Visualización de logs Docker en tiempo real + alertas | Full Control |
| AdGuard Home | 53/8089 | dns.home.local | DNS local + bloqueo de publicidad + DNS Rewrites wildcard | Full Control |
| Vaultwarden | 8222 | vault.home.local | Servidor de contraseñas (2FA, rate limiting, organizaciones) | Full Control |
| Homarr | 7575 | dash.home.local | Dashboard centralizado del homelab con integraciones | Full Control |
| Syncthing | 8384 | sync.home.local | Sincronización de archivos entre dispositivos | Full Control |

### Docker — Fase 2 (Automatización)

| Servicio | Puerto | Dominio Local | Función | Control |
|---|---|---|---|---|
| Watchtower | — | N/A (sin web UI) | Actualización automática de contenedores (fork nickfedor) | Full Control |
| ntfy | 8090 | ntfy.home.local | Servidor de notificaciones push autoalojado | Full Control |

### Monitoreo Externo

| Servicio | Función | Canal |
|---|---|---|
| Healthchecks.io | Dead man's switch — ping cada 5 min, alerta si el servidor cae | Email + ntfy.sh público |

## Automatización Nocturna

El servidor ejecuta tareas automatizadas cada noche sin intervención:

| Hora | Servicio | Tarea | Crontab |
|---|---|---|---|
| 3:00 AM | AdGuard Home | Backup config | usuario |
| 3:00 AM (dom) | Samba | Limpieza papelera | usuario |
| 3:15 AM | Portainer | Backup portainer.db | usuario |
| 3:30 AM | NPM | Backup data/ | usuario |
| 3:40 AM | ntfy | Backup data/ | usuario |
| 3:45 AM | FileBrowser | Backup filebrowser.db | usuario |
| 3:50 AM | Uptime Kuma | Backup kuma.db | usuario |
| 3:55 AM | Homarr | Backup db | usuario |
| 4:00 AM | Watchtower | Actualizaciones Docker | usuario |
| 4:05 AM | Vaultwarden | Backup /data (tar.gz, con stop/start) | usuario |
| 4:30 AM | Restic | Snapshot cifrado y deduplicado de todo | root |
| */5 min | Healthchecks.io | Ping de heartbeat (dead man's switch) | usuario |

Todos los scripts envían notificaciones a ntfy (`homelab-alerts`) con resultado de éxito o fallo.

## Notificaciones (ntfy)

ntfy centraliza todas las alertas del homelab en un solo topic (`homelab-alerts`):

| Fuente | Evento |
|---|---|
| Uptime Kuma | Caída/recuperación de cualquier servicio |
| Watchtower | Actualización de contenedores |
| 8 scripts de backup | Resultado de cada respaldo nocturno |
| Dozzle | Errores fatales, fallos de autenticación, problemas de recursos |
| Healthchecks.io | Caída/recuperación del servidor (canal externo) |

Las notificaciones llegan como push al Galaxy J6 vía la app ntfy.

## Límites de Recursos

Con 3.8 GB de RAM, cada contenedor tiene límites máximos asignados:

| Categoría | Servicios | RAM | CPU |
|---|---|---|---|
| Ligeros | Dozzle, FileBrowser, Watchtower | 128M c/u | 0.25–0.50 |
| Medianos | Uptime Kuma, AdGuard, Vaultwarden, Homarr, Syncthing, Samba, ntfy | 256M c/u | 0.50 |
| Pesados | Home Assistant | 512M | 1.00 |

Total asignado como límite: ~2.5 GB. Margen suficiente para OS, Portainer, NPM y servicios no migrados.

## Estructura del Repositorio

```
~/homelab/
├── .gitignore
├── .pre-commit-config.yaml       ← framework pre-commit (para futuro)
├── README.md
├── adguard/
│   └── docker-compose.yml
├── backups/
│   ├── scripts/
│   │   ├── ntfy-notify.sh        ← función compartida de notificaciones
│   │   ├── backup-adguard.sh
│   │   ├── backup-portainer.sh
│   │   ├── backup-npm.sh
│   │   ├── backup-ntfy.sh
│   │   ├── backup-filebrowser.sh
│   │   ├── backup-uptime-kuma.sh
│   │   ├── backup-homarr.sh
│   │   ├── backup-vaultwarden.sh
│   │   └── restic-backup.sh
│   ├── .restic-password           ← ignorado por git
│   └── restic-repo/               ← ignorado por git
├── dozzle/
│   └── docker-compose.yml
├── filebrowser/
│   ├── docker-compose.yml
│   └── settings.json
├── homarr/
│   ├── docker-compose.yml
│   ├── .env                       ← ignorado por git
│   └── .env.example
├── home-assistant/
│   ├── docker-compose.yml
│   └── config/
│       └── configuration.yaml
├── npm/
│   ├── docker-compose.yml
│   └── certs/                     ← ignorado por git
├── ntfy/
│   ├── docker-compose.yml
│   └── config/
│       └── server.yml
├── portainer/
│   └── docker-compose.yml
├── samba/
│   ├── docker-compose.yml
│   ├── .env                       ← ignorado por git
│   └── .env.example
├── scripts/
│   ├── install-hooks.sh           ← instalador de git hooks
│   └── git-hooks/
│       ├── pre-commit             ← detección de secretos + validación YAML
│       └── commit-msg             ← validación de formato de commits
├── syncthing/
│   └── docker-compose.yml
├── uptime-kuma/
│   └── docker-compose.yml
├── vaultwarden/
│   ├── docker-compose.yml
│   ├── .env                       ← ignorado por git
│   └── .env.example
└── watchtower/
    └── docker-compose.yml
```

## Seguridad

- **Acceso exclusivo por VPN:** todos los puertos están restringidos a la interfaz `tailscale0`. Nada expuesto a internet.
- **SSH por llaves:** autenticación por contraseña deshabilitada.
- **Certificados SSL locales:** wildcard `*.home.local` generado con mkcert, servido por NPM.
- **Security Headers HTTP:** HSTS, X-Frame-Options, CSP, X-XSS-Protection en todos los proxy hosts.
- **Access Lists (HTTP Basic Auth):** capa adicional en servicios críticos (Portainer, Dozzle, AdGuard).
- **Secretos fuera de Git:** archivos `.env` en `.gitignore`. Usar `.env.example` como referencia.
- **Pre-commit hooks:** verificación automática de secretos, sintaxis YAML, archivos `.env` y formato de commits antes de cada commit.
- **Docker socket:** montado como `:ro` (solo lectura) en servicios que solo necesitan consultar.
- **DNS Rewrites:** wildcard `*.home.local` en AdGuard Home, elimina edición manual de archivos hosts.
- **Split DNS:** Tailscale envía solo consultas `.home.local` a AdGuard; el DNS público no se afecta.
- **Autenticación deny-all en ntfy:** sin acceso anónimo, permisos explícitos por usuario y topic.
- **Autenticación nativa en Dozzle:** bcrypt + sesiones, independiente del Access List de NPM.
- **Rate Limiting en Vaultwarden:** protección contra fuerza bruta en login y panel admin.
- **2FA (TOTP) en Vaultwarden:** autenticación de doble factor activada para el usuario admin.
- **Healthchecks.io:** dead man's switch externo que detecta caídas totales del servidor.

## Backups

### Estrategia de backup en 3 capas

| Capa | Herramienta | Qué hace |
|---|---|---|
| 1. Extracción | 8 scripts cron | `docker cp` de bases de datos y configs de cada servicio |
| 2. Snapshot | Restic | Cifrado AES-256, deduplicación, compresión (417 MB → 73.6 MiB) |
| 3. Sincronización | Syncthing | Espejo en tiempo real al portátil ASUS (segunda copia física) |

**Retención de Restic:** 7 diarios, 4 semanales, 3 mensuales.
**Verificación de integridad:** `restic check` automático los domingos.
**Prueba de restauración:** realizada y verificada exitosamente.

## Git & Control de Versiones

- **Repositorio:** privado en GitHub (`Apraghatyus/Homelab`) conectado por SSH.
- **Rama:** `main` (única por ahora).
- **Pre-commit hooks (bash):** detección de secretos en archivos staged, validación de sintaxis YAML, bloqueo de archivos `.env` reales, validación de `.env.example` sin datos privados.
- **Commit-msg hook:** valida formato de mensajes (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `ci:`, `test:`, `perf:`, `style:`).
- **Framework pre-commit:** `.pre-commit-config.yaml` versionado para migración futura a `detect-secrets`, `markdownlint`, etc.
- **Instalación de hooks:** `./scripts/install-hooks.sh` (symlinks de scripts versionados a `.git/hooks/`).

## Reconstruir desde cero

1. Clonar este repo en un servidor con Ubuntu Server + Docker instalado
2. Instalar Git hooks: `./scripts/install-hooks.sh`
3. Copiar los `.env.example` a `.env` y llenar con valores reales
4. Instalar Tailscale y unir a la red
5. Configurar UFW para restringir a `tailscale0`
6. Generar certificados con mkcert
7. Levantar cada servicio en orden:
```bash
cd ~/homelab/<servicio>
docker compose up -d
```
8. Orden recomendado: npm → portainer → adguard → uptime-kuma → dozzle → vaultwarden → homarr → filebrowser → home-assistant → samba → syncthing → ntfy → watchtower
9. Configurar cron jobs para backups y healthchecks
10. Inicializar repositorio de restic: `restic init -r ~/homelab/backups/restic-repo`
11. Instalar Tailscale en dispositivos cliente y configurar Split DNS

## Integrar un nuevo dispositivo

1. Instalar Tailscale en el dispositivo y conectar con la misma cuenta
2. Si usa AdGuard como DNS (Split DNS configurado): los dominios `.home.local` resuelven automáticamente
3. Si no: agregar entradas en el archivo `hosts` del dispositivo apuntando a `100.122.46.43`
4. Instalar certificado raíz de mkcert (`rootCA.crt`) para HTTPS sin advertencias
5. Configurar apps: ntfy (notificaciones), Bitwarden (contraseñas), FileBrowser (archivos)

## Roadmap

| Fase | Estado | Foco |
|---|---|---|
| **Fase 0** — Fundamentos | ✅ Completada | Linux, Docker, VPN, Firewall, NAS |
| **Fase 1** — Observabilidad | ✅ Completada | DNS, monitoreo, contraseñas, dashboard |
| **Fase 2** — Automatización | 🔄 En progreso | Git, Watchtower, backups, notificaciones, pre-commit hooks |
| **Fase 3** — Media y red | ⏳ Pendiente | Jellyfin, VLANs, Mini PC (N100), servidores de juegos |
| **Fase 4** — Seguridad avanzada | ⏳ Pendiente | SSO (Authelia), certificados públicos, WAF |
| **Fase 5** — Orquestación | ⏳ Pendiente | K3s, GitOps, clúster multi-nodo |

### Prioridad de compras (hardware)

| # | Dispositivo | Costo Est. | Impacto | Fase |
|---|---|---|---|---|
| 1 | Disco externo 1–2 TB USB | $40–70 | Backups regla 3-2-1 + expansión NAS | 2 |
| 2 | Raspberry Pi 4/5 | $60–100 | DNS dedicado + gateway VPN | 2 |
| 3 | UPS básico 600VA | $30–60 | Protección de datos y hardware | 2 |
| 4 | Mini PC (N100, 16GB RAM) | $150–250 | Nuevo servidor principal | 3 |
| 5 | Switch gestionable 8 puertos | $30–80 | VLANs y segmentación de red | 3 |
| 6 | SSD/NVMe para Mini PC | $40–60 | Rendimiento de I/O | 3 |
| 7 | Access Point WiFi | $30–60 | WiFi dedicado y estable | 3 |

### Arquitectura objetivo (largo plazo)

- **Dispositivo DNS/VPN:** Raspberry Pi con AdGuard Home + WireGuard
- **Servidor de aplicaciones:** Mini PC N100/N200 con Docker y todos los servicios
- **NAS dedicado:** Mini PC o dispositivo NAS con OpenMediaVault o TrueNAS
- **Reverse proxy / firewall:** Core 2 Duo reciclado con OPNsense
- **Red segmentada:** switch gestionable con VLANs (IoT, servidores, personal, invitados)

## Convenciones

- **Estructura:** cada servicio en `~/homelab/<nombre-servicio>/`
- **Commits:** `feat:` nuevo servicio, `fix:` corrección, `docs:` documentación, `refactor:` reorganización, `ci:` hooks/automatización, `chore:` mantenimiento, `test:` pruebas, `perf:` rendimiento
- **Secretos:** siempre en `.env`, nunca en `docker-compose.yml`
- **Firewall:** todo nuevo puerto se abre solo en `tailscale0`
- **Backups:** script en `~/homelab/backups/scripts/` con notificación ntfy + cron
- **Stacks:** rutas absolutas en Docker Compose (requerido por Portainer Full Control)
- **Documentación:** reporte `.docx` por cada sesión con bugs, soluciones y funcionalidades futuras