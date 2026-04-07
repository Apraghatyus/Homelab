#!/bin/bash
# Backup Immich — Base de datos PostgreSQL
# Ejecuta diariamente vía cron a las 4:15 AM
# La librería de fotos está protegida por RAID 1 en el NAS

source ~/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/mnt/nas/backups/docker/immich"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION=10

mkdir -p "$BACKUP_DIR"

# pg_dump desde el contenedor
docker exec immich_postgres pg_dumpall -U postgres | gzip > "$BACKUP_DIR/immich_db_${DATE}.sql.gz"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$BACKUP_DIR/immich_db_${DATE}.sql.gz" | cut -f1)

    # Rotación: mantener solo las últimas N copias
    ls -tp "$BACKUP_DIR"/immich_db_*.sql.gz | tail -n +$((RETENTION + 1)) | xargs -r rm --

    COUNT=$(ls "$BACKUP_DIR"/immich_db_*.sql.gz 2>/dev/null | wc -l)

    echo "[$(date)] OK — ${SIZE}" >> "$BACKUP_DIR/backup.log"
    notify_backup "Immich" "ok" "DB: ${SIZE} | Copias: ${COUNT}/${RETENTION}"
else
    echo "[$(date)] FAILED" >> "$BACKUP_DIR/backup.log"
    notify_backup "Immich" "fail" "Error en pg_dump de Immich"
fi
