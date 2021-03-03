[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [bool] $InitializeDisks = $true
)

Set-StrictMode -Version Latest;
$InformationPreference = "Continue";
$ErrorActionPreference = "Stop";

<#
    .SYNOPSIS
        This function calls the diskspd binary

    .PARAMETER Arguments
        Array of arguments to be passed to diskspd

    .OUTPUTS
        PSCustomObject {StandardOutput, StandardError, ExitCode}

    .EXAMPLE
        Invoke-Diskspd -Arguments @("compute", "instances", "list");
#>
function Invoke-Diskspd
{
    param
    (
        [string[]] $Arguments
    );

    process
    {
        $info = New-Object System.Diagnostics.ProcessStartInfo;
        $info.FileName = "cmd.exe";
        $info.RedirectStandardError = $true;
        $info.RedirectStandardOutput = $true;
        $info.UseShellExecute = $false;
        $info.LoadUserProfile = $true;
        $info.Arguments = "/C c:\tools\diskspd\amd64\diskspd.exe $($Arguments -join " ")";

        $process = New-Object System.Diagnostics.Process;
        $process.StartInfo = $info;
        $process.Start() | Out-Null;

        [PSCustomObject] @{
            StandardOutput = $process.StandardOutput.ReadToEnd()
            StandardError = $process.StandardError.ReadToEnd()
            ExitCode = $process.ExitCode
        };

        $process.WaitForExit();
    }
}

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

$scenarios = @{
    "fileserver" = @{
        "ratio" = 20
        "blockSizeValue" = 64
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 32
        "enableSoftwarCache" = $false
        "enableWriteTrough" = $true
    }
}

$outputFolder = "c:\tools";
$fileSizeValue = "10";
$fileSizeUnit = "G";
$duration = 60;
$threads = 1;
$warmup = 5;
$cooldown = 0;
$enableLatencyCollection = $false;

$disks = Get-PhysicalDisk -CanPool $true | Sort-Object {[int]$_.DeviceId};

if($InitializeDisks)
{
    foreach($disk in $disks)
    {
        Clear-Disk -UniqueId $disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
    
        $config = $configs[$disk.DeviceId];
        if($null -ne $config) {
            $fileSystem = $config["fileSystem"];
            $allocationUnitSize = $config["allocationUnitSize"];
            $label = "${fileSystem}-$($allocationUnitSize / 1024)K";

            Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle GPT -PassThru |
                New-Partition -UseMaximumSize -DriveLetter $([char](99 + $disk.DeviceId)) |
                Format-Volume -AllocationUnitSize $allocationUnitSize -FileSystem $fileSystem -NewFileSystemLabel $label;
        }
    }
}

foreach($scenario in $scenarios.GetEnumerator())
{
    Write-Information -MessageData "Starting scenario '$($scenario.Name)'";
    $config = $scenario.Value;

    $flags = "";

    if(-not $config["enableSoftwareCache"])
    {
        $flags += "-Su "
    }

    if($config["enableWriteThrough"])
    {
        $flags += "-Sw "
    }

    if($enableLatencyCollection)
    {
        $flags += "-L "
    }

    $arguments = @(
        "-c${fileSizeValue}${fileSizeUnit}",
        "-b$($config["blockSizeValue"])$($config["blockSizeUnit"])"
        "-d$duration"
        "-t$threads",
        "-W$warmup",
        "-C$cooldown",
        "-Rxml",
        "-w$($config["ratio"])",
        "-f$($config["accessHint"])",
        "-$($config["accessPattern"])",
        "-o$($config["outstandingIo"])",
        "-D",
        $flags
    );

    foreach($disk in $disks)
    {
        Write-Information -MessageData "Running diskspd for disk '$($disk.DeviceId)'";

        $instanceArguments = $arguments;
        $instanceArguments += @(
            "$([char](99 + $disk.DeviceId)):\diskspd.bin"
        );

        $process = Invoke-Diskspd -Arguments $instanceArguments;
        Set-Content -Path "${outputFolder}\diskspd-$($scenario.Name)-$($disk.DeviceId).xml" -Value $process.StandardOutput;

        Write-Information -MessageData "Cooling down for ${duration} seconds";
        Start-Sleep -Seconds $duration;
    }
}
