#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/mnt/nas/backups/docker/portainer"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAX_BACKUPS=10

mkdir -p "$BACKUP_DIR"

sudo docker cp portainer:/data/portainer.db "$BACKUP_DIR/portainer_${TIMESTAMP}.db"
sudo chown apraghatyus:apraghatyus "$BACKUP_DIR/portainer_${TIMESTAMP}.db"

if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t portainer_*.db | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm
    notify_backup "Portainer" "ok" "portainer_${TIMESTAMP}.db"
else
    notify_backup "Portainer" "fail" "Error copiando base de datos"
fi
