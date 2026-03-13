#!/bin/bash

# Check if base URL is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <base-url>"
  echo "Example: $0 https://test.ctag-edmus.com"
  exit 1
fi

BASE_URL=${1%/}

aws eks update-kubeconfig --region eu-central-1 --name mvd-on-aws

kubectl -n mvd scale deploy --all --replicas=0

# Set environment variables for all three connectors
echo "Updating environment variables with base URL: $BASE_URL"
kubectl -n mvd set env deploy/ita-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ita/public/api/public"
kubectl -n mvd set env deploy/avanza-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/avanza/public/api/public"
kubectl -n mvd set env deploy/ctag-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ctag/public/api/public"

echo "Done! Connectors are being updated."



echo "Starting vault backup and statefulset replacement..."
cd vault

# Create backup of vaults
kubectl -n mvd cp ./vault-backup.sh consumer-vault-0:/vault/data/vault-backup.sh
kubectl -n mvd cp ./vault-restore.sh consumer-vault-0:/vault/data/vault-restore.sh

kubectl -n mvd cp ./vault-backup.sh provider-vault-0:/vault/data/vault-backup.sh
kubectl -n mvd cp ./vault-restore.sh provider-vault-0:/vault/data/vault-restore.sh

kubectl -n mvd exec consumer-vault-0 -- sh /vault/data/vault-backup.sh
kubectl -n mvd exec provider-vault-0 -- sh /vault/data/vault-backup.sh

# Copy vault data to local

kubectl -n mvd cp consumer-vault-0:/vault/data ./consumer_vault_backup
kubectl -n mvd cp provider-vault-0:/vault/data ./provider_vault_backup

# Delete vault StatefulSets
kubectl -n mvd delete sts provider-vault consumer-vault 

# Create new vault StatefulSets
kubectl -n mvd apply -f ./new-consumer-vault-sts.yaml
kubectl -n mvd apply -f ./new-provider-vault-sts.yaml

# Wait for vaults to be ready
kubectl -n mvd rollout status sts/consumer-vault --timeout=120s
kubectl -n mvd rollout status sts/provider-vault --timeout=120s

# Copy vault data to new vaults
kubectl -n mvd cp ./vault-backup.sh consumer-vault-0:/vault/data/vault-backup.sh
kubectl -n mvd cp ./vault-restore.sh consumer-vault-0:/vault/data/vault-restore.sh

kubectl -n mvd cp ./vault-backup.sh provider-vault-0:/vault/data/vault-backup.sh
kubectl -n mvd cp ./vault-restore.sh provider-vault-0:/vault/data/vault-restore.sh

kubectl -n mvd cp ./consumer_vault_backup/. consumer-vault-0:/vault/data
kubectl -n mvd cp ./provider_vault_backup/. provider-vault-0:/vault/data

# Restore vaults
kubectl -n mvd exec consumer-vault-0 -- sh /vault/data/vault-restore.sh
kubectl -n mvd exec provider-vault-0 -- sh /vault/data/vault-restore.sh

kubectl -n mvd scale deploy --all --replicas=1
echo "Done! Vaults are being restored."
