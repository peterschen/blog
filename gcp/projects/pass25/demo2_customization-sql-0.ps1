configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        SqlServerDsc;

    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Credential.Password);

    Script "InitDisk"
    {
        GetScript = {
            # Ensure status of disks is current
            Get-PhysicalDisk | Reset-PhysicalDisk;
            
            $disk = Get-PhysicalDisk -CanPool $true | Where-Object -Property Size -EQ -Value 100GB | Select-Object -First 1;
            if($disk -eq $null)
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
            $disk = Get-PhysicalDisk -CanPool $true | Where-Object -Property Size -EQ -Value 100GB | Select-Object -First 1;
            
            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru |
                New-Partition -DriveLetter "T" -UseMaximumSize | 
                Format-Volume;
        }
    }

    Script "InitQuorumDisk"
    {
        GetScript = {
            # Ensure status of disks is current
            Get-PhysicalDisk | Reset-PhysicalDisk;
            
            $disk = Get-disk | Where-Object -Property Size -EQ -Value 4GB | Where-Object -Property PartitionStyle -EQ -Value "RAW" |  Select-Object -First 1;
            if($disk -eq $null)
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
            $disk = Get-disk | Where-Object -Property Size -EQ -Value 4GB | Where-Object -Property PartitionStyle -EQ -Value "RAW" |  Select-Object -First 1;
            
            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru |
                New-Partition -DriveLetter "Q" -UseMaximumSize | 
                Format-Volume;
        }
    }

    Script "AddClusterDisk"
    {
        GetScript = {
            $resource = Get-ClusterSharedVolume -Name "Cluster Disk 1" -ErrorAction "SilentlyContinue";
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
            $clusterDisk = Get-ClusterAvailableDisk | Where-Object -Property Size -EQ -Value 100GB | Add-ClusterDisk;
            $resource = Add-ClusterSharedVolume -Name $clusterDisk.Name;

            # Bring disk online if necessary
            Resume-ClusterResource -InputObject $resource;
        }

        PsDscRunAsCredential = $Credential
        DependsOn = "[Script]InitDisk"
    }

    Script "AddClusterQuorumDisk"
    {
        GetScript = {
            $resource = Get-ClusterQuorum -ErrorAction "SilentlyContinue";
            if($resource -ne $null -and $resource.QuorumResource -ne $null -and $resource.QuorumResource.ResourceType -eq "Physical Disk")
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
            $clusterDisk = Get-ClusterAvailableDisk | Where-Object -Property Size -EQ -Value 4GB | Add-ClusterDisk;
            Set-ClusterQuorum -DiskWitness $clusterDisk.Name;
        }

        PsDscRunAsCredential = $Credential
        DependsOn = "[Script]InitQuorumDisk"
    }

    SqlSetup "SqlServerSetup"
    {
        Action = "InstallFailoverCluster"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SecurityMode = "SQL"
        SAPwd = $domainCredential
        SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        FailoverClusterNetworkName = $Parameters.nodePrefix
        FailoverClusterIPAddress = $Parameters.ipSql
        InstallSQLDataDir = "C:\ClusterStorage\Volume1"

        SkipRule = "Cluster_VerifyForErrors"

        PsDscRunAsCredential = $Credential
        DependsOn = "[Script]InitDisk"
    }
}