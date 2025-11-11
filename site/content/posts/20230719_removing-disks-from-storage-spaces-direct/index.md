---
title: Removing (unclaiming) disks from Storage Spaces Direct (S2D)
url: /removing-disks-from-storage-spaces-direct
date: 2023-07-19T10:14:46.000Z
tags: [storage, windows-server, storage-spaces-direct, s2d]
---

When running Storage Spaces Direct in Cloud environments where disk resources can be provisioned at a moments notice with any capacity, it can be the norm that disks will be (hot) added from a cluster to account for growing capacity or performance needs.

By default, disks added to cluster nodes will automatically claimed by Storage Spaces Direct. You can prevent the disks to be automatically added to storage pools by setting the following option to the cluster:

```powershell
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting -Name "System.Storage.PhysicalDisk.AutoPool.Enabled" -Value False;
```

Additionally, you can also prevent Storage Spaces Direct from using spare drives to be automatically used for replacing failed drives in the cluster:

```powershell
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting -name "System.Storage.PhysicalDisk.AutoReplace.Enabled" -value False;
```

Yet, even when setting these options, disks will be claimed by Storage Spaces Direct and associated with the *Primordial* storage pool for later use. In the next section I'll explain, how these disks can be unclaimed from Storage Spaces Direct so that they can be used locally on the respective node. 

## Unclaim disks from Storage Spaces Direct

The following steps illustrate how to unclaim the disks from Storage Spaces Direct. Make sure to ammend the commands to your environment (e.g. make sure to only select the disk you want to remove from S2D).

### 1. Identify the disks you'd want to unclaim

Select one or more disks that you want to remove from S2D.

```powershell
# Get disk(s) by pooling status
$disks = Get-PhysicalDisk -CanPool $true;

# Get disks by their ID
$ids = ("694EB2C074657374860A1ABAA3206920", "694EB2C074657374500B1ABA619B184D");
```

### 2. Remove the disks from the Primordial pool

Unclaim the disks.

```powershell
Set-ClusterStorageSpacesDirectDisk -CanBeClaimed $false -PhysicalDisk $disks;
```

### 3. Set the disks to online

Once unclaimed, the disks are offlined locally. To make them availbale on the cluster node, they need to be set to online.

```powershell
Get-Disk | ? { $_.UniqueId -in ($disks).UniqueId } | Set-Disk -IsOffline $false;
```
