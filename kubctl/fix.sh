#!/bin/bash

aws eks update-kubeconfig --region eu-central-1 --name mvd-on-aws
# Set environment variables for all three connectors
echo "Updating environment variables..."
kubectl -n mvd set env deploy/ita-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="/ita/public/api/public"
kubectl -n mvd set env deploy/avanza-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="/avanza/public/api/public"
kubectl -n mvd set env deploy/ctag-dataplane \
  EDC_DATAPLANE_API_PUBLIC_BASEURL="/ctag/public/api/public"
# Restart deployments to apply changes
echo "Restarting deployments..."
kubectl -n mvd rollout restart deploy/ita-dataplane
kubectl -n mvd rollout restart deploy/avanza-dataplane
kubectl -n mvd rollout restart deploy/ctag-dataplane
echo "Done! Connectors are being updated."