#!/bin/bash
# Backup Vaultwarden - Base de datos, adjuntos y claves RSA
# Ejecuta diariamente vía cron a las 4:05 AM
# CRÍTICO: Este backup incluye las claves RSA sin las cuales
# la base de datos es irrecuperable

source ~/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/home/apraghatyus/homelab/backups/vaultwarden"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER="vaultwarden"

mkdir -p "$BACKUP_DIR"

# Detener el contenedor brevemente para consistencia de SQLite
# (SQLite puede corromperse si se copia mientras hay escrituras)
docker stop "$CONTAINER" > /dev/null 2>&1

# Copiar todo el directorio /data como tar comprimido
docker cp "$CONTAINER:/data" - | gzip > "$BACKUP_DIR/vaultwarden_${DATE}.tar.gz" 2>/dev/null
RESULT=$?

# Reiniciar inmediatamente
docker start "$CONTAINER" > /dev/null 2>&1

if [ $RESULT -eq 0 ]; then
    # Mantener solo los últimos 10 backups
    cd "$BACKUP_DIR" && ls -t vaultwarden_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    SIZE=$(du -h "$BACKUP_DIR/vaultwarden_${DATE}.tar.gz" | cut -f1)
    echo "$(date): Backup Vaultwarden completado - vaultwarden_${DATE}.tar.gz ($SIZE)" >> "$BACKUP_DIR/backup.log"
    notify_backup "Vaultwarden" "ok" "$SIZE"
else
    echo "$(date): ERROR - Backup Vaultwarden falló" >> "$BACKUP_DIR/backup.log"
    notify_backup "Vaultwarden" "failure"
fi
