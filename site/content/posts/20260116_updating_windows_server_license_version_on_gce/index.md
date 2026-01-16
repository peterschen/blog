---
title: Updating Windows Server license version on GCE
url: /updating_windows_server_license_version_on_gce
date: 2026-01-16 14:00:00+02:00
tags: ["gcp", "gce", "windows", "licensing"]
---

When deploying a VM running certain operating systems such as Windows Server, a license is added to the boot disk of that instance. This license is used for billing PAYG licensing.

While the cost for a Windows Server license is the same irrespective of the version, you may be inclined to want to update the associated license in order to reflect the correct version being billed.

Through recent upgrades, licenses are now mutable (within limits). This allows to upgrade licenses and ensure that the right version of the license is assigned to a particular VM.

# Scenario

Imagine that you have a VM that is running Windows Server 2022 and you are upgrading to Windows Server 2025. You want the GCE license to reflect the same. There are a few steps that you need to go through.

# Assigning a new license

The new license can either be appended or the existing license can be replaced. 

{{< alert icon="triangle-exclamation" >}}
When appending a license, make sure to remove the old license. You will be charged for each Windows Server license attached to the disk.
{{< /alert >}}

## Appending the license

The following snippet will append the Windows Server 2025 license to an existing disk `double-whammy`:

```shell
DISK=double-whammy
ZONE=europe-west4-a

gcloud compute disks update $DISK \
    --zone $ZONE \
    --append-licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022-dc
```

This is what the disk looks like now:

{{< figure 
    src="images/append.png"
    alt="License appended to the disk"
    catpion="License appended to the disk" >}}

When appending the license it is important to remove the old licese. As noted above if that is not done, all licenses will be charged leading to unecessary cost.

### Removing the old license

The following command will remove the old license.

```shell
DISK=double-whammy
ZONE=europe-west4-a

gcloud compute disks update $DISK \
    --zone $ZONE \
    --remove-licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022-dc
```

{{< alert icon="circle-info" >}}
While older licenses can be removed, the newest license assigned to the disk, for which no license that superseeds it is assigned to the disk can't be removed. 
{{< /alert >}}

## Replacing the licese

Instead of appending the new and removing the old license. The license can also be straight up replaced in a single operation.

```shell
DISK=double-whammy
ZONE=europe-west4-a

gcloud compute disks update $DISK \
    --zone $ZONE \
    --replace-license https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022-dc,https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-dc
```

This will update the license with the new one in a single operation:

{{< figure 
    src="featured.png"
    alt="Replace license assigned to the disk"
    catpion="Replace license assigned to the disk" >}}
