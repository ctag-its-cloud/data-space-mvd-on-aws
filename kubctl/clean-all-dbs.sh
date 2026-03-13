#!/bin/bash

# This script completely wipes all tables from all EDC databases 
# (Alice: alice; Bob: bob, qna, manufacturing, identity)
# by dropping and recreating the public schema.
# Use this with caution as it deletes ALL data!

set -e

CY="\033[0;36m"
NC="\033[0m"

echo -e "${CY}Fetching database credentials...${NC}"

# Fetch endpoints and passwords using terraform output
BOB_ENDPOINT=$(terraform output -raw rds-aurora-bob_endpoint 2>/dev/null || echo "mvd-on-aws-bob.cluster-c508iqyeewui.eu-central-1.rds.amazonaws.com")
BOB_PASSWORD=$(terraform output -raw rds-aurora-bob_password 2>/dev/null)

ALICE_ENDPOINT=$(terraform output -raw rds-aurora-alice_endpoint 2>/dev/null)
ALICE_PASSWORD=$(terraform output -raw rds-aurora-alice_password 2>/dev/null)

if [ -z "$BOB_PASSWORD" ] || [ -z "$ALICE_PASSWORD" ]; then
    echo "Error: Could not fetch database passwords. Please ensure you are in the project root."
    exit 1
fi

# SQL to wipe all tables by dropping the public schema
WIPE_SQL="DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;"

function wipe_db() {
    local host=$1
    local pwd=$2
    local db=$3
    local name=$4

    echo -e "${CY}Wiping $name database ($db) at $host...${NC}"
    
    kubectl run db-wipe-$(date +%s) --image=postgres:17.7 --restart=Never --rm -it --env="PGPASSWORD=$pwd" -- \
        psql -h "$host" -U postgres -d "$db" -c "$WIPE_SQL"
}

# 1. Wipe Bob's Databases
for db in "bob" "qna" "manufacturing" "identity"; do
    wipe_db "$BOB_ENDPOINT" "$BOB_PASSWORD" "$db" "Provider ($db)"
done

# 2. Wipe Alice's Database
wipe_db "$ALICE_ENDPOINT" "$ALICE_PASSWORD" "alice" "Consumer (alice)"

echo -e "${CY}Restarting all EDC components to recreate schemas...${NC}"

# Restart all deployments in the mvd namespace
kubectl -n mvd rollout restart deploy/ita-controlplane
kubectl -n mvd rollout restart deploy/avanza-controlplane
kubectl -n mvd rollout restart deploy/ctag-controlplane
kubectl -n mvd rollout restart deploy/provider-catalog-server-controlplane
kubectl -n mvd rollout restart deploy/consumer-identityhub
kubectl -n mvd rollout restart deploy/provider-identityhub
kubectl -n mvd rollout restart deploy/provider-vault
kubectl -n mvd rollout restart deploy/consumer-vault

echo -e "${CY}All databases wiped and components restarted.${NC}"
echo -e "${CY}Wait for pods to be ready, then run seeding script:${NC}"
echo -e "cd MinimumViableDataspace/ && ./seed-k8s.sh"
