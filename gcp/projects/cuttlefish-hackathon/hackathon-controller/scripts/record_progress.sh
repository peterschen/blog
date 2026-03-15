#!/usr/bin/env bash

DOC_ID="${1}"
STAGE="${2}"
BASE_URI="${3:-http://localhost:8080}"

if [ -z "$DOC_ID" ] || [ -z "$STAGE" ]; then
    echo "Usage: $0 <doc_id> <stage> [base_uri]"
    echo "Example: $0 my-doc-id-12345 1"
    exit 1
fi

API_URI="$BASE_URI/api/principals/$DOC_ID/progress"

echo "Fetching Google Cloud identity token..."
# Get the OIDC token for the currently authenticated gcloud user
TOKEN=$(gcloud auth print-identity-token)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token. Please try running 'gcloud auth login'."
    exit 1
fi

echo "Sending POST request to $API_URI..."

# Make the authenticated PATCH request
curl -X POST "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"stage\": \"$STAGE\" }"

echo ""
