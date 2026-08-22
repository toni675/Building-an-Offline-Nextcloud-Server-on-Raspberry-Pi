#!/bin/bash
set -e

BACKUP_ROOT="/backup"
DATE=$(date +%d-%m-%Y)
TEMP_DIR="$BACKUP_ROOT/temp_$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="nextcloud_backup_$DATE.zip"
LOG_FILE="$BACKUP_ROOT/backup.log"

mkdir -p "$BACKUP_ROOT"
echo "[$(date)] Starting backup process..." >> "$LOG_FILE"

mkdir -p "$TEMP_DIR"
echo "[$(date)] Checking Nextcloud data volume..." >> "$LOG_FILE"

if ! mountpoint -q /srv/nextcloud-data; then
echo "ERROR: /srv/nextcloud-data is not mounted."
echo "Unlock the encrypted volume first:"
echo "sudo /usr/local/bin/nextcloud-drive-start"
echo "[$(date)] ERROR: /srv/nextcloud-data is not mounted." >> "$LOG_FILE"
exit 1
fi

if [ -z "$(ls -A /srv/nextcloud-data 2>/dev/null)" ]; then
echo "[$(date)] ERROR: /srv/nextcloud-data is empty." >> "$LOG_FILE"
exit 1
fi

if [ ! -d /srv/nextcloud-data/admin ] || \
[ ! -d /srv/nextcloud-data/user_mobile1 ] || \
[ ! -d /srv/nextcloud-data/user_pc1 ]; then
echo "[$(date)] ERROR: Expected Nextcloud folders were not found." >> "$LOG_FILE"
exit 1
fi

echo "[$(date)] Backing up database..." >> "$LOG_FILE"

mysqldump -u nextcloud -p nextcloud > "$TEMP_DIR/nextcloud_database.sql"
echo "[$(date)] Backing up user data..." >> "$LOG_FILE"
cp -r /srv/nextcloud-data "$TEMP_DIR/"

echo "[$(date)] Backing up configuration files..." >> "$LOG_FILE"
mkdir -p "$TEMP_DIR/configuration"
cp /srv/nextcloud-app/app/config/config.php "$TEMP_DIR/configuration/"
cp /etc/apache2/sites-available/nextcloud.conf "$TEMP_DIR/configuration/"
cp /etc/php/8.4/apache2/php.ini "$TEMP_DIR/configuration/"
echo "[$(date)] Backing up TLS certificates..." >> "$LOG_FILE"
mkdir -p "$TEMP_DIR/ssl"
cp /etc/ssl/certs/nextcloud.local.crt "$TEMP_DIR/ssl/"
cp /etc/ssl/private/nextcloud.local.key "$TEMP_DIR/ssl/"

echo "[$(date)] Creating backup archive..." >> "$LOG_FILE"
cd "$BACKUP_ROOT"
zip -r "$ARCHIVE_NAME" "$(basename "$TEMP_DIR")"

echo "[$(date)] Verifying backup archive..." >> "$LOG_FILE"
unzip -t "$BACKUP_ROOT/$ARCHIVE_NAME" > /dev/null

echo "[$(date)] Backup archive verified successfully." >> "$LOG_FILE"

echo "[$(date)] Cleaning temporary files..." >> "$LOG_FILE"
rm -rf "$TEMP_DIR"
echo "[$(date)] Backup completed successfully." >> "$LOG_FILE"
