#!/usr/bin/env bash

. ./common.sh

DOC_ID="${1}"
STAGE="${2}"
SERVICE_ACCOUNT="${3}"
BASE_URI="${4:-http://localhost:8080}"
API_URI="$BASE_URI/api/principals/$DOC_ID/progress"

if [ -z "$DOC_ID" ] || [ -z "$STAGE" ]; then
    echo "Usage: $0 <doc_id> <stage> <service account> [base_uri]"
    echo "Example: $0 my-doc-id-12345 service@account.name 1"
    exit 1
fi

TOKEN=$(sign_jwt $SERVICE_ACCOUNT $API_URI)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token."
    exit 1
fi

echo "Sending POST request to $API_URI..."
curl -X POST "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"stage\": $STAGE }"

echo ""
