#!/bin/bash
# =============================================================================
# System Health — Verificación diaria de salud del servidor
# Ejecuta diariamente vía cron: 5:15 AM
# Ubicación: ~/homelab/scripts/maintenance/system-health.sh
# =============================================================================
# Verifica: disco, SMART, RAM, contenedores Docker, uptime
# Notifica: reporte completo vía ntfy (homelab-alerts)
# Umbrales: disco >80% warning, >90% crítico
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/system-health.log"
SEPARATOR="=================================================================="

mkdir -p "$(dirname "$LOG_FILE")"

# --- Funciones auxiliares ---------------------------------------------------

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Verificacion de salud diaria"
log "$SEPARATOR"

WARNINGS=0
CRITICALS=0
REPORT=""

# ─── 1. Uso de disco ───────────────────────────────────────────────────────

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

if [ "$DISK_USAGE" -ge 90 ]; then
    DISK_STATUS="CRITICO"
    ((CRITICALS++))
elif [ "$DISK_USAGE" -ge 80 ]; then
    DISK_STATUS="WARNING"
    ((WARNINGS++))
else
    DISK_STATUS="OK"
fi

REPORT+="Disco: ${DISK_USAGE}% usado (${DISK_USED}/${DISK_TOTAL}, libre: ${DISK_AVAIL}) [$DISK_STATUS]
"
log "[1/5] Disco: ${DISK_USAGE}% — $DISK_STATUS"

# ─── 2. SMART del disco ───────────────────────────────────────────────────

# Verificar si smartctl está disponible
if command -v smartctl &> /dev/null; then
    # Obtener estado general SMART
    SMART_HEALTH=$(sudo smartctl -H /dev/sda 2>/dev/null | grep -i "overall-health" | awk -F': ' '{print $2}' | xargs)

    # Sectores pendientes (Current_Pending_Sector)
    PENDING_SECTORS=$(sudo smartctl -A /dev/sda 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')
    # Errores no corregibles (Offline_Uncorrectable)
    UNCORRECTABLE=$(sudo smartctl -A /dev/sda 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $10}')
    # Temperatura
    DISK_TEMP=$(sudo smartctl -A /dev/sda 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}')

    if [ "$SMART_HEALTH" != "PASSED" ]; then
        SMART_STATUS="CRITICO"
        ((CRITICALS++))
    elif [ "${PENDING_SECTORS:-0}" -gt 100 ]; then
        SMART_STATUS="WARNING"
        ((WARNINGS++))
    else
        SMART_STATUS="OK"
    fi

    REPORT+="SMART: ${SMART_HEALTH:-N/A} — Pendientes: ${PENDING_SECTORS:-N/A}, Errores: ${UNCORRECTABLE:-N/A}, Temp: ${DISK_TEMP:-N/A}C [$SMART_STATUS]
"
    log "[2/5] SMART: $SMART_HEALTH — pendientes: ${PENDING_SECTORS:-?}, errores: ${UNCORRECTABLE:-?} — $SMART_STATUS"
else
    REPORT+="SMART: smartctl no disponible
"
    log "[2/5] SMART: smartctl no encontrado"
fi

# ─── 3. Uso de RAM ────────────────────────────────────────────────────────

RAM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
RAM_USED=$(free -m | awk 'NR==2 {print $3}')
RAM_AVAIL=$(free -m | awk 'NR==2 {printf "%.0f", $7}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))

if [ "$RAM_PERCENT" -ge 90 ]; then
    RAM_STATUS="CRITICO"
    ((CRITICALS++))
elif [ "$RAM_PERCENT" -ge 80 ]; then
    RAM_STATUS="WARNING"
    ((WARNINGS++))
else
    RAM_STATUS="OK"
fi

REPORT+="RAM: ${RAM_PERCENT}% (${RAM_USED}MB/${RAM_TOTAL}MB, libre: ${RAM_AVAIL}MB) [$RAM_STATUS]
"
log "[3/5] RAM: ${RAM_PERCENT}% — $RAM_STATUS"

# ─── 4. Estado de contenedores Docker ──────────────────────────────────────

TOTAL_CONTAINERS=$(docker ps -aq | wc -l)
RUNNING=$(docker ps -q | wc -l)
UNHEALTHY=$(docker ps --filter "health=unhealthy" -q | wc -l)
RESTARTING=$(docker ps --filter "status=restarting" -q | wc -l)
EXITED=$(docker ps --filter "status=exited" -q | wc -l)

PROBLEM_CONTAINERS=""
if [ "$UNHEALTHY" -gt 0 ]; then
    PROBLEM_CONTAINERS+="Unhealthy: $(docker ps --filter "health=unhealthy" --format "{{.Names}}" | tr '\n' ', ' | sed 's/,$//'). "
    ((WARNINGS++))
fi
if [ "$RESTARTING" -gt 0 ]; then
    PROBLEM_CONTAINERS+="Restarting: $(docker ps --filter "status=restarting" --format "{{.Names}}" | tr '\n' ', ' | sed 's/,$//'). "
    ((CRITICALS++))
fi
if [ "$EXITED" -gt 0 ]; then
    PROBLEM_CONTAINERS+="Exited: $(docker ps --filter "status=exited" --format "{{.Names}}" | tr '\n' ', ' | sed 's/,$//'). "
    ((WARNINGS++))
fi

if [ -z "$PROBLEM_CONTAINERS" ]; then
    DOCKER_STATUS="OK"
else
    DOCKER_STATUS="PROBLEMAS"
fi

REPORT+="Docker: ${RUNNING}/${TOTAL_CONTAINERS} activos [$DOCKER_STATUS]
"
if [ -n "$PROBLEM_CONTAINERS" ]; then
    REPORT+="  $PROBLEM_CONTAINERS
"
fi
log "[4/5] Docker: ${RUNNING}/${TOTAL_CONTAINERS} — $DOCKER_STATUS ${PROBLEM_CONTAINERS}"

# ─── 5. Uptime del servidor ───────────────────────────────────────────────

UPTIME_TEXT=$(uptime -p | sed 's/up //')
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

REPORT+="Uptime: ${UPTIME_TEXT}
"
REPORT+="Load avg: ${LOAD_AVG}"
log "[5/5] Uptime: $UPTIME_TEXT — Load: $LOAD_AVG"

# --- Resultado global -------------------------------------------------------

log ""
log "RESUMEN: ${CRITICALS} criticos, ${WARNINGS} warnings"

if [ "$CRITICALS" -gt 0 ]; then
    GLOBAL_STATUS="fail"
    TITLE_EMOJI="rotating_light"
    log "RESULTADO: CRITICO"
elif [ "$WARNINGS" -gt 0 ]; then
    GLOBAL_STATUS="ok"
    TITLE_EMOJI="warning"
    log "RESULTADO: WARNING"
else
    GLOBAL_STATUS="ok"
    TITLE_EMOJI="green_circle"
    log "RESULTADO: OK"
fi

# --- Notificación -----------------------------------------------------------

# Determinar título según severidad
if [ "$CRITICALS" -gt 0 ]; then
    NTFY_TITLE="Health CRITICO: ${CRITICALS} problema(s)"
    NTFY_TAGS="${TITLE_EMOJI},heartbeat"
    NTFY_PRIORITY="high"
elif [ "$WARNINGS" -gt 0 ]; then
    NTFY_TITLE="Health WARNING: ${WARNINGS} alerta(s)"
    NTFY_TAGS="${TITLE_EMOJI},heartbeat"
    NTFY_PRIORITY="default"
else
    NTFY_TITLE="Health OK — Todo operativo"
    NTFY_TAGS="${TITLE_EMOJI},heartbeat"
    NTFY_PRIORITY="default"
fi

# Enviar con curl directo para personalizar tags según severidad
curl -s -u "$NTFY_USER:$NTFY_PASS" \
    -H "Title: $NTFY_TITLE" \
    -H "Tags: $NTFY_TAGS" \
    -H "Priority: $NTFY_PRIORITY" \
    -d "$REPORT" \
    "$NTFY_URL" > /dev/null 2>&1

log "$SEPARATOR"
log "FIN — Verificacion de salud completada"
log "$SEPARATOR"
log ""