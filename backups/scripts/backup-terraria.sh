#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/srv/nas/backups/docker/terraria"
SOURCE_DIR="/home/apraghatyus/homelab/terraria/data"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Terraria vanilla no tiene RCON, copiamos directamente los archivos del mundo
tar -czf "$BACKUP_DIR/terraria_${DATE}.tar.gz" \
  -C "$SOURCE_DIR" \
  Apraghatyus.wld \
  Apraghatyus.wld.bak \
  serverconfig.txt \
  banlist.txt \
  2>/dev/null

RESULT=$?

if [ $RESULT -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t terraria_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    SIZE=$(du -h "$BACKUP_DIR/terraria_${DATE}.tar.gz" | cut -f1)
    notify_backup "Terraria" "ok" "$SIZE"
else
    notify_backup "Terraria" "failure"
fi
