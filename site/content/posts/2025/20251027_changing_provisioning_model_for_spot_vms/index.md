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

But what happens if the nature of your workload changes over time? Or you need to ensure that processing is completed within a certain timeframe? How can you change the provisioning model of a VM configured with a preemtible provisioning model? It is actually quiet simple (once you know how).

You may have started looking at the options to change the VM configuration using Cloud Console but unfortunately it won't let you change the provisioning model, even claiming it is not possible to do so:

![Chaning the provisioning model of a VM in Cloud Console](images/provisioning_model.png)

## Changing the provisioning model using `gcloud`

Fortunately, `gcloud` paired with the right options is able to change the schedulung configuration of a VM. The only requirement is that the VM is turned off when executing the command. 

```sh
gcloud compute instances set-scheduling spotty \
    --provisioning-model STANDARD \
    --maintenance-policy=MIGRATE \
    --no-preemptible \
    --clear-instance-termination-action
```

As the `SPOT` provisioning model implies preemptibility and a default termination action both of these attributes on the VM need to be updated when updating the configuration of the VM. 
