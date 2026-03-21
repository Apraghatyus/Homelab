#!/bin/bash
# Backup NPM - Base de datos y configuración
# Ejecuta diariamente vía cron

BACKUP_DIR="/home/apraghatyus/homelab/backups/npm"
SOURCE_DB="/home/apraghatyus/homelab/npm/data/database.sqlite"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Copiar base de datos (contiene proxy hosts, certs, access lists)
sudo cp "$SOURCE_DB" "$BACKUP_DIR/database_${DATE}.sqlite"
sudo chown apraghatyus:apraghatyus "$BACKUP_DIR/database_${DATE}.sqlite"

# Mantener solo los últimos 10 backups
cd "$BACKUP_DIR" && ls -t database_*.sqlite | tail -n +11 | xargs -r rm --

echo "$(date): Backup NPM completado - database_${DATE}.sqlite"
