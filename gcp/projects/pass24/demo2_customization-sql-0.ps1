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
            $disk = Get-PhysicalDisk -CanPool $true;
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
            $clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk;
            $resource = Add-ClusterSharedVolume -Name $clusterDisk.Name;

            # Bring disk online if necessary
            Resume-ClusterResource -InputObject $resource;
        }

        PsDscRunAsCredential = $Credential
        DependsOn = "[Script]InitDisk"
    }

    SqlSetup "SqlServerSetup"
    {
        Action = "InstallFailoverCluster"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
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