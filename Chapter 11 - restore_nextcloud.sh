#!/bin/bash
set -e
BACKUP_FILE="$1"
RESTORE_DIR="/backup/nextcloud_restore"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found."
    exit 1
fi

if [ ! -d /srv/nextcloud-app/app ]; then
    echo "ERROR: Nextcloud application not found."
    echo "Install Nextcloud before running this restore."
    exit 1
fi

echo "Checking Nextcloud data volume..."

if ! sudo cryptsetup status nextcloud_crypt >/dev/null 2>&1; then
    echo "ERROR: Encrypted volume “nextcloud_data” is not unlocked."
    echo "Unlock the encrypted volume first:"
    echo "sudo /usr/local/bin/nextcloud-drive-start"
    exit 1
fi

if ! mountpoint -q /srv/nextcloud-data; then
    echo "ERROR: /srv/nextcloud-data is not mounted."
    echo "Unlock the encrypted volume first:"
    echo "sudo /usr/local/bin/nextcloud-drive-start"
    exit 1
fi

echo "Stopping services..."

sudo systemctl stop apache2
sudo systemctl stop mariadb

rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

echo "Extracting backup..."

unzip "$BACKUP_FILE" -d "$RESTORE_DIR"

BACKUP_ROOT=$(find "$RESTORE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)

if [ -z "$BACKUP_ROOT" ]; then
    echo "ERROR: Could not locate backup contents."
    exit 1
fi

echo "Restoring SSL certificates..."
sudo cp -a "$BACKUP_ROOT/ssl/." /etc/ssl/

echo "Restoring Nextcloud application..."
echo "Skipping application restore..."
echo "The Nextcloud application must already be installed."

echo "Restoring configuration..."
sudo cp "$BACKUP_ROOT/configuration/config.php" \
/srv/nextcloud-app/app/config/config.php

sudo cp "$BACKUP_ROOT/configuration/nextcloud.conf" \
/etc/apache2/sites-available/nextcloud.conf

sudo a2ensite nextcloud.conf >/dev/null 2>&1 || true

sudo systemctl reload apache2 >/dev/null 2>&1 || true

sudo cp "$BACKUP_ROOT/configuration/php.ini" \
/etc/php/8.4/apache2/php.ini

echo "Restoring data directory..."
sudo rsync -a "$BACKUP_ROOT/nextcloud-data/" /srv/nextcloud-data/

echo "Restoring database..."

DB_DUMP=$(find "$BACKUP_ROOT" -name "*.sql" | head -1)

if [ -z "$DB_DUMP" ]; then
       echo "ERROR: Database dump not found."
    exit 1
fi
sudo systemctl start mariadb

mysql -u root nextcloud < "$DB_DUMP"

echo "Setting permissions..."

sudo chown www-data:www-data /srv/nextcloud-app/app/config/config.php

sudo chown -R www-data:www-data /srv/nextcloud-app

sudo chown -R www-data:www-data /srv/nextcloud-data

echo "Starting services..."
sudo systemctl restart mariadb
sudo systemctl restart apache2

echo "Verifying Nextcloud installation..."
sudo -u www-data php /srv/nextcloud-app/app/occ status
rm -rf "$RESTORE_DIR"

echo "Restoration completed."
