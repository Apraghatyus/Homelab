#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/mnt/nas/backups/docker/adguard
SOURCE_DIR=/home/apraghatyus/homelab/adguard/data/conf

sudo cp "$SOURCE_DIR/AdGuardHome.yaml" "$BACKUP_DIR/AdGuardHome_${TIMESTAMP}.yaml"
sudo chown $(whoami):$(whoami) "$BACKUP_DIR/AdGuardHome_${TIMESTAMP}.yaml"

if [ $? -eq 0 ]; then
    ls -t "$BACKUP_DIR"/*.yaml 2>/dev/null | tail -n +11 | xargs -r rm
    notify_backup "AdGuard Home" "ok" "AdGuardHome_${TIMESTAMP}.yaml"
else
    notify_backup "AdGuard Home" "fail" "Error copiando configuración"
fi
