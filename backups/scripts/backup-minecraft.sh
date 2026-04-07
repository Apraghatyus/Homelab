#!/bin/bash
# Backup Minecraft - Mundo, plugins, configs
# Ejecuta diariamente vía cron a las 4:20 AM
# Usa RCON para save-off/save-all antes del backup
# evitando corrupción de chunks durante la copia

source ~/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/srv/nas/backups/docker/minecraft"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER="minecraft"
SOURCE_DIR="/data/compose/28/data"

mkdir -p "$BACKUP_DIR"

# Desactivar auto-guardado y forzar flush a disco vía RCON
docker exec "$CONTAINER" rcon-cli save-off > /dev/null 2>&1
docker exec "$CONTAINER" rcon-cli save-all flush > /dev/null 2>&1
sleep 5

# Crear backup comprimido
tar -czf "$BACKUP_DIR/minecraft_${DATE}.tar.gz" -C "$SOURCE_DIR" . 2>/dev/null
RESULT=$?

# Reactivar auto-guardado
docker exec "$CONTAINER" rcon-cli save-on > /dev/null 2>&1

if [ $RESULT -eq 0 ]; then
    # Mantener solo los últimos 10 backups
    cd "$BACKUP_DIR" && ls -t minecraft_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    SIZE=$(du -h "$BACKUP_DIR/minecraft_${DATE}.tar.gz" | cut -f1)
    echo "$(date): Backup Minecraft completado - minecraft_${DATE}.tar.gz ($SIZE)" >> "$BACKUP_DIR/backup.log"
    notify_backup "Minecraft" "ok" "$SIZE — Mundo + plugins + configs"
else
    # Asegurar que save-on se reactive aunque falle el backup
    docker exec "$CONTAINER" rcon-cli save-on > /dev/null 2>&1
    echo "$(date): ERROR - Backup Minecraft falló" >> "$BACKUP_DIR/backup.log"
    notify_backup "Minecraft" "failure" "Error al crear backup"
fi
