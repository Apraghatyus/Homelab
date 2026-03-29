#!/bin/bash
# =============================================================================
# Temp Monitor — Monitoreo de temperatura CPU
# Ejecuta cada 30 minutos vía cron
# Ubicación: ~/homelab/scripts/maintenance/temp-monitor.sh
# =============================================================================
# Solo notifica si hay problema (>70°C warning, >80°C crítico)
# En condiciones normales solo escribe al log (sin notificación)
# =============================================================================

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

LOG_FILE="/home/apraghatyus/homelab/scripts/maintenance/logs/temp-monitor.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

WARNING_TEMP=70
CRITICAL_TEMP=80

# --- Leer temperatura CPU ---------------------------------------------------

CPU_TEMP=""

# Método 1: /sys/class/thermal (disponible en la mayoría de sistemas)
if [ -z "$CPU_TEMP" ]; then
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            # El valor está en miligrados (ej: 45000 = 45°C)
            RAW_TEMP=$(cat "$zone" 2>/dev/null)
            if [ -n "$RAW_TEMP" ] && [ "$RAW_TEMP" -gt 0 ] 2>/dev/null; then
                ZONE_TEMP=$((RAW_TEMP / 1000))
                # Quedarse con la temperatura más alta
                if [ -z "$CPU_TEMP" ] || [ "$ZONE_TEMP" -gt "$CPU_TEMP" ]; then
                    CPU_TEMP=$ZONE_TEMP
                fi
            fi
        fi
    done
fi

# Método 2: lm-sensors (si está instalado)
if [ -z "$CPU_TEMP" ] && command -v sensors &> /dev/null; then
    CPU_TEMP=$(sensors 2>/dev/null | grep -oP 'Core 0.*?\+\K[0-9]+' | head -1)
fi

# Método 3: SMART del disco como proxy (último recurso)
if [ -z "$CPU_TEMP" ] && command -v smartctl &> /dev/null; then
    CPU_TEMP=$(sudo smartctl -A /dev/sda 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}')
    if [ -n "$CPU_TEMP" ]; then
        log "NOTA: usando temperatura del disco como proxy (sensores CPU no disponibles)"
    fi
fi

# --- Evaluar ----------------------------------------------------------------

if [ -z "$CPU_TEMP" ]; then
    log "ERROR: no se pudo leer la temperatura del sistema"
    notify_maintenance "Temp Monitor" "fail" "No se pudo leer la temperatura. Verificar sensores."
    exit 1
fi

# Determinar estado
if [ "$CPU_TEMP" -ge "$CRITICAL_TEMP" ]; then
    STATUS="CRITICO"
    log "CRITICO: ${CPU_TEMP}C (umbral: ${CRITICAL_TEMP}C)"

    curl -s -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Temperatura CRITICA: ${CPU_TEMP}C" \
        -H "Tags: fire,rotating_light" \
        -H "Priority: urgent" \
        -d "CPU: ${CPU_TEMP}C — Umbral critico: ${CRITICAL_TEMP}C
Accion requerida: verificar ventilacion y carga del servidor.
Considerar apagar servicios no esenciales." \
        "$NTFY_URL" > /dev/null 2>&1

elif [ "$CPU_TEMP" -ge "$WARNING_TEMP" ]; then
    STATUS="WARNING"
    log "WARNING: ${CPU_TEMP}C (umbral: ${WARNING_TEMP}C)"

    curl -s -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Temperatura alta: ${CPU_TEMP}C" \
        -H "Tags: thermometer,warning" \
        -H "Priority: high" \
        -d "CPU: ${CPU_TEMP}C — Umbral warning: ${WARNING_TEMP}C
Monitorear. Si sube a ${CRITICAL_TEMP}C se enviara alerta critica." \
        "$NTFY_URL" > /dev/null 2>&1

else
    # Normal — solo log, sin notificación
    STATUS="OK"
    log "OK: ${CPU_TEMP}C"
fi