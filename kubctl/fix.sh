#!/bin/bash

# Check if base URL is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <base-url>"
  echo "Example: $0 https://test.ctag-edmus.com"
  exit 1
fi

BASE_URL=${1%/}

aws eks update-kubeconfig --region eu-central-1 --name mvd-on-aws

# Set environment variables for all three connectors
echo "Updating environment variables with base URL: $BASE_URL"
kubectl -n mvd set env deploy/ita-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ita/public/api/public"
kubectl -n mvd set env deploy/avanza-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/avanza/public/api/public"
kubectl -n mvd set env deploy/ctag-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="$BASE_URL/ctag/public/api/public"

# Restart deployments to apply changes
echo "Restarting deployments..."
kubectl -n mvd rollout restart deploy/ita-dataplane
kubectl -n mvd rollout restart deploy/avanza-dataplane
kubectl -n mvd rollout restart deploy/ctag-dataplane

echo "Done! Connectors are being updated."