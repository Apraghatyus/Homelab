#!/bin/bash
# =============================================================================
# Weekly Report — Reporte semanal consolidado del homelab
# Ejecuta semanalmente vía cron: domingos a las 6:00 AM
# Ubicación: ~/homelab/scripts/maintenance/weekly-report.sh
# =============================================================================
# Recopila: restic, Docker, disco, Watchtower, RAM, uptime
# No ejecuta acciones, solo reporta
# Notifica: reporte consolidado vía ntfy (homelab-alerts)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/weekly-report.log"
SEPARATOR="=================================================================="
RESTIC_REPO="/home/apraghatyus/homelab/backups/restic-repo"
RESTIC_PASS="/home/apraghatyus/homelab/backups/.restic-password"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Reporte semanal"
log "$SEPARATOR"

REPORT=""

# ─── 1. Restic — Último snapshot y tamaño del repo ────────────────────────

RESTIC_SECTION=""
if command -v restic &> /dev/null && [ -d "$RESTIC_REPO" ]; then
    # Contar snapshots totales
    SNAP_COUNT=$(sudo restic -r "$RESTIC_REPO" --password-file "$RESTIC_PASS" snapshots --json 2>/dev/null | grep -o '"time"' | wc -l)

    # Último snapshot (fecha)
    LAST_SNAP=$(sudo restic -r "$RESTIC_REPO" --password-file "$RESTIC_PASS" snapshots --latest 1 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' | tail -1)

    # Tamaño del repo en disco
    REPO_SIZE=$(du -sh "$RESTIC_REPO" 2>/dev/null | cut -f1)

    RESTIC_SECTION="Restic: ${SNAP_COUNT} snapshots, repo: ${REPO_SIZE}
  Ultimo: ${LAST_SNAP:-N/A}"
    log "[1/5] Restic: $SNAP_COUNT snapshots, $REPO_SIZE, ultimo: ${LAST_SNAP:-N/A}"
else
    RESTIC_SECTION="Restic: no disponible"
    log "[1/5] Restic: no disponible"
fi

REPORT+="$RESTIC_SECTION
"

# ─── 2. Docker — Contenedores con reinicios recientes ─────────────────────

DOCKER_SECTION=""
TOTAL_CONTAINERS=$(docker ps -q | wc -l)
TOTAL_IMAGES=$(docker images -q | wc -l)

# Detectar contenedores con RestartCount > 0
RESTART_INFO=""
RESTART_TOTAL=0
while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $NF}')
    RESTARTS=$(docker inspect --format='{{.RestartCount}}' "$NAME" 2>/dev/null)
    if [ "${RESTARTS:-0}" -gt 0 ]; then
        RESTART_INFO+="  $NAME: ${RESTARTS} restart(s)
"
        RESTART_TOTAL=$((RESTART_TOTAL + RESTARTS))
    fi
done < <(docker ps --format "{{.Names}}")

DOCKER_SECTION="Docker: ${TOTAL_CONTAINERS} contenedores, ${TOTAL_IMAGES} imagenes"
if [ "$RESTART_TOTAL" -gt 0 ]; then
    DOCKER_SECTION+="
  Reinicios: ${RESTART_TOTAL} total
${RESTART_INFO}"
else
    DOCKER_SECTION+="
  Sin reinicios (estable)"
fi

log "[2/5] Docker: $TOTAL_CONTAINERS contenedores, $RESTART_TOTAL reinicios"
REPORT+="$DOCKER_SECTION
"

# ─── 3. Watchtower — Actualizaciones recientes ────────────────────────────

WATCHTOWER_SECTION=""
if docker ps --format '{{.Names}}' | grep -q watchtower; then
    # Buscar actualizaciones en los logs de los últimos 7 días
    UPDATES=$(docker logs watchtower --since 168h 2>&1 | grep -i "updated" | grep -v "Found" || true)
    UPDATE_COUNT=$(echo "$UPDATES" | grep -c "updated" 2>/dev/null || echo "0")

    if [ "$UPDATE_COUNT" -gt 0 ] && [ -n "$UPDATES" ]; then
        WATCHTOWER_SECTION="Watchtower: ${UPDATE_COUNT} actualizacion(es) esta semana"
    else
        WATCHTOWER_SECTION="Watchtower: sin actualizaciones esta semana"
    fi
else
    WATCHTOWER_SECTION="Watchtower: contenedor no encontrado"
fi

log "[3/5] $WATCHTOWER_SECTION"
REPORT+="$WATCHTOWER_SECTION
"

# ─── 4. Disco y almacenamiento ────────────────────────────────────────────

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

# NAS usage si existe
NAS_SECTION=""
if [ -d "/srv/nas" ]; then
    NAS_SIZE=$(du -sh /srv/nas 2>/dev/null | cut -f1)
    NAS_SECTION=" | NAS: ${NAS_SIZE}"
fi

DISK_SECTION="Disco: ${DISK_USAGE} (${DISK_USED}/${DISK_TOTAL}, libre: ${DISK_AVAIL})${NAS_SECTION}"
log "[4/5] $DISK_SECTION"
REPORT+="$DISK_SECTION
"

# ─── 5. Sistema — RAM, Uptime, Load ──────────────────────────────────────

RAM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
RAM_USED=$(free -m | awk 'NR==2 {print $3}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
UPTIME_TEXT=$(uptime -p | sed 's/up //')
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

SYSTEM_SECTION="RAM: ${RAM_PERCENT}% (${RAM_USED}/${RAM_TOTAL}MB) | Load: ${LOAD_AVG}
Uptime: ${UPTIME_TEXT}"

log "[5/5] RAM: ${RAM_PERCENT}%, Uptime: $UPTIME_TEXT"
REPORT+="$SYSTEM_SECTION"

# --- Notificación -----------------------------------------------------------

log ""
log "Reporte enviado a ntfy"

curl -s -u "$NTFY_USER:$NTFY_PASS" \
    -H "Title: Reporte Semanal — Homelab Apraghatyus" \
    -H "Tags: clipboard,bar_chart" \
    -H "Priority: default" \
    -d "$REPORT" \
    "$NTFY_URL" > /dev/null 2>&1

log "$SEPARATOR"
log "FIN — Reporte semanal completado"
log "$SEPARATOR"
log ""