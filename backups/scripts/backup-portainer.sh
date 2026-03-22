#!/bin/bash
# Backup de Portainer - volumen de datos
BACKUP_DIR="/home/apraghatyus/homelab/backups/portainer"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAX_BACKUPS=10

mkdir -p "$BACKUP_DIR"

# Copiar la base de datos de Portainer desde el volumen Docker
sudo docker cp portainer:/data/portainer.db "$BACKUP_DIR/portainer_${TIMESTAMP}.db"
sudo chown apraghatyus:apraghatyus "$BACKUP_DIR/portainer_${TIMESTAMP}.db"

# Mantener solo los últimos backups
cd "$BACKUP_DIR" && ls -t portainer_*.db | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm

echo "Backup completado: portainer_${TIMESTAMP}.db"