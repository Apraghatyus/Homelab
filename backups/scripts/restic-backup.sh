#!/bin/bash
# Restic Backup — Snapshot cifrado, comprimido y deduplicado
# Ejecuta diariamente vía cron a las 4:30 AM (después de todos los backups individuales)
# Respalda: ~/homelab/ (configs + scripts + backups) + /mnt/nas/ (archivos NAS)

source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

REPO="/mnt/nas/backups/restic"
PASSWORD_FILE="/home/apraghatyus/homelab/backups/.restic-password"
LOG_FILE="/home/apraghatyus/homelab/backups/restic-backup.log"

# --- Backup ---
echo "$(date): Iniciando backup restic..." >> "$LOG_FILE"

sudo restic -r "$REPO" --password-file "$PASSWORD_FILE" backup \
  /home/apraghatyus/homelab \
  /mnt/nas \
  --exclude="$REPO" \
  --exclude="/home/apraghatyus/homelab/*/data/icon_cache" \
  --exclude="/mnt/nas/*/.recycle" \
  --tag homelab \
  --tag automated \
  2>> "$LOG_FILE"

BACKUP_RESULT=$?

# --- Retención ---
if [ $BACKUP_RESULT -eq 0 ]; then
  echo "$(date): Aplicando política de retención..." >> "$LOG_FILE"

  sudo restic -r "$REPO" --password-file "$PASSWORD_FILE" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 3 \
    --prune \
    2>> "$LOG_FILE"
fi

# --- Verificación de integridad (solo domingos) ---
DOW=$(date +%u)
if [ "$DOW" -eq 7 ] && [ $BACKUP_RESULT -eq 0 ]; then
  echo "$(date): Verificación de integridad semanal..." >> "$LOG_FILE"
  sudo restic -r "$REPO" --password-file "$PASSWORD_FILE" check 2>> "$LOG_FILE"
  CHECK_RESULT=$?
  if [ $CHECK_RESULT -ne 0 ]; then
    echo "$(date): ERROR - Verificación de integridad falló" >> "$LOG_FILE"
    notify_backup "Restic INTEGRIDAD" "failure"
  fi
fi

# --- Notificación ---
if [ $BACKUP_RESULT -eq 0 ]; then
  SNAP_SIZE=$(sudo restic -r "$REPO" --password-file "$PASSWORD_FILE" stats --mode raw-data 2>/dev/null | grep "Total Size:" | awk '{print $3, $4}')
  echo "$(date): Backup completado — Repo total: $SNAP_SIZE" >> "$LOG_FILE"
  notify_backup "Restic" "ok" "$SNAP_SIZE"
else
  echo "$(date): ERROR - Backup restic falló" >> "$LOG_FILE"
  notify_backup "Restic" "failure"
fi

# --- Corregir permisos (sudo crea archivos como root) ---
chown -R apraghatyus:apraghatyus /mnt/nas/backups/restic
echo "---" >> "$LOG_FILE"
