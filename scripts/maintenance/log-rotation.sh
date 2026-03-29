#!/bin/bash
# =============================================================================
# Log Rotation — Rotación y purga de logs del homelab
# Ejecuta semanalmente vía cron: domingos a las 5:30 AM
# Ubicación: ~/homelab/scripts/maintenance/log-rotation.sh
# =============================================================================
# Rota: logs de mantenimiento, backups y servicios
# Purga: rotaciones con más de 30 días
# Notifica: resultado vía ntfy (homelab-alerts)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_DIR="/home/apraghatyus/homelab/scripts/maintenance/logs"
SELF_LOG="${LOG_DIR}/log-rotation.log"
SEPARATOR="=================================================================="
DATE_SUFFIX=$(date '+%Y%m%d')
RETENTION_DAYS=30

mkdir -p "$LOG_DIR"

# --- Funciones auxiliares ---------------------------------------------------

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$SELF_LOG"
}

rotate_log() {
    local log_path="$1"
    local log_name=$(basename "$log_path")

    if [ ! -f "$log_path" ]; then
        log "  SKIP: $log_path no existe"
        return 1
    fi

    local size=$(du -k "$log_path" | cut -f1)

    # Solo rotar si tiene más de 1KB de contenido
    if [ "$size" -le 1 ]; then
        log "  SKIP: $log_name vacio o muy pequeno (${size}KB)"
        return 1
    fi

    local rotated="${log_path}.${DATE_SUFFIX}"

    # Si ya existe una rotación de hoy, agregar timestamp
    if [ -f "$rotated" ]; then
        rotated="${log_path}.${DATE_SUFFIX}_$(date '+%H%M%S')"
    fi

    cp "$log_path" "$rotated"
    > "$log_path"

    log "  ROTADO: $log_name (${size}KB) -> $(basename "$rotated")"
    ((ROTATED_COUNT++))
    ROTATED_SIZE=$((ROTATED_SIZE + size))
    return 0
}

purge_old_rotations() {
    local log_path="$1"
    local dir=$(dirname "$log_path")
    local base=$(basename "$log_path")

    # Buscar rotaciones antiguas (archivos .log.YYYYMMDD con más de N días)
    local old_files=$(find "$dir" -name "${base}.*" -type f -mtime +${RETENTION_DAYS} 2>/dev/null)

    if [ -n "$old_files" ]; then
        local count=$(echo "$old_files" | wc -l)
        echo "$old_files" | xargs rm -f
        log "  PURGADO: $count rotacion(es) antigua(s) de $base"
        PURGED_COUNT=$((PURGED_COUNT + count))
    fi
}

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Rotacion de logs semanal"
log "$SEPARATOR"

ROTATED_COUNT=0
ROTATED_SIZE=0
PURGED_COUNT=0
ERRORS=0

# Lista de logs a gestionar
LOGS_TO_ROTATE=(
    # Logs de mantenimiento
    "/home/apraghatyus/homelab/scripts/maintenance/logs/docker-cleanup.log"
    "/home/apraghatyus/homelab/scripts/maintenance/logs/system-health.log"
    # Logs de backups
    "/home/apraghatyus/homelab/backups/restic-backup.log"
    # Logs de servicios
    "/var/log/samba-recycle-clean.log"
)

# Rotar cada log
log "--- Rotacion ---"
for log_path in "${LOGS_TO_ROTATE[@]}"; do
    rotate_log "$log_path"
done

# Purgar rotaciones antiguas
log "--- Purga (>${RETENTION_DAYS} dias) ---"
for log_path in "${LOGS_TO_ROTATE[@]}"; do
    purge_old_rotations "$log_path"
done

# Purgar también las rotaciones del propio log-rotation.log
purge_old_rotations "$SELF_LOG"

# --- Resumen ----------------------------------------------------------------

SUMMARY="Logs rotados: ${ROTATED_COUNT} (${ROTATED_SIZE}KB total)
Rotaciones purgadas: ${PURGED_COUNT} (>${RETENTION_DAYS} dias)
Logs gestionados: ${#LOGS_TO_ROTATE[@]}"

log ""
log "RESUMEN:"
log "Rotados: ${ROTATED_COUNT} (${ROTATED_SIZE}KB)"
log "Purgados: ${PURGED_COUNT}"
log "Errores: ${ERRORS}"

# --- Notificación -----------------------------------------------------------

notify_maintenance "Log Rotation" "ok" "$SUMMARY"

log "$SEPARATOR"
log "FIN — Rotacion de logs completada"
log "$SEPARATOR"
log ""