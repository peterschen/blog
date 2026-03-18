#!/usr/bin/env bash

. ./common.sh

DOC_ID="${1}"
NICKNAME="${2}"
SERVICE_ACCOUNT="${3}"
BASE_URI="${4:-http://localhost:8080}"
API_URI="$BASE_URI/api/principals/$DOC_ID"

if [ -z "$DOC_ID" ] || [ -z "$NICKNAME" ]; then
    echo "Usage: $0 <doc_id> <nickname> <service account> [base_uri]"
    echo "Example: $0 my-doc-id-12345 \"Cool Nickname\" service@account.name"
    exit 1
fi

TOKEN=$(sign_jwt $SERVICE_ACCOUNT $API_URI)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token."
    exit 1
fi

echo "Sending PATCH request to $API_URI..."
curl -X PATCH "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"nickname\": \"$NICKNAME\" }"

echo ""
