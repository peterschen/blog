configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration;

    Script "InitDisk"
    {
        GetScript = {
            $partition = Get-Partition -DriveLetter "T" -ErrorAction "SilentlyContinue";
            if($partition -ne $null)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }
            
            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
            $disk = Get-PhysicalDisk -CanPool $true;

            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru |
                New-Partition -DriveLetter "T" -UseMaximumSize | 
                Format-Volume;
        }
    }

    Script "AddClusterDisk"
    {
        GetScript = {
            $resource = Get-ClusterResource -Name "Cluster Disk 1" -ErrorAction "SilentlyContinue";
            if($resource -ne $null)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }
            
            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
            # Add disk to cluster
            $clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk;
            $resource = Add-ClusterSharedVolume -Name $clusterDisk.Name;

            # Bring disk online if necessary
            Resume-ClusterResource -InputObject $resource;
        }

        DependsOn = "[Script]InitDisk"
    }
}