#!/bin/bash

# Get hostname from argument or try to fetch it automatically
LB_HOST=$1

if [ -z "$LB_HOST" ]; then
  echo "No hostname provided, attempting to fetch from Kubernetes..."
  LB_HOST=$(kubectl get ingress -n mvd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

if [ -z "$LB_HOST" ]; then
  echo "Error: Could not determine LoadBalancer hostname."
  echo "Usage: ./fix.sh <LOAD_BALANCER_HOSTNAME>"
  exit 1
fi

echo "Using Hostname: $LB_HOST"

# Apply Ingress configurations
kubectl apply -f consumer-dataplane-public-ingress.yaml
kubectl apply -f provider-qna-dataplane-public-ingress.yaml
kubectl apply -f provider-manufacturing-dataplane-public-ingress.yaml

# Set environment variables for all three connectors
echo "Updating environment variables..."

kubectl -n mvd set env deploy/consumer-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="https://${LB_HOST}/consumer-dp/api/public"

kubectl -n mvd set env deploy/provider-qna-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="https://${LB_HOST}/provider-qna-dp/api/public"

kubectl -n mvd set env deploy/provider-manufacturing-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="https://${LB_HOST}/provider-manufacturing-dp/api/public"

# Restart deployments to apply changes
echo "Restarting deployments..."
kubectl -n mvd rollout restart deploy/consumer-dataplane
kubectl -n mvd rollout restart deploy/provider-qna-dataplane
kubectl -n mvd rollout restart deploy/provider-manufacturing-dataplane

echo "Done! Connectors are being updated."