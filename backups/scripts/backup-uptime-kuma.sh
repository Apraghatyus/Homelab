#!/bin/bash
# Backup Uptime Kuma - Base de datos
# Ejecuta diariamente vía cron

BACKUP_DIR="/home/apraghatyus/homelab/backups/uptime-kuma"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

docker cp uptime-kuma:/app/data/kuma.db "$BACKUP_DIR/kuma_${DATE}.db"

# Mantener solo los últimos 10 backups
ls -t "$BACKUP_DIR"/kuma_*.db 2>/dev/null | tail -n +11 | xargs -r rm

echo "$(date): Backup Uptime Kuma completado - kuma_${DATE}.db"
