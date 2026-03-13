#!/bin/bash
# backup_flat.sh

BASE_PATH="secret"             # Root path in Vault
BACKUP_DIR="/vault/data"    # Directory to store backups

# Get keys in a clean way
keys=$(vault kv list -format=json "$BASE_PATH" | tr -d '[]" ' | tr ',' '\n')

for key in $keys; do
    SECRET_PATH="$BASE_PATH/$key"
    BACKUP_FILE="$BACKUP_DIR/$key.txt"

    # Extract content field
    vault kv get -field=content "$SECRET_PATH" > "$BACKUP_FILE"
    echo "Backed up: $SECRET_PATH -> $BACKUP_FILE"
done