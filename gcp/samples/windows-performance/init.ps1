Set-StrictMode -Version Latest;
$InformationPreference = "Continue";
$ErrorActionPreference = "Stop";

$configs = @{
    "1" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 4096
    }
    "2" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 8192
    }
    "3" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 16384
    }
    "4" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 32768
    }
    "5" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 65536
    }
    "6" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 131072
    }
    "7" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 262144
    }
    "8" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 524288
    }
    "9" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 1048576
    }
    "10" = @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 2097152
    }
    "11" = @{
        "fileSystem" = "ReFS"
        "allocationUnitSize" = 4096
    }
    "12" = @{
        "fileSystem" = "ReFS"
        "allocationUnitSize" = 65536
    }
}

$disks = Get-PhysicalDisk -CanPool $true | Sort-Object {[int]$_.DeviceId};
foreach($disk in $disks)
{
    Clear-Disk -UniqueId $disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";

    $config = $configs[$disk.DeviceId];
    if($null -ne $config) {
        $fileSystem = $config["fileSystem"];
        $allocationUnitSize = $config["allocationUnitSize"];
        $label = "${fileSystem}-$($allocationUnitSize / 1024)K";

        Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize |
            Format-Volume -AllocationUnitSize $allocationUnitSize -FileSystem $fileSystem -NewFileSystemLabel $label;
    }
}
