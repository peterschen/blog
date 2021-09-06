#!/usr/bin/env sh

# Config
gcloud config set compute/region europe-west4
gcloud config set compute/zone europe-west4-a

# Create node template
gcloud compute sole-tenancy node-templates create prod --node-type=n1-node-96-624 --node-affinity-labels environment=prod

# Create node group
gcloud compute sole-tenancy node-groups create prod --node-template=prod --target-size=3 --maintenance-policy=migrate-within-node-group

# Create smaller VMs
for number in 01 02 03 04 05 06 07 08 09 10 11 12; do
    gcloud compute instances create small-vm-$number --machine-type=n1-highmem-16 --network-interface=subnet=europe-west4,no-address --node-affinity-file affinity.json --enable-display-device --image=debian-11-bullseye-v20210817 --image-project=debian-cloud --boot-disk-size=10GB --boot-disk-type=pd-balanced --boot-disk-device-name=small-vm-$number --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring
done

# Create some holes by deleting some VMs
for number in 01 02 03 10 11 12; do
    gcloud compute instances delete small-vm-$number --quiet
done

# Pause VMs
for number in 07 08 09; do
    gcloud beta compute instances suspend small-vm-$number
done

# Resume VMs
for number in 07 08 09; do
    gcloud beta compute instances resume small-vm-$number
done

# Delete remaining VMs
for number in 04 05 06 07 08 09; do
    gcloud compute instances delete small-vm-$number --quiet
done

# Delete node group
gcloud compute sole-tenancy node-groups delete prod --quiet

# Delete node template
gcloud compute sole-tenancy node-templates delete prod --quiet
