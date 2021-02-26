Set-StrictMode -Version Latest;
$InformationPreference = "Continue";
$ErrorActionPreference = "Stop";

# https://datacadamia.com/io/access_pattern

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
        $info.Arguments = "/C c:\tools\amd64\diskspd.exe $($Arguments -join " ")";

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

$outputFolder = "c:\tools";
$disks = @(
    "d", "e", "f", "g", "h"
);

$fileSizeValue = "10";
$fileSizeUnit = "G";
$duration = 60;
$threads = 1;
$warmup = 5;
$cooldown = 0;

$scenarios = @{
    "fileserver" = @{
        "ratio" = 20
        "blockSizeValue" = 64
        "blockSizeUnit" = 'K'
        "accessHint" = 'r'
        "accesspattern" = 'r'
        "outstandingIo" = 32
        "enableSoftwarCache" = $true
        "enableWriteTrough" = $true
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
        "-o$($config["outstandingIo"])"
        "-L",
        $flags
    );

    foreach($disk in $disks)
    {
        Write-Information -MessageData "Running diskspd for '${disk}:'";

        $args = $arguments;
        $args += @(
            "${disk}:\diskspd.bin"
        );

        $process = Invoke-Diskspd -Arguments $args;
        Set-Content -Path "${outputFolder}\diskspd-$($scenario.Name)-${disk}.xml" -Value $process.StandardOutput;

        Write-Information -MessageData "Cooling down for ${duration} seconds";
        Start-Sleep -Seconds $duration;
    }
}
