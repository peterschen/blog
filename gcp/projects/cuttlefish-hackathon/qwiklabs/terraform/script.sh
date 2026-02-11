#!/usr/bin/env bash

PROJECT_ID=$1
BASE_URI=$2

TOKEN=$(gcloud auth print-identity-token)
JSON_DATA="{ \"project\": \"$PROJECT_ID\" }"

curl -X POST "$BASE_URI/api/principals" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_DATA"
