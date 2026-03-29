#!/bin/bash
# =============================================================================
# Docker Cleanup — Limpieza segura de recursos Docker huérfanos
# Ejecuta semanalmente vía cron: domingos a las 5:00 AM
# Ubicación: ~/homelab/scripts/maintenance/docker-cleanup.sh
# =============================================================================
# Limpia: imágenes dangling, contenedores parados, redes sin usar
# NO limpia: volúmenes (protege datos de servicios detenidos como HA)
# Notifica: resultado + espacio liberado vía ntfy (homelab-alerts)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/docker-cleanup.log"
SEPARATOR="=================================================================="

# Crear directorio de logs si no existe
mkdir -p "$(dirname "$LOG_FILE")"

# --- Funciones auxiliares ---------------------------------------------------

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

get_disk_usage() {
    df -BM --output=used / | tail -1 | tr -d ' M'
}

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Limpieza Docker semanal"
log "$SEPARATOR"

ERRORS=0
DISK_BEFORE=$(get_disk_usage)

# 1. Contenedores parados (exited + dead)
log "[1/3] Limpiando contenedores parados..."
CONTAINERS_REMOVED=$(docker container prune -f 2>> "$LOG_FILE")
CONTAINER_COUNT=$(echo "$CONTAINERS_REMOVED" | grep -oP 'Deleted Containers:\s*\K\d+' || echo "0")
if [ $? -ne 0 ]; then
    log "[1/3] ERROR limpiando contenedores"
    ((ERRORS++))
else
    log "[1/3] Contenedores eliminados: $CONTAINER_COUNT"
fi

# 2. Imágenes dangling (sin tag, no referenciadas)
log "[2/3] Limpiando imágenes dangling..."
IMAGES_OUTPUT=$(docker image prune -f 2>> "$LOG_FILE")
IMAGE_SPACE=$(echo "$IMAGES_OUTPUT" | grep -oP 'Total reclaimed space:\s*\K.*' || echo "0B")
if [ $? -ne 0 ]; then
    log "[2/3] ERROR limpiando imágenes"
    ((ERRORS++))
else
    log "[2/3] Espacio recuperado (imágenes): $IMAGE_SPACE"
fi

# 3. Redes sin usar (no conectadas a ningún contenedor activo)
log "[3/3] Limpiando redes sin usar..."
NETWORKS_OUTPUT=$(docker network prune -f 2>> "$LOG_FILE")
NETWORK_COUNT=$(echo "$NETWORKS_OUTPUT" | grep -c 'Deleted Networks:' || echo "0")
if [ $? -ne 0 ]; then
    log "[3/3] ERROR limpiando redes"
    ((ERRORS++))
else
    log "[3/3] Redes limpiadas"
fi

# --- Resumen ----------------------------------------------------------------

DISK_AFTER=$(get_disk_usage)
DISK_FREED=$((DISK_BEFORE - DISK_AFTER))

# Si el valor es negativo (otros procesos escribieron), reportar 0
if [ "$DISK_FREED" -lt 0 ]; then
    DISK_FREED=0
fi

# Estadísticas de Docker post-limpieza
TOTAL_IMAGES=$(docker images -q | wc -l)
TOTAL_CONTAINERS=$(docker ps -aq | wc -l)
RUNNING_CONTAINERS=$(docker ps -q | wc -l)
TOTAL_VOLUMES=$(docker volume ls -q | wc -l)
TOTAL_NETWORKS=$(docker network ls -q | wc -l)

SUMMARY="Espacio liberado: ${DISK_FREED}MB (imágenes: ${IMAGE_SPACE})
Estado post-limpieza:
• Imágenes: ${TOTAL_IMAGES}
• Contenedores: ${RUNNING_CONTAINERS} activos / ${TOTAL_CONTAINERS} total
• Volúmenes: ${TOTAL_VOLUMES} (no tocados)
• Redes: ${TOTAL_NETWORKS}"

log ""
log "RESUMEN:"
log "Espacio liberado: ${DISK_FREED}MB"
log "Imágenes totales: ${TOTAL_IMAGES}"
log "Contenedores: ${RUNNING_CONTAINERS} activos / ${TOTAL_CONTAINERS} total"
log "Volúmenes: ${TOTAL_VOLUMES} (protegidos)"
log "Redes: ${TOTAL_NETWORKS}"
log "Errores: ${ERRORS}"

# --- Notificación -----------------------------------------------------------

if [ "$ERRORS" -eq 0 ]; then
    log "RESULTADO: OK"
    notify_maintenance "Docker Cleanup" "ok" "$SUMMARY"
else
    log "RESULTADO: ERRORES ($ERRORS)"
    notify_maintenance "Docker Cleanup" "fail" "$SUMMARY"
fi

log "$SEPARATOR"
log "FIN — Limpieza Docker completada"
log "$SEPARATOR"
log ""
