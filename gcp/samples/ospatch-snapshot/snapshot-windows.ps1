Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

<#
    .SYNOPSIS
        This function calls the gcloud binary

    .PARAMETER Arguments
        Array of arguments to be passed to gcloud

    .OUTPUTS
        PSCustomObject {StandardOutput, StandardError, ExitCode}

    .EXAMPLE
        Invoke-Gcloud -Arguments @("compute", "instances", "list");
#>
function Invoke-Gcloud
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
        $info.Arguments = "/C gcloud.cmd $($Arguments -join " ")";

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
        This function returns the object name from a given resource URI

    .PARAMETER Uri
        GCP resource URI

    .OUTPUTS
        Object name

    .EXAMPLE
        ConvertTo-ObjectName -Uri "https://www.googleapis.com/compute/v1/projects/test/zones/europe-west4-a/disks/test";
#>
function ConvertTo-ObjectName
{
    param
    (
        [string] $Uri
    );

    process
    {
        return $uri.Substring($uri.LastIndexOf("/") + 1);
    }
}

<#
    .SYNOPSIS
        This function returns the project from a given resource URI

    .PARAMETER Uri
        GCP resource URI

    .OUTPUTS
        Project

    .EXAMPLE
        ConvertTo-Project -Uri "https://www.googleapis.com/compute/v1/projects/test/zones/europe-west4-a/disks/test";
#>
function ConvertTo-Project
{
    param
    (
        [string] $Uri
    );

    process
    {
        $start = $Uri.IndexOf("projects/") + 9;
        $end = $Uri.IndexOf("/", $start);

        if($end -eq -1)
        {
            $end = $Uri.Length - $start;
        }

        return $Uri.Substring($start, $end);
    }
}

<#
    .SYNOPSIS
        This function returns the zone from a given resource URI

    .PARAMETER Uri
        GCP resource URI

    .OUTPUTS
        Zone

    .EXAMPLE
        ConvertTo-Zone -Uri "https://www.googleapis.com/compute/v1/projects/test/zones/europe-west4-a/disks/test";
#>
function ConvertTo-Zone
{
    param
    (
        [string] $Uri
    );

    process
    {
        $start = $Uri.IndexOf("zones/") + 6;
        $end = $Uri.IndexOf("/", $start);

        if($end -eq -1)
        {
            $end = $Uri.Length - $start;
        }

        return $Uri.Substring($start, $end);
    }
}

<#
    .SYNOPSIS
        Returns instance metadata queried from the GCE metadata endpoint

    .PARAMETER Entry
        Metadata entry to query for

    .OUTPUTS
        Metadata value for the entry

    .EXAMPLE
        Get-InstanceMetadata -Entry "name";

    .LINK
        https://cloud.google.com/compute/docs/storing-retrieving-metadata#project-instance-metadata
#>
function Get-InstanceMetadata
{
    param
    (
        [string] $Entry
    );

    process
    {
        return Invoke-RestMethod `
            -Headers @{"Metadata-Flavor" = "Google"} `
            -Uri "http://metadata/computeMetadata/v1/instance/$($Entry)";
    }
}

<#
    .SYNOPSIS
        Function determines the ID of the patch job 

    .DESCRIPTION
        At any given time more than one patch job might be active.
        This function validates each active patch job with the name
        of the current VM and its region and returns the ID of the
        first patch job that matches all criteria.

    .PARAMETER VmName
        Name of the VM

    .PARAMETER Zone
        Zone of the VM

    .OUTPUTS
        GUID representing the patch job ID

    .EXAMPLE
        Get-PatchJobId -VmName "instance-1" -Zone "europe-west4-a"
#>
function Get-PatchJobId
{
    param
    (
        [string] $VmName,
        [string] $Zone
    );

    process
    {
        # Get running patch jobs
        $jobs = gcloud compute os-config patch-jobs list --filter="state:patching" --format="value(ID)";

        # Iterating all jobs
        foreach($job in $jobs)
        {
            # Check if this instance is targetted by the patch job
            # and the job is in the RUNNING_PRE_PATCH_STEP
            $filter = "name:$($VmName) AND zone:$($Zone) AND state:RUNNING_PRE_PATCH_STEP";
            $instance = gcloud compute os-config patch-jobs list-instance-details $job --filter=$filter --format="value(NAME)";
            if($instance -eq $VmName)
            {
                return $job;
            }
        }

        return $null;
    }
}

<#
    .SYNOPSIS
        Gets the name of the current VM from metadata

    .OUTPUTS
        Name of the VM

    .EXAMPLE
        Get-VmName;
#>
function Get-VmName
{
    param
    (
    );

    process
    {
        return Get-InstanceMetadata -Entry "name";
    }
}

<#
    .SYNOPSIS
        Gets the zone of the current VM from metadata

    .OUTPUTS
        Zone of the VM

    .EXAMPLE
        Get-Zone;
#>
function Get-Zone
{
    param
    (
    );

    process
    {
        $zone = Get-InstanceMetadata -Entry "zone";
        return ConvertTo-Zone -Uri $zone;
    }
}

<#
    .SYNOPSIS
        Retrieve the resource IDs for the disks associated with the given VM

    .PARAMETER VmName
        Name of the VM

    .PARAMETER Zone
        Zone of the VM

    .OUTPUTS
        Array with disk resource IDs 

    .EXAMPLE
        Get-Disks -VmName "instance-1" -Zone "europe-west4-a"
#>
function Get-Disks
{
    param
    (
        [string] $VmName,
        [string] $Zone
    );

    process
    {
        $arguments = @(
            "compute",
            "instances",
            "describe",
            $VmName,
            "--zone $Zone",
            '--format="value[delimiter=\n](disks[].source)"'
        );
            
        $process = Invoke-Gcloud -Arguments $arguments;

        # Trim whitespaces from output and split on newline
        return $process.StandardOutput.Trim().Split("`n");
    }
}

<#
    .SYNOPSIS
        Creates a disk clone for all attached disk(s)

    .PARAMETER Disks
        Array of disk resource URIs

    .PARAMETER VmName
        Name of the current VM

    .PARAMETER PachJobId
        Id of the patch job

    .EXAMPLE
        New-Clone -Disks @(https://www.googleapis.com/compute/v1/projects/test/zones/europe-west4-a/disks/boot https://www.googleapis.com/compute/v1/projects/test/zones/europe-west4-a/disks/data) `
            -VmName "instance-1" -PatchJobId "9245b1bc-643b-4f87-8020-eda82d1d3cb4"
#>
function New-Clone
{
    param
    (
        [string[]] $Disks,
        [string] $VmName,
        [string] $PatchJobId
    );

    process
    {
        foreach($diskId in $Disks)
        {
            $sourceName = ConvertTo-ObjectName -Uri $diskId;
            $targetName = "$sourceName-$PatchJobId";
            $targetDiskId = $diskId.Replace($sourceName, $targetName);

            $arguments = @(
                "compute",
                "disks",
                "create",
                $targetDiskId,
                '--description="Clone before patching"',
                "--labels reason=patching,patchjob=$PatchJobId,vm=$VmName",
                "--user-output-enabled false",
                "--source-disk $diskId"
            );
            
            $process = Invoke-Gcloud -Arguments $arguments;
            if($process.ExitCode -ne 0)
            {
                return $false;
            }
        }

        return $true;
    }
}

$vmName = Get-VmName;
$zone = Get-Zone;

Write-Host -NoNewline "Determining patch job: ";
$jobId = Get-PatchJobId -VmName $vmName -Zone $zone;
Write-Host $jobId;

Write-Host -NoNewline "Retrieving disks associated with VM: ";
$disks = @(Get-Disks -VmName $vmName -Zone $zone);
Write-Host "$($disks.Count) disk(s) found";

Write-Host -NoNewline "Creating clone(s): ";
$result = New-Clone -Disks $disks -VmName $VmName -PatchJobId $jobId;

if($result)
{
    Write-Host "done";
}
else
{
    Write-Host "failed";
    
    # Return non-zero exit code to stop patching
    [System.Environment]::Exit(1);
}
