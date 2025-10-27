---
author: christoph
title: Changing provisioning model for Spot VMs
url: /changing_provisioning_model_for_spot_vms

date: 2025-10-27 13:30:00+02:00
tags: 
- gce
- gcp
- spot
cover: images/cover.png
draft: true
---

Spot VMs is a great way to reduce cost for interruptible, stateless and fault-tolerant workloads like batch processing or containers. Starting these types of VMs follows the same principles as regular VMs. The following snippet launches a C4A Spot VM:

```sh
gcloud compute instances create spotty \
    --machine-type=c4a-standard-1 \
    --create-disk auto-delete=yes,boot=yes,image-project=debian-cloud,image-family=debian-13-arm64,type=hyperdisk-balanced,size=10 \
    --network-interface nic-type=GVNIC,stack-type=IPV4_ONLY,subnet=default,no-address \
    --provisioning-model SPOT \
    --instance-termination-action STOP \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring
```

## Change provisioning model

But what happens if the nature of your workload changes over time? Or you need to ensure that processing is completed within a certain timeframe? How can you change the provisioning model of a VM configured with a preemtible provisioning model? It is actually quiet simple. The scheduling configuration for a VM can be changed using gcloud.

```sh
gcloud compute instances set-scheduling spotty \
    --provisioning-model STANDARD \
    --no-preemptible \
    --clear-instance-termination-action
```

As the `SPOT` provisioning model implies preemptibility and a default termination action both of these attributes on the VM need to be updated when updating the configuration of the VM. 
