# VM Manager / OS patch management: Take a snapshot before patching #
[VM Manager](https://cloud.google.com/compute/docs/vm-manager) is a suite of tools to manage operating systems (both Linux and Windows) running on Google Compute Engine at scale. One service of VM Manager is [OS patch management](https://cloud.google.com/compute/docs/os-patch-management) for applying patches on-demand and on a schedule. The service takes care of patch orchestration and interfacing with the package repository (Linux) or update subsystem (Windows).

The OS patch management service can run pre and post scripts to make sure that any workloads running on the VMs under management are in a consistent state. This feature can be used to allow the VM to take a snapshot of attached disks when patching commences. 

This sample shows scripts that can be used for both Linux and Windows workloads. The sample scripts identify the ID of the patch job and create a snapshot of all attached disks. Additionally on Windows the VSS interface will be used to ensure that all VSS enabled services write out their data before the snapshot is being taken.

## Prerequisites ##
Follow the instructions ["Setting up VM Manager"](https://cloud.google.com/compute/docs/manage-os) to enable VM Manager for your project. 

You need to upload the scripts to a Google Cloud Storage bucket and get the correct version of the respective script.

## Examples ##
These are command samples to start an on-demand patch job for both Linux and Windows. 

### Linux on-demand patch job ###
```
gcloud compute os-config patch-jobs execute \
    --display-name=snapshot \
    --instance-filter-all \
    --reboot-config=default \
    --windows-classifications=critical,security \
    --pre-patch-windows-executable=gs://<BUCKET>/snapshot-windows.ps1#<VERSION> \
    --async
```

### Windows on-demand patch job ###
```
gcloud compute os-config patch-jobs execute \
    --display-name=snapshot \
    --instance-filter-all \
    --reboot-config=default \
    --pre-patch-linux-executable=gs://<BUCKET>/snapshot-linux.sh#<VERSION> \
    --async
```
