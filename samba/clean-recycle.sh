#!/bin/bash
find /srv/nas -name ".recycle" -type d -exec find {} -type f -mtime +30 -delete \;
find /srv/nas -name ".recycle" -type d -exec find {} -type d -empty -delete \;
echo "$(date): Limpieza de papelera completada" >> /var/log/samba-recycle-clean.log
