---
author: christoph
title: Deny permissions on resources using tags and IAM deny rules
url: /deny-resources-using-tags
date: 2024-01-25T14:46:09.000Z
tags: [gcp, iam, tags]
cover:
draft: true
---

* Prevent disks from using unvalidated sources
* Protect snapshots against accidental deletion

## Scenario

Our ficticous customer wants to prevent internal functions to create virtual machines that use disks that may contain unvalidated software, or require licenses that have usage contrainst (e.g. Microsoft Windows Server). 

## Prerequisites

* Project
* VPN & subnet

## Create tag and tag value



## Create tagged disk

```sh
project_id="<PROJECT ID>"
zone="<ZONE>"
tag_key_id="<TAG_KEY_ID>"
tag_value_id="<TAG_VALUE_ID>"

gcloud compute disks create disk-with-tag --project=$project_id --zone=$zone

gcloud resource-manager tag-binding 
```

## Create deny policy

```sh
project_id="<PROJECT ID>"
zone="<ZONE>"
tag_key_id="<TAG_KEY_ID>"
tag_value_id="<TAG_VALUE_ID>"

gcloud compute disks create disk-with-tag --project=$project_id --zone=$zone

gcloud resource-manager tag-binding 
```

This sample uses resource tags and IAM deny policy to prevent untagged disks from being created. This technique can be used to control which disk sources can be used for VMs and manage compliance for certain use-cases like Microsoft licensing.
