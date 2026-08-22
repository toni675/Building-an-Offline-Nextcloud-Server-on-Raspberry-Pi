#!/bin/bash

USB_PATH="/media/security-key"
AUTH_FILE="$USB_PATH/authorized.key"
DATA_PATH="/srv/nextcloud-data"
EXPECTED_UUID="YOUR UUID"
APACHE_SERVICE="apache2"

# Automatically mount the USB security key if the correct device is connected.
if ! mountpoint -q "$USB_PATH"; then
    DEVICE=$(blkid -U "$EXPECTED_UUID")

    if [ -n "$DEVICE" ]; then
        mount "$USB_PATH"
    fi
fi


log() {
    echo "$1"
    logger -t nextcloud-usb-check "$1"
}

if ! mountpoint -q "$DATA_PATH"; then
    log "FAIL: Nextcloud data storage is not mounted."
    systemctl stop "$APACHE_SERVICE"
    exit 1
fi

if ! mountpoint -q "$USB_PATH"; then
    log "FAIL: USB security key is not mounted."
    systemctl stop "$APACHE_SERVICE"
    exit 1
fi

if [ ! -f "$AUTH_FILE" ]; then
    log "FAIL: authorized.key not found."
    systemctl stop "$APACHE_SERVICE"
    exit 1
fi

# Verify the UUID
CURRENT_UUID=$(findmnt -no UUID "$USB_PATH" 2>/dev/null | tr -d '[:space:]')

if [[ "$CURRENT_UUID" != "$EXPECTED_UUID" ]]; then
    log "FAIL: UUID mismatch. Found $CURRENT_UUID"
    if systemctl is-active --quiet "$APACHE_SERVICE"; then
        systemctl stop "$APACHE_SERVICE"
    fi

    exit 1
fi

# Everything is OK
if ! systemctl is-active --quiet "$APACHE_SERVICE"; then
    systemctl start "$APACHE_SERVICE"
    log "SUCCESS: Apache started."
fi

exit 0
