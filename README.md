# 🏠 Homelab Apraghatyus

Infraestructura de homelabbing para aprendizaje de administración de servidores, redes y despliegue de servicios autoalojados.

## Hardware

| Dispositivo | Specs | Rol |
|---|---|---|
| Servidor Apraghatyus | Core 2 Duo E8400 · 3.8 GB RAM · 298 GB HDD | Servidor principal |
| ASUS TUF Gaming A15 | Ryzen 5 7535HS · 24 GB RAM · 512 GB NVMe | Administración y desarrollo |

**SO:** Ubuntu Server 24.04.3 LTS

## Servicios

### Sistema (no Docker)
| Servicio | Función |
|---|---|
| Tailscale VPN | Acceso remoto cifrado (mesh VPN basada en WireGuard) |
| UFW Firewall | Todo el tráfico entrante bloqueado excepto interfaz tailscale0 |
| Cockpit | Administración web del sistema (CPU, RAM, discos, red) |

### Docker — Fase 0 (Fundamentos)
| Servicio | Puerto | Dominio Local | Función |
|---|---|---|---|
| Portainer CE | 9443 | portainer.home.local | Gestión visual de contenedores Docker |
| Nginx Proxy Manager | 80/443/81 | — | Reverse proxy centralizado con SSL wildcard |
| Samba NAS | 445/139 | — | Compartición de archivos SMB |
| Home Assistant | 8123 | ha.home.local | Automatización del hogar |
| FileBrowser | 8080 | files.home.local | Gestión de archivos vía web |

### Docker — Fase 1 (Observabilidad y Servicios Esenciales)
| Servicio | Puerto | Dominio Local | Función |
|---|---|---|---|
| Uptime Kuma | 3001 | uptime.home.local | Monitoreo de disponibilidad |
| Dozzle | 9999 | logs.home.local | Visualización de logs Docker en tiempo real |
| AdGuard Home | 53/8089 | dns.home.local | DNS local + bloqueo de publicidad |
| Vaultwarden | 8222 | vault.home.local | Servidor de contraseñas (compatible con Bitwarden) |
| Homarr | 7575 | dash.home.local | Dashboard centralizado del homelab |
| Syncthing | 8384 | sync.home.local | Sincronización de archivos entre dispositivos |

## Estructura del Repositorio
```
~/homelab/
├── .gitignore
├── README.md
├── adguard/
│   └── docker-compose.yml
├── dozzle/
│   └── docker-compose.yml
├── filebrowser/
│   ├── docker-compose.yml
│   └── settings.json
├── homarr/
│   ├── docker-compose.yml
│   ├── .env              ← ignorado por git
│   └── .env.example
├── home-assistant/
│   ├── docker-compose.yml
│   └── config/
│       └── configuration.yaml
├── npm/
│   ├── docker-compose.yml
│   └── certs/            ← ignorado por git
├── portainer/
│   └── docker-compose.yml
├── samba/
│   ├── docker-compose.yml
│   ├── .env              ← ignorado por git
│   └── .env.example
├── syncthing/
│   └── docker-compose.yml
├── uptime-kuma/
│   └── docker-compose.yml
└── vaultwarden/
    ├── docker-compose.yml
    ├── .env              ← ignorado por git
    └── .env.example
```

## Seguridad

- **Acceso exclusivo por VPN:** todos los puertos están restringidos a la interfaz `tailscale0`. Nada expuesto a internet.
- **SSH por llaves:** autenticación por contraseña deshabilitada.
- **Certificados SSL locales:** wildcard `*.home.local` generado con mkcert, servido por NPM.
- **Secretos fuera de Git:** archivos `.env` en `.gitignore`. Usar `.env.example` como referencia.
- **Docker socket:** montado como `:ro` (solo lectura) en servicios que solo necesitan consultar.

## Reconstruir desde cero

1. Clonar este repo en un servidor con Ubuntu Server + Docker instalado
2. Copiar los `.env.example` a `.env` y llenar con valores reales
3. Instalar Tailscale y unir a la red
4. Configurar UFW para restringir a `tailscale0`
5. Generar certificados con mkcert
6. Levantar cada servicio en orden:
```bash
   cd ~/homelab/<servicio>
   docker compose up -d
```
7. Orden recomendado: npm → portainer → adguard → uptime-kuma → dozzle → vaultwarden → homarr → filebrowser → home-assistant → samba → syncthing

## Roadmap

| Fase | Estado | Foco |
|---|---|---|
| **Fase 0** — Fundamentos | ✅ Completada | Linux, Docker, VPN, Firewall, NAS |
| **Fase 1** — Observabilidad | ✅ Completada | DNS, monitoreo, contraseñas, dashboard |
| **Fase 2** — Automatización | 🔄 En progreso | Backups, Watchtower, Git, scripts cron |
| **Fase 3** — Media y red | ⏳ Pendiente | Jellyfin, VLANs, Mini PC (N100) |
| **Fase 4** — Seguridad avanzada | ⏳ Pendiente | SSO, certificados públicos, WAF |
| **Fase 5** — Orquestación | ⏳ Pendiente | K3s, GitOps, clúster multi-nodo |

## Convenciones

- **Estructura:** cada servicio en `~/homelab/<nombre-servicio>/`
- **Commits:** `feat:` nuevo servicio, `fix:` corrección de bug, `docs:` documentación, `refactor:` reorganización
- **Secretos:** siempre en `.env`, nunca en `docker-compose.yml`
- **Firewall:** todo nuevo puerto se abre solo en `tailscale0`
# test
