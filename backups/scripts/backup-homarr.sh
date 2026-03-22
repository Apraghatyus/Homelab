#!/bin/bash
# Backup Homarr - Base de datos y configuración
# Ejecuta diariamente vía cron a las 3:55 AM

BACKUP_DIR="/home/apraghatyus/homelab/backups/homarr"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Copiar db.sqlite desde el contenedor
docker cp homarr:/appdata/db/db.sqlite "$BACKUP_DIR/homarr_${DATE}.db"

# Mantener solo los últimos 10 backups
cd "$BACKUP_DIR" && ls -t homarr_*.db 2>/dev/null | tail -n +11 | xargs -r rm --

echo "$(date): Backup Homarr completado - homarr_${DATE}.db" >> "$BACKUP_DIR/backup.log"
