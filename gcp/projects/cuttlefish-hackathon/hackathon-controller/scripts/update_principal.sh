#!/usr/bin/env bash

DOC_ID="${1}"
NICKNAME="${2}"
BASE_URI="${3:-http://localhost:8080}"

if [ -z "$DOC_ID" ] || [ -z "$NICKNAME" ]; then
    echo "Usage: $0 <doc_id> <nickname> [base_uri]"
    echo "Example: $0 my-doc-id-12345 \"Cool Nickname\""
    exit 1
fi

API_URI="$BASE_URI/api/principals/$DOC_ID"

echo "Fetching Google Cloud identity token..."
# Get the OIDC token for the currently authenticated gcloud user
TOKEN=$(gcloud auth print-identity-token)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token. Please try running 'gcloud auth login'."
    exit 1
fi

echo "Sending PATCH request to $API_URI..."

# Make the authenticated PATCH request
curl -X PATCH "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"nickname\": \"$NICKNAME\" }"

echo ""
