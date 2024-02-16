#!/usr/bin/env sh

mapping=$(gcloud compute regions list --format="json(name,zones)" | sed 's/".*zones\//"/' | jq '[.[] | {key:.name, value:.zones} ] | from_entries')
echo "$mapping"
