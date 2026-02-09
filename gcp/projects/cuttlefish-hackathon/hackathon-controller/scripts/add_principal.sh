#!/usr/bin/env bash

PROJECT="${1}"
NICKNAME="${2}"
BASE_URI="${3:-http://localhost:8080}"

if [ -z "$PROJECT" ] || [ -z "$NICKNAME" ]; then
    echo "Usage: $0 <project> <nickname> [base_uri]"
    echo "Example: $0 my-project-id \"Cool Nickname\""
    exit 1
fi

API_URI="$BASE_URI/api/principals"

echo "Fetching Google Cloud identity token..."
# Get the OIDC token for the currently authenticated gcloud user
TOKEN=$(gcloud auth print-identity-token)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token. Please try running 'gcloud auth login'."
    exit 1
fi

echo "Sending POST request to $API_URI..."

# Prepare JSON payload
if [ -n "$NICKNAME" ]; then
    JSON_DATA="{ \"project\": \"$PROJECT\", \"nickname\": \"$NICKNAME\" }"
else
    JSON_DATA="{ \"project\": \"$PROJECT\" }"
fi

# Make the authenticated POST request
curl -X POST "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_DATA"

echo ""
