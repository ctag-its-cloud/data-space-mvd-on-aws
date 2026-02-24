#!/bin/bash

#
#  Copyright (c) 2024 Metaform Systems, Inc.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  SPDX-License-Identifier: Apache-2.0
#
#  Contributors:
#       Metaform Systems, Inc. - initial API and implementation
#
#

## This script must be executed when running the dataspace from IntelliJ. Neglecting to do that will render the connectors
## inoperable!

## Seed application DATA to both connectors
echo
echo
echo "Seed data to 'avanza' and 'ctag'"
for url in 'https://NLB_ADDRESS/ctag/cp' 'https://NLB_ADDRESS/avanza/cp'
do
  newman run \
    --folder "Seed" \
    --env-var "HOST=$url" \
    ./deployment/postman/MVD.postman_collection.json \
   --insecure
done

## Seed linked assets to Catalog Server
echo
echo
echo "Create linked assets on the Catalog Server"
newman run \
  --folder "Seed Catalog Server" \
  --env-var "HOST=https://NLB_ADDRESS/provider-catalog-server/cp" \
  --env-var "PROVIDER_QNA_DSP_URL=http://avanza-controlplane:8082" \
  --env-var "PROVIDER_MF_DSP_URL=http://ctag-controlplane:8082" \
  ./deployment/postman/MVD.postman_collection.json \
  --insecure

## Seed management DATA to identityhubsl
API_KEY="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="

# add ita participant
echo
echo
echo "Create ita participant context in IdentityHub"
ITA_CONTROLPLANE_SERVICE_URL="http://ita-controlplane:8082"
ITA_IDENTITYHUB_URL="http://ita-identityhub:7082"
DATA_ITA=$(jq -n --arg url "$ITA_CONTROLPLANE_SERVICE_URL" --arg ihurl "$ITA_IDENTITYHUB_URL" '{
           "roles":[],
           "serviceEndpoints":[
             {
                "type": "CredentialService",
                "serviceEndpoint": "\($ihurl)/api/credentials/v1/participants/ZGlkOndlYjpjb25zdW1lci1pZGVudGl0eWh1YiUzQTcwODM6Y29uc3VtZXI=",
                "id": "ita-credentialservice-1"
             },
             {
                "type": "ProtocolEndpoint",
                "serviceEndpoint": "\($url)/api/dsp",
                "id": "ita-dsp"
             }
           ],
           "active": true,
           "participantId": "did:web:ita-identityhub%3A7083:ita",
           "did": "did:web:ita-identityhub%3A7083:ita",
           "key":{
               "keyId": "did:web:ita-identityhub%3A7083:ita#key-1",
               "privateKeyAlias": "did:web:ita-identityhub%3A7083:ita#key-1",
               "keyGeneratorParams":{
                  "algorithm": "EC"
               }
           }
       }')

curl -k --location "https://NLB_ADDRESS/ita/cs/api/identity/v1alpha/participants/" \
--header 'Content-Type: application/json' \
--header "x-api-key: $API_KEY" \
--data "$DATA_ITA"


# add provider participant
echo
echo
echo "Create provider participant context in IdentityHub"

PROVIDER_CONTROLPLANE_SERVICE_URL="http://provider-catalog-server-controlplane:8082"
PROVIDER_IDENTITYHUB_URL="http://provider-identityhub:7082"

DATA_PROVIDER=$(jq -n --arg url "$PROVIDER_CONTROLPLANE_SERVICE_URL" --arg ihurl "$PROVIDER_IDENTITYHUB_URL" '{
           "roles":[],
           "serviceEndpoints":[
             {
                "type": "CredentialService",
                "serviceEndpoint": "\($ihurl)/api/credentials/v1/participants/ZGlkOndlYjpwcm92aWRlci1pZGVudGl0eWh1YiUzQTcwODM6cHJvdmlkZXI=",
                "id": "provider-credentialservice-1"
             },
             {
                "type": "ProtocolEndpoint",
                "serviceEndpoint": "\($url)/api/dsp",
                "id": "provider-dsp"
             }
           ],
           "active": true,
           "participantId": "did:web:provider-identityhub%3A7083:provider",
           "did": "did:web:provider-identityhub%3A7083:provider",
           "key":{
               "keyId": "did:web:provider-identityhub%3A7083:provider#key-1",
               "privateKeyAlias": "did:web:provider-identityhub%3A7083:provider#key-1",
               "keyGeneratorParams":{
                  "algorithm": "EC"
               }
           }
       }')

curl -k --location "https://NLB_ADDRESS/provider/cs/api/identity/v1alpha/participants/" \
--header 'Content-Type: application/json' \
--header "x-api-key: $API_KEY" \
--data "$DATA_PROVIDER"

###############################################
# SEED ISSUER SERVICE
###############################################

echo
echo
echo "Create dataspace issuer"
DATA_ISSUER=$(jq -n --arg pem "$PEM_ISSUER" '{
            "roles":["admin"],
            "serviceEndpoints":[
              {
                 "type": "IssuerService",
                 "serviceEndpoint": "http://dataspace-issuer-service:10012/api/issuance/v1alpha/participants/ZGlkOndlYjpkYXRhc3BhY2UtaXNzdWVyLXNlcnZpY2UlM0ExMDAxNjppc3N1ZXI=",
                 "id": "issuer-service-1"
              }
            ],
            "active": true,
            "participantId": "did:web:dataspace-issuer-service%3A10016:issuer",
            "did": "did:web:dataspace-issuer-service%3A10016:issuer",
            "key":{
                "keyId": "did:web:dataspace-issuer-service%3A10016:issuer#key-1",
                "privateKeyAlias": "key-1",
                "keyGeneratorParams":{
                  "algorithm": "EdDSA"
                }
            }
      }')

curl -k -s --location 'https://NLB_ADDRESS/issuer/cs/api/identity/v1alpha/participants/' \
--header 'Content-Type: application/json' \
--data "$DATA_ISSUER"

## Seed participant data to the issuer service
newman run \
  --folder "Seed Issuer SQL" \
  --env-var "ISSUER_ADMIN_URL=https://NLB_ADDRESS/issuer/ad" \
  --env-var "ITA_ID=did:web:ita-identityhub%3A7083:ita" \
  --env-var "ITA_NAME=MVD Ita Participant" \
  --env-var "PROVIDER_ID=did:web:provider-identityhub%3A7083:provider" \
  --env-var "PROVIDER_NAME=MVD Provider Participant" \
  ./deployment/postman/MVD.postman_collection.json \
  --insecure