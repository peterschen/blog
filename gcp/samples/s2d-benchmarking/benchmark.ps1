[CmdletBinding()]
param
(
    [string] $ConfigFolder = "C:\tools",
    [string] $OutputFolder = "C:\tools",
    [bool] $SkipBenchmark = $false,
    [bool] $SkipAnalysis = $false,
    [string] $DiskId = ""
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
        [string] $FileSystem,
        [int] $AllocationUnitSize,
        [String] $DriveLetter
    );

    process
    {
        Clear-Disk -UniqueId $Disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
    
        $fileSystem = $FileSystem;
        $label = "${fileSystem}-$($AllocationUnitSize / 1024)K";

        Initialize-Disk -UniqueId $Disk.UniqueId -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize -DriveLetter $DriveLetter |
            Format-Volume -AllocationUnitSize $AllocationUnitSize -FileSystem $FileSystem -NewFileSystemLabel $label |
            Out-Null;
    }
}

<#
    .SYNOPSIS
        Start benchmark run

    .PARAMETER Scenarios
        Array of disk test scenarios

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
        [Array] $Scenarios,     
        [Array] $Configurations,
        [string] $OutputFolder,
        [string] $FileSize,
        [int] $Duration,
        [int] $Warmup,
        [int] $Cooldown,
        [bool] $EnableLatencyCollection,
        [string] $DiskId
    );

    process
    {
        $disk = $null;
        if($DiskId -ne "")
        {
            $disk = Get-Disk -UniqueId $DiskId;
        }

        foreach($configuration in $Configurations.GetEnumerator())
        {
            if("testPath" -in $Configuration.PSObject.Properties.Name)
            {
                $testPath = Join-Path -Path $configuration.testPath -ChildPath "\benchmark_$($env:COMPUTERNAME).bin";
            }
            else
            {
                throw "'testPath' needs to be passed in configuration";
            }

            $skipDiskSetup = $false;
            if("skipDiskSetup" -in $Configuration.PSObject.Properties.Name)
            {
                $skipDiskSetup = $configuration.skipDiskSetup;
            }

            if(-not $skipDiskSetup)
            {
                if($disk -eq $null)
                {
                    throw "'DiskId' needs to be passed in arguments"
                }

                Write-Information -MessageData "Preparing disk '$($configuration.fileSystem)-$($configuration.allocationUnitSize)'";
                Setup-Disk -Disk $disk -FileSystem $configuration.fileSystem -AllocationUnitSize $configuration.allocationUnitSize  `
                    -DriveLetter (Split-Path -Path $Configuration.testPath -Qualifier);
            }

            foreach($scenario in $Scenarios.GetEnumerator())
            {
                $config = $scenario.Value;
                $flags = "";
                
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
                    "-c$($config["fileSize"])", # Size of the test file
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
                    "${testPath}"
                );

                # Seed test file
                Initialize-TestFile -Path $testPath -FileSize $config["fileSize"];

                Write-Information -MessageData "Running scenario '$($scenario.Name)'";
                $process = Invoke-Diskspd -Arguments $arguments;

                # Construct output path
                $fileName = "diskspd-$($scenario.Name)-$($configuration.fileSystem)";
                if("allocationUnitSize" -in $configuration.PSObject.Properties.Name)
                {
                    $fileName += "-$($configuration.allocationUnitSize)";
                }
                
                # Write output
                $outputPath = Join-Path -Path $OutputFolder -ChildPath "${fileName}.xml";
                Set-Content -Path $outputPath -Value $process.StandardOutput;
            }
        }
    }
}

<#
    .SYNOPSIS
        Parse benchmark output

    .PARAMETER Scenarios
        Array of benchmark scenarios

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
        [Array] $Scenarios,     
        [Array] $Configurations,
        [string] $OutputFolder
    );

    process
    {
        $results = @();

        foreach($configuration in $Configurations.GetEnumerator())
        {
            foreach($scenario in $Scenarios.GetEnumerator())
            {
                $allocationUnitSize = $null;
                $fileName = "diskspd-$($scenario.Name)-$($configuration.fileSystem)";
                
                if("allocationUnitSize" -in $configuration.PSObject.Properties.Name)
                {
                    $allocationUnitSize = $configuration.allocationUnitSize;
                    $fileName += "-$($configuration.allocationUnitSize)";
                }

                $document = Join-Path -Path $OutputFolder -ChildPath "${fileName}.xml";
                if(Test-Path -Path $document)
                {
                    Write-Information -MessageData "Parsing data '${document}'";

                    $xml = [xml](Get-Content -Path $document);
                    $result = New-Object psobject;

                    # Generic test parameters
                    $result | Add-Member -MemberType NoteProperty -Name "Timestamp" -Value $xml.Results.System.RunTime;
                    $result | Add-Member -MemberType NoteProperty -Name "Scenario" -Value $scenario.Name;
                    $result | Add-Member -MemberType NoteProperty -Name "FileSystem" -Value $configuration.fileSystem;
                    $result | Add-Member -MemberType NoteProperty -Name "AllocationUnitSize" -Value $allocationUnitSize;
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
                        
                        $result | Add-Member -MemberType NoteProperty -Name "AvgLatencyMsRead" -Value $readLatency;
                        $result | Add-Member -MemberType NoteProperty -Name "AvgLatencyMsWrite" -Value $writelatency;
                    }
                    
                    $results += $result;
                }
                else
                {
                    Write-Warning -MessageData "Can't read file '${document}'";
                }
            }
        }

        return $results
    }
}

<#
    .SYNOPSIS
        Creates and seeds test file with random data

    .PARAMETER Path
        Path to test file

    .PARAMETER FileSize
        Size of test file

    .EXAMPLE
        Initialize-TestFile `
            -Path  = "C:\ClusterStorage\mirror-2way\diskspd.bin" `
            -FileSize "64G"
#>
function Initialize-TestFile
{
    param
    (
        [string] $Path,
        [string] $FileSize
    )

    process
    {
        $create = $true;

        if(Test-Path -Path $Path)
        {
            $fileSizeValue = [int] $FileSize.SubString(0, $FileSize.Length - 1);
            $fileSizeUnit = $FileSize.SubString($FileSize.Length - 1, 1).ToUpper();

            if($fileSizeUnit -eq "K")
            {
                $fileSizeValue *= 1024;
            }
            elseif($fileSizeUnit -eq "M")
            {
                $fileSizeValue *= 1024 * 1024;
            }
            elseif($fileSizeUnit -eq "G")
            {
                $fileSizeValue *= 1024 * 1024 * 1024;
            }

            $currentFileSize = (Get-Item -Path $Path).Length;
            if($currentFileSize -eq $fileSizeValue)
            {
                $create = $false
            }
        }

        if ($create)
        {
            Write-Information -MessageData "Initializing '${Path}' with ${FileSize} of random data";

            # 120s write of random data
            $arguments = @(
                "-c${FileSize}",
                "-d120",
                "-w100",
                "-Zr"
                "${Path}"
            );

            $process = Invoke-Diskspd -Arguments $arguments;
        }
        else
        {
            Write-Information -MessageData "File '${Path}' already exists";
        }
    }
}

<#
    .SYNOPSIS
        Import scenarios from json file

    .PARAMETER ConfigurationFolder
        Path to folder containing configuration files

    .PARAMETER Processors
        Processors installed in the server

    .OUTPUTS
        Returns HashMap with scenarios to run
#>
function Import-Scenarios
{
    param
    (
        [string] $ConfigurationFolder,
        [int] $Processors
    );

    process
    {
        $scenarios = @{};

        $scenariosFile = Join-Path -Path $ConfigurationFolder -ChildPath "benchmark_scenarios.json";
        $configurations = Get-Content -Path $scenariosFile | %{ if ($_.Contains('//')){ $_.SubString(0, $_.IndexOf('//')) } else {$_}}
        $configurations = $configurations -Join "`n" | ConvertFrom-Json;

        foreach($configuration in $configurations.GetEnumerator())
        {
            $startThreads = $Processors;
            $endThreads = $Processors;

            $startOutstandingIo = $Processors;
            $endOutstandingIo = $Processors;

            if($configuration.incrementThreads)
            {
                $startThreads = 1;
                $endThreads = ($Processors / 8 + 1) * 8;
            }

            if($configuration.incrementQueueDepth)
            {
                $startOutstandingIo = 1;
                $endOutstandingIo = ($Processors / 8 + 1) * 8;
            }

            for($t = $startThreads; $t -le $endThreads;)
            {
                for($q = $startOutstandingIo; $q -le $endOutstandingIo;)
                {
                    $name = "$($configuration.name)_t$($t.ToString().PadLeft(3, '0'))_q$($q.ToString().PadLeft(3, '0'))";
                    $scenarios[$name] = New-Scenario -Threads $t -OutstandingIo $q `
                        -Configuration $configuration.config;

                    if($q -eq 1)
                    {
                        $q = 8;
                    }
                    else
                    {
                        $q += 8;
                    }
                }

                if($t -eq 1)
                {
                    $t = 8;
                }
                else
                {
                    $t += 8;
                }
            }
        }

        return $scenarios;
    }
}

<#
    .SYNOPSIS
        Constructs a new scenario HashTable

    .PARAMETER Threads
        Number of threads

    .PARAMETER OutstandingIo
        Queue depth for this scenario

    .PARAMETER Configuration
        Configuration object

    .OUTPUTS
        Returns HashMap with scenarios to run
#>
function New-Scenario
{
    param
    (
        [int] $Threads,
        [int] $OutstandingIo,
        [PSCustomObject] $Configuration
    );

    process
    {
        $scenario = @{
            ratio = $Configuration.ratio
            blockSizeValue = $Configuration.blockSizeValue
            blockSizeUnit = $Configuration.blockSizeUnit
            accessHint = $Configuration.accessHint
            accessPattern = $Configuration.accessPattern
            threads = $Threads
            outstandingIo = $OutstandingIo
        };

        $scenario["fileSize"] = "64G";
        if("FileSize" -in $Configuration.PSObject.Properties.Name)
        {
            $scenario["fileSize"] = $Configuration.fileSize;
        }

        if("EnableWriteThrough" -in $Configuration.PSObject.Properties.Name)
        {
            $scenario["enableWriteThrough"] = $Configuration.enableWriteThrough;
        }

        if("EnableSoftwareCache" -in $Configuration.PSObject.Properties.Name)
        {
            $scenario["enableSoftwareCache"] = $Configuration.enableSoftwareCache;
        }

        if("EnableRemoteCache" -in $Configuration.PSObject.Properties.Name)
        {
            $scenario["enableRemoteCache"] = $Configuration.enableRemoteCache;
        }

        return $scenario;
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

$configurationsFile = Join-Path -Path $ConfigFolder -ChildPath "benchmark_configurations.json";

# While PowerShell 6+ supports comments in JSON older versions do not
$configurations = Get-Content -Path $configurationsFile | %{ if ($_.Contains('//')){ $_.SubString(0, $_.IndexOf('//')) } else {$_}} | ConvertFrom-Json;
$scenarios = (Import-Scenarios -ConfigurationFolder $ConfigFolder -Processors $logicalProcessors).GetEnumerator() | Sort-Object -Property Name;

if(-not $SkipBenchmark)
{
    $duration = 60;
    $warmup = 15;
    $cooldown = 15;
    $enableLatencyCollection = $true;

    Invoke-Benchmark -Scenarios $scenarios -Configurations $configurations -OutputFolder $OutputFolder `
        -Duration $duration -Warmup $warmup -Cooldown $cooldown -EnableLatencyCollection $enableLatencyCollection;
}

if(-not $SkipAnalysis)
{
    Invoke-Analysis -Scenarios $scenarios -Configurations $configurations -OutputFolder $OutputFolder;
}
