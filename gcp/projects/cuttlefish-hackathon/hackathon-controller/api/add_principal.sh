#!/usr/bin/env bash

# Default URL for the API. It can be overridden by passing an argument to the script.
BASE_URI="${1:-http://localhost:8080}"
API_URI="$BASE_URI/api/principals"

PROJECT="${2:-local}"

echo "Fetching Google Cloud identity token..."
# Get the OIDC token for the currently authenticated gcloud user
TOKEN=$(gcloud auth print-identity-token)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain identity token. Please try running 'gcloud auth login'."
    exit 1
fi

echo "Sending POST request to $API_URI..."

# Make the authenticated POST request
curl -X POST "$API_URI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{ \"project\": \"$PROJECT\" }"

echo ""
