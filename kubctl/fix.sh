#!/bin/bash

# Check if base URL is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <base-url>"
  echo "Example: $0 https://test.ctag-edmus.com"
  exit 1
fi

BASE_URL=${1%/}

aws eks update-kubeconfig --region eu-central-1 --name mvd-on-aws
kubectl config set-context --current --namespace=mvd

kubectl scale deploy --all --replicas=0

# Set environment variables for all three connectors
echo "Updating environment variables with base URL: $BASE_URL"
kubectl set env deploy/ita-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ita/public/api/public"
kubectl set env deploy/avanza-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/avanza/public/api/public"
kubectl set env deploy/ctag-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ctag/public/api/public"

echo "Done! Connectors are being updated."



echo "Starting vault backup and statefulset replacement..."
cd vault

# Create backup of vaults
kubectl cp ./vault-backup.sh consumer-vault-0:/vault/data/vault-backup.sh
kubectl cp ./vault-restore.sh consumer-vault-0:/vault/data/vault-restore.sh

kubectl cp ./vault-backup.sh provider-vault-0:/vault/data/vault-backup.sh
kubectl cp ./vault-restore.sh provider-vault-0:/vault/data/vault-restore.sh

kubectl exec consumer-vault-0 -- sh /vault/data/vault-backup.sh
kubectl exec provider-vault-0 -- sh /vault/data/vault-backup.sh

# Copy vault data to local

kubectl cp consumer-vault-0:/vault/data ./consumer_vault_backup
kubectl cp provider-vault-0:/vault/data ./provider_vault_backup

# Delete vault StatefulSets
kubectl delete sts provider-vault consumer-vault 

# Create new vault StatefulSets
kubectl apply -f ./new-consumer-vault-sts.yaml
kubectl apply -f ./new-provider-vault-sts.yaml

# Wait for vaults to be ready
kubectl rollout status sts/consumer-vault --timeout=120s
kubectl rollout status sts/provider-vault --timeout=120s

# Copy vault data to new vaults
kubectl cp ./vault-backup.sh consumer-vault-0:/vault/data/vault-backup.sh
kubectl cp ./vault-restore.sh consumer-vault-0:/vault/data/vault-restore.sh

kubectl cp ./vault-backup.sh provider-vault-0:/vault/data/vault-backup.sh
kubectl cp ./vault-restore.sh provider-vault-0:/vault/data/vault-restore.sh

kubectl cp ./consumer_vault_backup/. consumer-vault-0:/vault/data
kubectl cp ./provider_vault_backup/. provider-vault-0:/vault/data

# Restore vaults
kubectl exec consumer-vault-0 -- sh /vault/data/vault-restore.sh
kubectl exec provider-vault-0 -- sh /vault/data/vault-restore.sh

kubectl scale deploy --all --replicas=1
echo "Done! Vaults are being restored."
