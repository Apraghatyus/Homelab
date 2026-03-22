#!/bin/bash
# Backup FileBrowser - Base de datos
# Ejecuta diariamente vía cron a las 3:45 AM
BACKUP_DIR="/home/apraghatyus/homelab/backups/filebrowser"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAX_BACKUPS=10

mkdir -p "$BACKUP_DIR"

# Copiar la base de datos desde el contenedor
docker cp filebrowser:/database/filebrowser.db "$BACKUP_DIR/filebrowser_${TIMESTAMP}.db"

# Mantener solo los últimos backups
cd "$BACKUP_DIR" && ls -t filebrowser_*.db | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm

echo "$(date): Backup FileBrowser completado - filebrowser_${TIMESTAMP}.db"
