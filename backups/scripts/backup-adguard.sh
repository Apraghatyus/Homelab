#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/homelab/backups/adguard
SOURCE_DIR=~/homelab/adguard/data/conf

sudo cp "$SOURCE_DIR/AdGuardHome.yaml" "$BACKUP_DIR/AdGuardHome_${TIMESTAMP}.yaml"
sudo chown $(whoami):$(whoami) "$BACKUP_DIR/AdGuardHome_${TIMESTAMP}.yaml"

# Mantener solo los últimos 10 backups
ls -t "$BACKUP_DIR"/*.yaml 2>/dev/null | tail -n +11 | xargs -r rm

echo "Backup completado: AdGuardHome_${TIMESTAMP}.yaml"
