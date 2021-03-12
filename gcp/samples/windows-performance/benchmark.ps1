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

<#
    .SYNOPSIS
        This function initializes the disk

    .PARAMETER Disk
        MSFT_PhysicalDisk $Disk

    .PARAMETER Configuration
        Hashtable of parameters for disk initialization

    .OUTPUTS
        Boolean

    .EXAMPLE
        Setup-Disk -Configuration @{"fileSystem" = "NTFS" "allocationUnitSize" = 4096}
#>
function Setup-Disk
{
    param
    (
        [CimInstance] $Disk,
        [Hashtable] $Configuration,
        [String] $DriveLetter
    );

    process
    {
        Clear-Disk -UniqueId $Disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
    
        $fileSystem = $Configuration["fileSystem"];
        $allocationUnitSize = $Configuration["allocationUnitSize"];
        $label = "${fileSystem}-$($allocationUnitSize / 1024)K";

        Initialize-Disk -UniqueId $Disk.UniqueId -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize -DriveLetter $DriveLetter |
            Format-Volume -AllocationUnitSize $allocationUnitSize -FileSystem $fileSystem -NewFileSystemLabel $label |
            Out-Null;
    }
}

$scenarios = @{
    "write_throughput" = @{
        "ratio" = 100
        "blockSizeValue" = 1
        "blockSizeUnit" = 'M'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 64
        "enableSoftwarCache" = $false
        "enableWriteTrough" = $true
        "threads" = 8
    }
    "write_iops" = @{
        "ratio" = 100
        "blockSizeValue" = 4
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 64
        "enableSoftwarCache" = $false
        "enableWriteTrough" = $true
        "threads" = 1
    }
}

$configurations = @(
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 4096
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 8192
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 16384
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 32768
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 65536
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 131072
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 262144
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 524288
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 1048576
    },
    @{
        "fileSystem" = "NTFS"
        "allocationUnitSize" = 2097152
    },
    @{
        "fileSystem" = "ReFS"
        "allocationUnitSize" = 4096
    },
    @{
        "fileSystem" = "ReFS"
        "allocationUnitSize" = 65536
    }
);

$driveLetter = "t";
$outputFolder = "c:\tools";
$fileSizeValue = "10";
$fileSizeUnit = "G";
$duration = 60;
$warmup = 5;
$cooldown = 0;
$enableLatencyCollection = $false;

$disk = Get-PhysicalDisk | Where-Object { $_.Size -eq 100GB };
foreach($configuration in $configurations)
{
    Write-Information -MessageData "Preparing disk '$($configuration["fileSystem"])-$($configuration["allocationUnitSize"])'";
    Setup-Disk -Disk $disk -Configuration $configuration -DriveLetter $driveLetter;

    foreach($scenario in $scenarios.GetEnumerator())
    {
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
            "-t$($config["threads"])",
            "-W$warmup",
            "-C$cooldown",
            "-Rxml",
            "-w$($config["ratio"])",
            "-f$($config["accessHint"])",
            "-$($config["accessPattern"])",
            "-o$($config["outstandingIo"])",
            "-D",
            $flags,
            "${driveLetter}:\diskspd.bin"
        );

        Write-Information -MessageData "Running scenario '$($scenario.Name)'";

        $process = Invoke-Diskspd -Arguments $arguments;
        Set-Content -Path "${outputFolder}\diskspd-$($scenario.Name)-$($configuration["fileSystem"])-$($configuration["allocationUnitSize"]).xml" `
            -Value $process.StandardOutput;

        Write-Information -MessageData "Cooling down for ${duration} seconds";
        Start-Sleep -Seconds $duration;
    }
}
