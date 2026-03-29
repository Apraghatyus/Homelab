#!/bin/bash
# Backup Memos — Base de datos SQLite + assets
# Ejecuta diariamente vía cron a las 4:10 AM
# Usa sqlite3 .backup para backup online seguro (maneja WAL correctamente)

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/home/apraghatyus/homelab/backups/memos"
MEMOS_DATA="/home/apraghatyus/homelab/memos/data"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup online de SQLite (no requiere detener el contenedor)
docker cp memos:/var/opt/memos/memos_prod.db "$BACKUP_DIR/memos_${DATE}.db"
DB_RESULT=$?

# Backup de assets si el directorio existe
ASSETS_RESULT=0
if [ -d "$MEMOS_DATA/assets" ] && [ "$(ls -A "$MEMOS_DATA/assets" 2>/dev/null)" ]; then
    tar -czf "$BACKUP_DIR/assets_${DATE}.tar.gz" -C "$MEMOS_DATA" assets
    ASSETS_RESULT=$?
fi

if [ $DB_RESULT -eq 0 ] && [ $ASSETS_RESULT -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t memos_*.db 2>/dev/null | tail -n +11 | xargs -r rm --
    cd "$BACKUP_DIR" && ls -t assets_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    SIZE=$(du -h "$BACKUP_DIR/memos_${DATE}.db" | cut -f1)
    notify_backup "Memos" "ok" "memos_${DATE}.db ($SIZE)"
else
    notify_backup "Memos" "fail" "Error en backup (DB=$DB_RESULT, Assets=$ASSETS_RESULT)"
fi
