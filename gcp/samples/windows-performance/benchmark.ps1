[CmdletBinding()]
param
(
    [bool] $SkipBenchmark = $false,
    [bool] $SkipAnalysis = $false
);

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

<#
    .SYNOPSIS
        Start benchmark run

    .PARAMETER Scenarios
        Hashtable of disk test scenarios

    .PARAMETER Configuration
        Array of parameters for disk initialization

    .PARAMETER DriveLetter
        Letter to assign to drive under test

    .PARAMETER OutputFolder
        Path to folder to store test results

    .PARAMETER FileSize
        Size of test file

    .PARAMETER Duration
        Duration of test in seconds

    .PARAMETER Warmup
        Warum-up time in seconds (passed to diskspd)

    .PARAMETER Cooldown
        Cooldown time in seconds (passed to diskspd)

    .PARAMETER EnableLatencyCollection
        Whether latency collection is enabled or not

    .EXAMPLE
        Invoke-Benchmark `
            -Scenarios @{"write_throughput" = @{"ratio" = 100 "blockSizeValue" = 1 "blockSizeUnit" = 'M' "accessHint" = 's' "accesspattern" = 's' "outstandingIo" = 64 "enableSoftwarCache" = $false "enableWriteTrough" = $true "threads" = 8}} `
            -Configuration @(@{"fileSystem" = "NTFS" "allocationUnitSize" = 4096}) `
            -DriveLetter "t" `
            -OutputFolder .\ '
            -FileSize "10G" `
            -Duration 60 `
            -Warmup 5 `
            -Cooldown 60

#>
function Invoke-Benchmark
{
    param
    (
        [Hashtable] $Scenarios,     
        [Array] $Configurations,
        [char] $DriveLetter,
        [string] $OutputFolder,
        [string] $FileSize,
        [int] $Duration,
        [int] $Warmup,
        [int] $Cooldown,
        [bool] $EnableLatencyCollection 
    );

    process
    {
        $disk = Get-PhysicalDisk | Where-Object { $_.Size -eq 100GB };
        foreach($configuration in $Configurations)
        {
            Write-Information -MessageData "Preparing disk '$($configuration["fileSystem"])-$($configuration["allocationUnitSize"])'";
            Setup-Disk -Disk $disk -Configuration $configuration -DriveLetter $DriveLetter;

            foreach($scenario in $Scenarios.GetEnumerator())
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
                    "-c${FileSize}",
                    "-b$($config["blockSizeValue"])$($config["blockSizeUnit"])"
                    "-d$Duration"
                    "-t$($config["threads"])",
                    "-W$Warmup",
                    "-C$Cooldown",
                    "-Rxml",
                    "-w$($config["ratio"])",
                    "-f$($config["accessHint"])",
                    "-$($config["accessPattern"])",
                    "-o$($config["outstandingIo"])",
                    "-D",
                    $flags,
                    "${DriveLetter}:\diskspd.bin"
                );

                Write-Information -MessageData "Running scenario '$($scenario.Name)'";

                $process = Invoke-Diskspd -Arguments $arguments;
                Set-Content -Path "${OutputFolder}\diskspd-$($scenario.Name)-$($configuration["fileSystem"])-$($configuration["allocationUnitSize"]).xml" `
                    -Value $process.StandardOutput;

                # Write-Information -MessageData "Cooling down for ${duration} seconds";
                # Start-Sleep -Seconds $duration;
            }
        }
    }
}

<#
    .SYNOPSIS
        Parse benchmark output

    .PARAMETER Scenarios
        Hashtable of disk test scenarios

    .PARAMETER Configuration
        Array of parameters for disk initialization

    .PARAMETER OutputFolder
        Path to folder to store test results

    .OUTPUTS
        Returns array of individual results

    .EXAMPLE
        Invoke-Analysis `
            -Scenarios @{"write_throughput" = @{"ratio" = 100 "blockSizeValue" = 1 "blockSizeUnit" = 'M' "accessHint" = 's' "accesspattern" = 's' "outstandingIo" = 64 "enableSoftwarCache" = $false "enableWriteTrough" = $true "threads" = 8}} `
            -Configuration @(@{"fileSystem" = "NTFS" "allocationUnitSize" = 4096}) `
            -OutputFolder .\
#>
function Invoke-Analysis
{
    param
    (
        [Hashtable] $Scenarios,     
        [Array] $Configurations,
        [string] $OutputFolder
    );

    process
    {
        $results = @();

        foreach($configuration in $Configurations)
        {
            foreach($scenario in $Scenarios.GetEnumerator())
            {
                $document = "${OutputFolder}\diskspd-$($scenario.Name)-$($configuration["fileSystem"])-$($configuration["allocationUnitSize"]).xml";
                Write-Information -MessageData "Parsing data ${document}";

                $xml = [xml](Get-Content -Path $document);
                $result = New-Object psobject;

                # Generic test parameters
                $result | Add-Member -MemberType NoteProperty -Name "Timestamp" -Value $xml.Results.System.RunTime;
                $result | Add-Member -MemberType NoteProperty -Name "Scenario" -Value $scenario.Name;
                $result | Add-Member -MemberType NoteProperty -Name "File system" -Value $configuration["fileSystem"];
                $result | Add-Member -MemberType NoteProperty -Name "Allocation unit size" -Value $configuration["allocationUnitSize"];
                $result | Add-Member -MemberType NoteProperty -Name "Cores" -Value $xml.Results.TimeSpan.ProcCount;

                # Target specific test parameters
                $duration = $xml.Results.Profile.TimeSpans.TimeSpan.Duration;
                $result | Add-Member -MemberType NoteProperty -Name "Duration (s)" -Value $duration;
                $result | Add-Member -MemberType NoteProperty -Name "Actual duration (s)" -Value $xml.Results.TimeSpan.TestTimeSeconds;
                $result | Add-Member -MemberType NoteProperty -Name "Warmup (s)" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Warmup;
                $result | Add-Member -MemberType NoteProperty -Name "Cooldown (s)" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Cooldown;
                $result | Add-Member -MemberType NoteProperty -Name "Thread count" -Value $xml.Results.TimeSpan.ThreadCount;
                
                # What happens if there is more than one target?
                $result | Add-Member -MemberType NoteProperty -Name "Path" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.Path;
                $result | Add-Member -MemberType NoteProperty -Name "Block size" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.BlockSize;
                $result | Add-Member -MemberType NoteProperty -Name "Sequential scan" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.SequentialScan;
                $result | Add-Member -MemberType NoteProperty -Name "Random access" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RandomAccess;
                $result | Add-Member -MemberType NoteProperty -Name "Disable OS cache" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.DisableOSCache;
                $result | Add-Member -MemberType NoteProperty -Name "Write buffer content pattern" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.WriteBufferContent.Pattern;
                $result | Add-Member -MemberType NoteProperty -Name "File size" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.FileSize;
                $result | Add-Member -MemberType NoteProperty -Name "Request count (queue depth)" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RequestCount;

                # Performance metrics
                $bytesTotal = 0;
                $bytesRead = 0;
                $bytesWrite = 0;
                $ioTotal = 0;
                $ioRead = 0;
                $ioWrite = 0;

                foreach($thread in $xml.Results.TimeSpan.GetElementsByTagName("Thread"))
                {
                    $bytesTotal += $thread.Target.BytesCount;
                    $bytesRead += $thread.Target.ReadBytes;
                    $bytesWrite += $thread.Target.WriteBytes;
                    $ioTotal += $thread.Target.IOCOunt;
                    $ioRead += $thread.Target.ReadCount;
                    $ioWrite += $thread.Target.WriteCount;
                }

                $bytesPerSecondTotal = [int][Math]::Round($bytesTotal / $duration);
                $bytesPerSecondRead = [int][Math]::Round($bytesRead / $duration);
                $bytesPerSecondWrite = [int][Math]::Round($bytesWrite / $duration);

                $bytesTotal /= 1000000;
                $bytesRead /= 1000000;
                $bytesWrite /= 1000000;

                $bytesPerSecondTotal /= 1000000;
                $bytesPerSecondRead /= 1000000;
                $bytesPerSecondWrite /= 1000000;

                $ioPerSecondTotal = [int][Math]::Round($ioTotal / $duration);
                $ioPerSecondRead = [int][Math]::Round($ioRead / $duration);
                $ioPerSecondWrite = [int][Math]::Round($ioWrite / $duration);

                $result | Add-Member -MemberType NoteProperty -Name "MB (total)" -Value $bytesTotal;
                $result | Add-Member -MemberType NoteProperty -Name "MB (read)" -Value $bytesRead;
                $result | Add-Member -MemberType NoteProperty -Name "MB (write)" -Value $bytesWrite;
                $result | Add-Member -MemberType NoteProperty -Name "IO (total)" -Value $ioTotal;
                $result | Add-Member -MemberType NoteProperty -Name "IO (read)" -Value $ioRead;
                $result | Add-Member -MemberType NoteProperty -Name "IO (write)" -Value $ioWrite;

                $result | Add-Member -MemberType NoteProperty -Name "MB/s (total)" -Value $bytesPerSecondTotal;
                $result | Add-Member -MemberType NoteProperty -Name "MB/s(read)" -Value $bytesPerSecondRead;
                $result | Add-Member -MemberType NoteProperty -Name "MB/s (write)" -Value $bytesPerSecondWrite;
                $result | Add-Member -MemberType NoteProperty -Name "IOPS (total)" -Value $ioPerSecondTotal;
                $result | Add-Member -MemberType NoteProperty -Name "IOPS (read)" -Value $ioPerSecondRead;
                $result | Add-Member -MemberType NoteProperty -Name "IOPS (write)" -Value $ioPerSecondWrite;
                $results += $result;
            }
        }

        return $results
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

$outputFolder = "c:\tools";

if(-not $SkipBenchmark)
{
    $driveLetter = "t";
    $fileSize = "10G";
    $duration = 60;
    $warmup = 5;
    $cooldown = 60;
    $enableLatencyCollection = $false;

    Invoke-Benchmark -Scenarios $scenarios -Configurations $configurations -DriveLetter $driveLetter -OutputFolder $outputFolder `
        -FileSize $fileSize -Duration $duration -Warumup $warmup -Cooldown $cooldown -EnableLatencyCollection $enableLatencyCollection;
}

if(-not $SkipAnalysis)
{
    Invoke-Analysis -Scenarios $scenarios -Configurations $configurations -OutputFolder $outputFolder;
}
