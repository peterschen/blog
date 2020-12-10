Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";

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
        # Zone is returned as projects/#projectId/zones/#zone
        $zone = Get-InstanceMetadata -Entry "zone";
        return $zone.Substring($zone.LastIndexOf("/") + 1);
    }
}

$vmName = Get-VmName;
$zone = Get-Zone;
$jobId = Get-PatchJobId -VmName $vmName -Zone $zone;

Write-Host "Patching $vmName as part of patch job $jobId";

Start-Sleep -Seconds 120;
