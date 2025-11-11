---
title: Changing licensing from BYOL to PAYG for Windows Server on Google Compute Engine
url: /changing_licensing_from_byol_to_payg_for_windows_server_on_google_compute_engine
date: '2025-11-11T10:39:06Z'
---

Customers moving Windows Server workload to the cloud often leverage bring your own license (BYOL) to optimize licensing cost. At some point customers may decide to change the licensing model. Reasons could be restrictive licensing terms constraining which versions can be deployed or optimizations such as reducing the amount time a VM and by extension the licese is running per month, for which a permanently assigned license is not the ideal choice.

When a customer decides to switch from BYOL to pay-as-you-go (PAYG) Google Cloud needs to be told that not only the infrastructure but also the cost for the Windows Server license should be charged. A new feature that [allows to manage licenses](https://docs.cloud.google.com/compute/docs/licenses/manage) for Google Compute Engine (GCE) helps with the transition. 

## A license in GCE

A license in the context of GCE is an Google Cloud specific mechanism to identify sofware that is installed on a VM and make sure that all the commercial aspects (and in some cases technical) are covered. These licenses are governed by constraints like whether they can be appended or removed to disks, whether they are transferable or whether they can only be deployed on certain compute options like sole-tenant nodes.

## Windows Server licenses in GCE

Google Cloud publishes a distinct license for each version of Windows Server both for BYOL and PAYG. They can be found in [the documentation](https://docs.cloud.google.com/compute/docs/images/os-details#license-strings):

{{< figure 
    src="images/windows_licenses.png"
    alt="Windows Server licenses for GCE"
    caption="Windows Server licenses for GCE" >}}

Alternatively, they can also be queried by issuing a REST request against the Compute API (this API currently not exposed through gcloud). Filtering for Windows Server 2025 in this example:

```sh
baseUri="https://compute.googleapis.com/compute/v1/projects"
token=`gcloud auth print-access-token`
project="windows-cloud"
filter=`echo "name = windows-server-2025*" | jq -Rr @uri`
curl -s \
    "${baseUri}/${project}/global/licenses?filter=${filter}" \
    --header "Authorization: Bearer ${token}" \
    --header "Accept: application/json" \
    --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.selfLink)"' | column -s' ' -t -N Name,Code,Uri
```

## Attach a Windows Server license

The only step required to move from BYOL to PAYG is to attach the respective license to the boot disk of the VM. This operation is exposed through gcloud and just takes the additional license as a parameter. 

{{< alert icon="circle-info" >}}
If the disk is attached to a VM it has to be turned off for the attach operation.
{{< /alert >}}

```sh
disk=blog
zone=europe-west4-a
gcloud compute disks update $disk \
    --zone $zone \
    --append-licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-dc
```

Once the disk you can see all attached licenses using gcloud:

```sh
disk=blog
zone=europe-west4-a
gcloud compute disks describe $disk \
    --zone $zone \
    --format json | jq '.licenses'
```

{{< figure 
    src="images/attached_licenses.png"
    alt="Licenses attached to the disk"
    catpion="Licenses attached to the disk" >}}