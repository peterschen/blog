#!/usr/bin/env bash

set -eu

regions=`gcloud compute regions list --format="value(name)" | sort -u`
types=`gcloud compute sole-tenancy node-types list --sort-by="name" --format="value(name)" --filter="deprecated=''" | uniq`
types_regions=`gcloud compute sole-tenancy node-types list --sort-by="zone,name" --format="value(name,zone)" --filter="deprecated=''" | uniq`

echo -en "Region"
for type in $types; do
    echo -en "\t$type"
done

# Add linebreak
echo ""

for region in $regions; do
    echo -en "$region"

    for type in $types; do
        availability=0
        available_zones=`echo "$types_regions" | grep $type | grep "$region-" | wc -l`

        if [ $available_zones -gt 0 ]; then
            availability=1
        fi

        echo -en "\t$availability"
    done
    
    # Add linebreak
    echo ""    
done
