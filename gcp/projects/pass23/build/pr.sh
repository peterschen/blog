#!/usr/bin/env sh
set +eux

# Generate manifest for deployment
envsubst < data/pr-inline.yml > /workspace/pr-inline.yml
