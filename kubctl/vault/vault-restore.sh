#!/bin/bash
# restore_flat.sh

BACKUP_DIR="/vault/data"

for file in "$BACKUP_DIR"/*.txt; do
    RESTORE_PATH="secret/$(basename "$file" .txt)"
    vault kv put "$RESTORE_PATH" content="$(cat "$file")"
    echo "Restored: $RESTORE_PATH from $file"
done