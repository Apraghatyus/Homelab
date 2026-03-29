#!/bin/bash
# =============================================================================
# Cert Check — Verificación de expiración de certificados SSL
# Ejecuta semanalmente vía cron: domingos a las 5:50 AM
# Ubicación: ~/homelab/scripts/maintenance/cert-check.sh
# =============================================================================
# Verifica: certificado wildcard mkcert y CA raíz
# Umbrales: <30 días = warning, <7 días = crítico
# Notifica: días restantes vía ntfy (homelab-alerts)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/cert-check.log"
SEPARATOR="=================================================================="

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

# --- Configuración de certificados ------------------------------------------

# Certificados a verificar: "nombre|ruta"
CERTS=(
    "Wildcard *.home.local|/home/apraghatyus/homelab/npm/certs/_wildcard.home.local+1.pem"
    "CA Raiz mkcert|/home/apraghatyus/.local/share/mkcert/rootCA.pem"
)

WARNING_DAYS=30
CRITICAL_DAYS=7

# --- Inicio -----------------------------------------------------------------

log "$SEPARATOR"
log "INICIO — Verificacion de certificados"
log "$SEPARATOR"

WARNINGS=0
CRITICALS=0
REPORT=""
TOTAL_CERTS=0
CERTS_OK=0

for cert_entry in "${CERTS[@]}"; do
    CERT_NAME="${cert_entry%%|*}"
    CERT_PATH="${cert_entry##*|}"
    ((TOTAL_CERTS++))

    if [ ! -f "$CERT_PATH" ]; then
        log "[$CERT_NAME] ERROR: archivo no encontrado — $CERT_PATH"
        REPORT+="$CERT_NAME: NO ENCONTRADO
"
        ((CRITICALS++))
        continue
    fi

    # Extraer fecha de expiración
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_PATH" 2>/dev/null | cut -d= -f2)

    if [ -z "$EXPIRY_DATE" ]; then
        log "[$CERT_NAME] ERROR: no se pudo leer la fecha de expiracion"
        REPORT+="$CERT_NAME: ERROR DE LECTURA
"
        ((CRITICALS++))
        continue
    fi

    # Calcular días restantes
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

    # Fecha legible
    EXPIRY_READABLE=$(date -d "$EXPIRY_DATE" '+%Y-%m-%d')

    # Determinar estado
    if [ "$DAYS_LEFT" -le 0 ]; then
        STATUS="EXPIRADO"
        ((CRITICALS++))
    elif [ "$DAYS_LEFT" -le "$CRITICAL_DAYS" ]; then
        STATUS="CRITICO"
        ((CRITICALS++))
    elif [ "$DAYS_LEFT" -le "$WARNING_DAYS" ]; then
        STATUS="WARNING"
        ((WARNINGS++))
    else
        STATUS="OK"
        ((CERTS_OK++))
    fi

    REPORT+="$CERT_NAME: ${DAYS_LEFT} dias (vence ${EXPIRY_READABLE}) [$STATUS]
"
    log "[$CERT_NAME] ${DAYS_LEFT} dias restantes — vence $EXPIRY_READABLE — $STATUS"
done

# --- Resumen ----------------------------------------------------------------

log ""
log "RESUMEN: ${CERTS_OK}/${TOTAL_CERTS} OK, ${WARNINGS} warnings, ${CRITICALS} criticos"

# --- Notificación -----------------------------------------------------------

if [ "$CRITICALS" -gt 0 ]; then
    curl -s -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Certificados CRITICO — Accion requerida" \
        -H "Tags: rotating_light,lock" \
        -H "Priority: urgent" \
        -d "$REPORT" \
        "$NTFY_URL" > /dev/null 2>&1
elif [ "$WARNINGS" -gt 0 ]; then
    curl -s -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Certificados WARNING — Renovar pronto" \
        -H "Tags: warning,lock" \
        -H "Priority: high" \
        -d "$REPORT" \
        "$NTFY_URL" > /dev/null 2>&1
else
    notify_maintenance "Cert Check" "ok" "$REPORT"
fi

log "$SEPARATOR"
log "FIN — Verificacion de certificados completada"
log "$SEPARATOR"
log ""