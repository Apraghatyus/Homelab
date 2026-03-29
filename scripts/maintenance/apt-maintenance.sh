#!/bin/bash
# =============================================================================
# APT Maintenance — Actualizaciones de seguridad automáticas
# Ejecuta vía cron: miércoles y domingos a las 5:45 AM
# Ubicación: ~/homelab/scripts/maintenance/apt-maintenance.sh
# =============================================================================
# Actualiza: índice de paquetes, parches de seguridad, limpieza
# Requiere: root (sudo crontab)
# Notifica: paquetes actualizados vía ntfy (homelab-alerts)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/apt-maintenance.log"
SEPARATOR="=================================================================="

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Mantenimiento APT"
log "$SEPARATOR"

ERRORS=0

# ─── 1. Actualizar índice de paquetes ──────────────────────────────────────

log "[1/3] Actualizando indice de paquetes..."
apt update -qq 2>> "$LOG_FILE"
if [ $? -ne 0 ]; then
    log "[1/3] ERROR actualizando indice"
    ((ERRORS++))
else
    log "[1/3] Indice actualizado"
fi

# ─── 2. Contar paquetes actualizables antes de aplicar ─────────────────────

UPGRADABLE_BEFORE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
SECURITY_LIST=$(apt list --upgradable 2>/dev/null | grep -i "security" || true)
SECURITY_COUNT=$(echo "$SECURITY_LIST" | grep -c "security" 2>/dev/null)
[ -z "$SECURITY_COUNT" ] && SECURITY_COUNT=0

log "[2/3] Paquetes actualizables: $UPGRADABLE_BEFORE (seguridad: $SECURITY_COUNT)"

# ─── 3. Aplicar actualizaciones de seguridad ───────────────────────────────

log "[3/3] Aplicando actualizaciones de seguridad..."

# Verificar si unattended-upgrades está instalado
if ! command -v unattended-upgrade &> /dev/null; then
    log "[3/3] Instalando unattended-upgrades..."
    apt install -y unattended-upgrades 2>> "$LOG_FILE"
fi

# Ejecutar solo actualizaciones de seguridad (no todas)
UPGRADE_OUTPUT=$(unattended-upgrade -v 2>&1)
UPGRADE_RESULT=$?

# Extraer paquetes actualizados del output
UPGRADED_PACKAGES=$(echo "$UPGRADE_OUTPUT" | grep -oP "Packages that will be upgraded:.*|Packages that are upgraded:.*" || true)
INSTALLED_COUNT=$(echo "$UPGRADE_OUTPUT" | grep -c "is installed" 2>/dev/null || echo "0")

if [ $UPGRADE_RESULT -ne 0 ]; then
    log "[3/3] ERROR aplicando actualizaciones"
    ((ERRORS++))
else
    log "[3/3] Actualizaciones aplicadas"
fi

# ─── 4. Limpieza de paquetes obsoletos ─────────────────────────────────────

AUTOREMOVE_OUTPUT=$(apt autoremove -y -qq 2>&1)
AUTOREMOVE_COUNT=$(echo "$AUTOREMOVE_OUTPUT" | grep -oP '\d+ to remove' | grep -oP '\d+' || echo "0")

log "Paquetes limpiados (autoremove): $AUTOREMOVE_COUNT"

# ─── 5. Verificar si se requiere reinicio ──────────────────────────────────

REBOOT_REQUIRED="No"
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED="SI — reinicio pendiente"
    log "ATENCION: Reinicio requerido por actualizaciones del kernel"
fi

# --- Resumen ----------------------------------------------------------------

# Contar actualizables restantes
UPGRADABLE_AFTER=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
APPLIED=$((UPGRADABLE_BEFORE - UPGRADABLE_AFTER))
if [ "$APPLIED" -lt 0 ]; then
    APPLIED=0
fi

SUMMARY="Paquetes disponibles: ${UPGRADABLE_BEFORE}
Seguridad aplicados: ${APPLIED}
Pendientes: ${UPGRADABLE_AFTER}
Autoremove: ${AUTOREMOVE_COUNT}
Reinicio requerido: ${REBOOT_REQUIRED}"

log ""
log "RESUMEN:"
log "Disponibles: $UPGRADABLE_BEFORE"
log "Aplicados: $APPLIED"
log "Pendientes: $UPGRADABLE_AFTER"
log "Autoremove: $AUTOREMOVE_COUNT"
log "Reinicio: $REBOOT_REQUIRED"
log "Errores: $ERRORS"

# --- Notificación -----------------------------------------------------------

if [ "$ERRORS" -eq 0 ]; then
    if [ "$REBOOT_REQUIRED" != "No" ]; then
        # OK pero necesita reinicio — prioridad alta para que no se olvide
        curl -s -u "$NTFY_USER:$NTFY_PASS" \
            -H "Title: APT OK — Reinicio pendiente" \
            -H "Tags: package,warning" \
            -H "Priority: high" \
            -d "$SUMMARY" \
            "$NTFY_URL" > /dev/null 2>&1
    else
        notify_maintenance "APT Update" "ok" "$SUMMARY"
    fi
else
    notify_maintenance "APT Update" "fail" "$SUMMARY"
fi

log "$SEPARATOR"
log "FIN — Mantenimiento APT completado"
log "$SEPARATOR"
log ""