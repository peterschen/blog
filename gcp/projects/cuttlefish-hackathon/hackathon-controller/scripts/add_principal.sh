#!/usr/bin/env bash

. ./common.sh

PROJECT="${1}"
NICKNAME="${2}"
SERVICE_ACCOUNT="${3}"
BASE_URI="${4:-http://localhost:8080}"
API_URI="$BASE_URI/api/principals"

if [ -z "$PROJECT" ] || [ -z "$NICKNAME" ]; then
    echo "Usage: $0 <project> <nickname> <service account> [base_uri]"
    echo "Example: $0 my-project-id service@account.com \"Cool Nickname\" service@account.name"
    exit 1
fi

TOKEN=$(sign_jwt $SERVICE_ACCOUNT $API_URI)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token."
    exit 1
fi

# Prepare JSON payload
if [ -n "$NICKNAME" ]; then
    JSON_DATA="{ \"project\": \"$PROJECT\", \"nickname\": \"$NICKNAME\" }"
else
    JSON_DATA="{ \"project\": \"$PROJECT\" }"
fi

# Make the authenticated POST request
echo "Sending POST request to $API_URI..."
curl -X POST "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_DATA"

echo ""
