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

        Write-Debug -Message "Running 'diskspd.exe $($Arguments -join " ")'";

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
            -Scenarios @{"write_throughput" = @{"ratio" = 100 "blockSizeValue" = 1 "blockSizeUnit" = 'M' "accessHint" = 's' "accesspattern" = 's' "outstandingIo" = 64 "enableSoftwareCache" = $false "enableWriteThrough" = $true "threads" = 8}} `
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
        $disk = Get-PhysicalDisk | Where-Object { $_.Size -eq 1000GB };
        foreach($configuration in $Configurations)
        {
            if(-not $configuration["skipDiskSetup"])
            {
                Write-Information -MessageData "Preparing disk '$($configuration["fileSystem"])-$($configuration["allocationUnitSize"])'";
                Setup-Disk -Disk $disk -Configuration $configuration -DriveLetter $DriveLetter;
            }

            foreach($scenario in $Scenarios.GetEnumerator())
            {
                $config = $scenario.Value;
                $flags = "";
                
                $size = $FileSize;
                if(-not [string]::IsNullOrEmpty($config["fileSize"]))
                {
                    $size = $config["fileSize"];
                }

                if(-not $config["enableRemoteCache"])
                {
                    if(-not $config["enableSoftwareCache"])
                    {
                        $flags += "-Su ";
                    }

                    if($config["enableWriteThrough"])
                    {
                        $flags += "-Sw ";
                    }
                }
                else
                {
                    $flags += "-Sr ";
                }

                if($enableLatencyCollection)
                {
                    $flags += "-L ";
                }

                if($config.Contains("otherFlags"))
                {
                    $flags += $config["otherFlags"];
                }

                $arguments = @(
                    "-c${size}", # Size of the test file
                    "-b$($config["blockSizeValue"])$($config["blockSizeUnit"])" # blocksize
                    "-d${Duration}" # test duration
                    "-t$($config["threads"])", # threads per file
                    "-W${Warmup}",
                    "-C${Cooldown}",
                    "-Rxml",
                    "-w$($config["ratio"])",
                    "-f$($config["accessHint"])",
                    "-$($config["accessPattern"])",
                    "-o$($config["outstandingIo"])",
                    "-D",
                    "-Z1M"
                    $flags,
                    "${DriveLetter}:\diskspd.bin"
                );

                if(Test-Path -Path "${DriveLetter}:\diskspd.bin")
                {
                    Write-Information -MessageData "Deleting '${DriveLetter}:\diskspd.bin' before diskspd run";
                    Remove-Item -Path "${DriveLetter}:\diskspd.bin" -Force;
                }

                Write-Information -MessageData "Running scenario '$($scenario.Name)'";

                $process = Invoke-Diskspd -Arguments $arguments;
                Set-Content -Path "${OutputFolder}\diskspd-$($scenario.Name)-$($configuration["fileSystem"])-$($configuration["allocationUnitSize"]).xml" `
                    -Value $process.StandardOutput;
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
            -Scenarios @{"write_throughput" = @{"ratio" = 100 "blockSizeValue" = 1 "blockSizeUnit" = 'M' "accessHint" = 's' "accesspattern" = 's' "outstandingIo" = 64 "enableSoftwareCache" = $false "enableWriteThrough" = $true "threads" = 8}} `
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
                if(Test-Path -Path $document)
                {
                    Write-Information -MessageData "Parsing data ${document}";

                    $xml = [xml](Get-Content -Path $document);
                    $result = New-Object psobject;

                    # Generic test parameters
                    $result | Add-Member -MemberType NoteProperty -Name "Timestamp" -Value $xml.Results.System.RunTime;
                    $result | Add-Member -MemberType NoteProperty -Name "Scenario" -Value $scenario.Name;
                    $result | Add-Member -MemberType NoteProperty -Name "FileSystem" -Value $configuration["fileSystem"];
                    $result | Add-Member -MemberType NoteProperty -Name "AllocationUnitSize" -Value $configuration["allocationUnitSize"];
                    $result | Add-Member -MemberType NoteProperty -Name "Cores" -Value $xml.Results.TimeSpan.ProcCount;

                    # Target specific test parameters
                    $duration = $xml.Results.Profile.TimeSpans.TimeSpan.Duration;
                    $result | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $duration;
                    $result | Add-Member -MemberType NoteProperty -Name "ActualDurationSeconds" -Value $xml.Results.TimeSpan.TestTimeSeconds;
                    $result | Add-Member -MemberType NoteProperty -Name "WarmupSeconds" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Warmup;
                    $result | Add-Member -MemberType NoteProperty -Name "CooldownSeconds" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Cooldown;
                    $result | Add-Member -MemberType NoteProperty -Name "ThreadCount" -Value $xml.Results.TimeSpan.ThreadCount;
                    
                    # What happens if there is more than one target?
                    $result | Add-Member -MemberType NoteProperty -Name "Path" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.Path;
                    $result | Add-Member -MemberType NoteProperty -Name "BlockSize" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.BlockSize;
                    $result | Add-Member -MemberType NoteProperty -Name "SequentialScan" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.SequentialScan;
                    $result | Add-Member -MemberType NoteProperty -Name "RandomAccess" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RandomAccess;
                    
                    # Depending on configuration property may not exist
                    try
                    {
                        $result | Add-Member -MemberType NoteProperty -Name "DisableOsCache" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.DisableOSCache;
                    }
                    catch
                    {
                        $result | Add-Member -MemberType NoteProperty -Name "DisableOsCache" -Value "false";
                    }

                    # Depending on configuration property may not exist
                    try
                    {
                        $result | Add-Member -MemberType NoteProperty -Name "DisableLocalCache" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.DisableLocalCache;
                    }
                    catch
                    {
                        $result | Add-Member -MemberType NoteProperty -Name "DisableLocalCache" -Value "false";
                    }
                    
                    $result | Add-Member -MemberType NoteProperty -Name "WriteBufferContentPattern" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.WriteBufferContent.Pattern;
                    $result | Add-Member -MemberType NoteProperty -Name "FileSize" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.FileSize;
                    $result | Add-Member -MemberType NoteProperty -Name "RequestCount" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RequestCount;
                    $result | Add-Member -MemberType NoteProperty -Name "WriteRatio" -Value $xml.Results.Profile.TimeSpans.TimeSpan.Targets.Target.WriteRatio;

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

                    $bytesPerSecondTotal = [double][Math]::Round($bytesTotal / $duration);
                    $bytesPerSecondRead = [double][Math]::Round($bytesRead / $duration);
                    $bytesPerSecondWrite = [double][Math]::Round($bytesWrite / $duration);

                    $bytesTotal /= 1000000;
                    $bytesRead /= 1000000;
                    $bytesWrite /= 1000000;

                    $bytesPerSecondTotal /= 1000000;
                    $bytesPerSecondRead /= 1000000;
                    $bytesPerSecondWrite /= 1000000;

                    $ioPerSecondTotal = [double][Math]::Round($ioTotal / $duration);
                    $ioPerSecondRead = [double][Math]::Round($ioRead / $duration);
                    $ioPerSecondWrite = [double][Math]::Round($ioWrite / $duration);

                    $result | Add-Member -MemberType NoteProperty -Name "MbTotal" -Value $bytesTotal;
                    $result | Add-Member -MemberType NoteProperty -Name "MbRead" -Value $bytesRead;
                    $result | Add-Member -MemberType NoteProperty -Name "MbWrite" -Value $bytesWrite;
                    $result | Add-Member -MemberType NoteProperty -Name "IoTotal" -Value $ioTotal;
                    $result | Add-Member -MemberType NoteProperty -Name "IoRead" -Value $ioRead;
                    $result | Add-Member -MemberType NoteProperty -Name "IoWrite" -Value $ioWrite;

                    $result | Add-Member -MemberType NoteProperty -Name "MbSecondTotal" -Value $bytesPerSecondTotal;
                    $result | Add-Member -MemberType NoteProperty -Name "MbSecondRead" -Value $bytesPerSecondRead;
                    $result | Add-Member -MemberType NoteProperty -Name "MbSecondWrite" -Value $bytesPerSecondWrite;
                    $result | Add-Member -MemberType NoteProperty -Name "IoSecondTotal" -Value $ioPerSecondTotal;
                    $result | Add-Member -MemberType NoteProperty -Name "IoSecondRead" -Value $ioPerSecondRead;
                    $result | Add-Member -MemberType NoteProperty -Name "IoSecondWrite" -Value $ioPerSecondWrite;
                    
                    # Only available if latency collection was enabled
                    # read/write latency only available if 0 > write ratio < 100
                    $latency = $xml.Results.TimeSpan["Latency"];
                    if($null -ne $latency)
                    {
                        $readLatency = 0;
                        $writeLatency = 0;

                        if($null -ne $latency["AverageReadMilliseconds"])
                        {
                            $readLatency = $latency["AverageReadMilliseconds"].'#text';
                        }

                        if($null -ne $latency["AverageWriteMilliseconds"])
                        {
                            $writeLatency = $latency["AverageWriteMilliseconds"].'#text';
                        }
                        
                        $result | Add-Member -MemberType NoteProperty -Name "AvgLatencyRead" -Value $readLatency;
                        $result | Add-Member -MemberType NoteProperty -Name "AvgLatencyWrite" -Value $writelatency;
                    }
                    
                    $results += $result;
                }
            }
        }

        return $results
    }
}

$logicalProcessors = (Get-ComputerInfo -Property CsProcessors).CsProcessors.NumberOfLogicalProcessors;
if($logicalProcessors -is [array])
{
    $cores = 0;
    foreach($socket in $logicalProcessors)
    {
        $cores += $socket;
    }
    $logicalProcessors = $cores;
}

# Tests with diskspd have shown that running it with threads per file equal to the number of logical processors (-t8) and a queue depth (-o1) of 1
# is sufficient achieve maximum througput/IOs while increasing the number of outstanding IOs and/or logical processors beyond that just increases
# IO latency witout yielding more performance. This is probably due to rate limiting of the PDs
$scenarios = @{
    # Based on https://cloud.google.com/compute/docs/disks/benchmarking-pd-performance
    "write_throughput" = @{
        "ratio" = 100
        "blockSizeValue" = 1
        "blockSizeUnit" = 'M'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = $logicalProcessors
    }
    # Based on https://cloud.google.com/compute/docs/disks/benchmarking-pd-performance
    "write_iops" = @{
        "ratio" = 100
        "blockSizeValue" = 4
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = $logicalProcessors
    }
    # Based on https://cloud.google.com/compute/docs/disks/benchmarking-pd-performance
    "read_throughput" = @{
        "ratio" = 0
        "blockSizeValue" = 1
        "blockSizeUnit" = 'M'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = $logicalProcessors
    }
    # Based on https://cloud.google.com/compute/docs/disks/benchmarking-pd-performance
    "read_iops" = @{
        "ratio" = 0
        "blockSizeValue" = 4
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = $logicalProcessors
    }
    # Based on 
    # https://www.sqlshack.com/using-diskspd-to-test-sql-server-storage-subsystems/
    # https://docs.microsoft.com/en-us/azure-stack/hci/manage/diskspd-overview#online-transaction-processing-oltp-workload
    # https://www.altaro.com/hyper-v/storage-performance-baseline-diskspd//
    # 
    # OLTP workloads are latency sensitive (more IOPS = better performance)
    "sql_oltp_logwrite_4k" = @{
        "ratio" = 100
        "blockSizeValue" = 4
        "blockSizeUnit" = 'K'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = "2"
    }
    "sql_oltp_logwrite_64k" = @{
        "ratio" = 100
        "blockSizeValue" = 64
        "blockSizeUnit" = 'K'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = "2"
    }
    "sql_oltp_dataread_8k" = @{
        "ratio" = 0
        "blockSizeValue" = 8
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = "2"
    }
    "sql_oltp_dataread_128k" = @{
        "ratio" = 0
        "blockSizeValue" = 128
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = "2"
    }
    # Based on https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn894707(v=ws.11)#random-small-io-test-1-vary-outstanding-ios-per-thread
    #
    # OLAP workloads are throughput sensitive (better throughput = faster transactions)
    "sql_olap" = @{
        "ratio" = 0
        "blockSizeValue" = 512 # 512K blocks is a common I/O size for SQL Server loading a batch of 64 pages with read-ahead
        "blockSizeUnit" = 'K'
        "accessHint" = 's'
        "accesspattern" = 's'
        "outstandingIo" = 1
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "threads" = $logicalProcessors
        "otherParameters" = "-si"
    }
    # Based on https://unhandled.wordpress.com/2016/07/20/madness-testing-smb-direct-network-throughput-with-diskspd/
    #
    # Small files accessed with random 64K IOs
    "smb_network_throughput_writethrough" = @{
        "fileSize" = "2M"
        "ratio" = 0
        "blockSizeValue" = 64
        "blockSizeUnit" = 'K'
        "accessHint" = 't'
        "accesspattern" = 'r'
        "outstandingIo" = 2
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "enableRemoteCache" = $false # Only available for remote file systems
        "threads" = $logicalProcessors
    }
    "smb_network_throughput_remotecache" = @{
        "fileSize" = "2M"
        "ratio" = 0
        "blockSizeValue" = 64
        "blockSizeUnit" = 'K'
        "accessHint" = 't'
        "accesspattern" = 'r'
        "outstandingIo" = 2
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $false
        "enableRemoteCache" = $true # Only available for remote file systems
        "threads" = $logicalProcessors
    }
    # Based on https://www.windowspro.de/marcel-kueppers/storage-performance-iops-unter-hyper-v-messen-diskspd
    "smb_30_70_writethrough" = @{
        "ratio" = 30
        "blockSizeValue" = 8
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = $logicalProcessors
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $true
        "enableRemoteCache" = $false # Only available for remote file systems
        "threads" = $logicalProcessors
    }
    "smb_30_70_remotecache" = @{
        "ratio" = 30
        "blockSizeValue" = 8
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = $logicalProcessors
        "enableSoftwareCache" = $false
        "enableWriteThrough" = $false
        "enableRemoteCache" = $true # Only available for remote file systems
        "threads" = $logicalProcessors
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
    },
    @{
        "fileSystem" = "SMB"
        "allocationUnitSize" = 4096
        "skipDiskSetup" = $true
    }
);

$outputFolder = "c:\tools";

if(-not $SkipBenchmark)
{
    $driveLetter = "t";
    $fileSize = "64G";
    $duration = 60;
    $warmup = 15;
    $cooldown = 15;
    $enableLatencyCollection = $true;

    Invoke-Benchmark -Scenarios $scenarios -Configurations $configurations -DriveLetter $driveLetter -OutputFolder $outputFolder `
        -FileSize $fileSize -Duration $duration -Warmup $warmup -Cooldown $cooldown -EnableLatencyCollection $enableLatencyCollection;
}

if(-not $SkipAnalysis)
{
    Invoke-Analysis -Scenarios $scenarios -Configurations $configurations -OutputFolder $outputFolder;
}
