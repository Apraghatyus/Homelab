#!/bin/bash
# Backup emupoke - PostgreSQL de cuentas e historial (base "emupoke")
# Ejecuta diariamente vía cron a las 4:45 AM
# pg_dump es consistente en caliente: no hace falta parar el contenedor.
# Va a ~/homelab/backups (no al NAS) para que restic lo recoja cifrado.

source ~/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="$HOME/homelab/backups/emupoke"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER="emupoke-base"
FILE="$BACKUP_DIR/emupoke_${DATE}.dump"

umask 077
mkdir -p "$BACKUP_DIR"

# Formato custom (-Fc): comprimido y restaurable con pg_restore.
# Se conecta por socket local como emupoke_admin (por red está rechazado).
docker exec "$CONTAINER" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U emupoke_admin -d emupoke -Fc' > "$FILE"
RESULT=$?

# Un dump vacío también es un fallo.
[ -s "$FILE" ] || RESULT=1

if [ $RESULT -eq 0 ]; then
    # Mantener solo los últimos 14 backups
    cd "$BACKUP_DIR" && ls -t emupoke_*.dump 2>/dev/null | tail -n +15 | xargs -r rm --
    SIZE=$(du -h "$FILE" | cut -f1)
    echo "$(date): Backup emupoke completado - $(basename "$FILE") ($SIZE)" >> "$BACKUP_DIR/backup.log"
    notify_backup "emupoke" "ok" "$SIZE"
else
    rm -f "$FILE"
    echo "$(date): ERROR - Backup emupoke falló" >> "$BACKUP_DIR/backup.log"
    notify_backup "emupoke" "failure"
fi
