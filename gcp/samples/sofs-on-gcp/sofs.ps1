configuration ConfigurationWorkload
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [securestring] $Password,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        ComputerManagementDsc, ActiveDirectoryDsc, NetworkingDsc, xFailOverCluster;

    $features = @(
        "Failover-clustering",
        "FS-FileServer",
        "Storage-Replica",
        "RSAT-Clustering-Mgmt",
        "RSAT-Clustering-PowerShell",
        "RSAT-Storage-Replica"
    );

    $rules = @(
        "FPS-NB_Datagram-In-UDP",
        "FPS-NB_Name-In-UDP",
        "FPS-NB_Session-In-TCP",
        "FPS-SMB-In-TCP",
        "RemoteFwAdmin-In-TCP",
        "RemoteFwAdmin-RPCSS-In-TCP",
        "RemoteEventLogSvc-In-TCP",
        "RemoteEventLogSvc-NP-In-TCP",
        "RemoteEventLogSvc-RPCSS-In-TCP",
        "RemoteSvcAdmin-In-TCP",
        "RemoteSvcAdmin-NP-In-TCP",
        "RemoteSvcAdmin-RPCSS-In-TCP"
    );

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $credentialAdminDomain = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);

    Node $ComputerName
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        foreach($rule in $rules)
        {
            Firewall "$rule"
            {
                Name = "$rule"
                Ensure = "Present"
                Enabled = "True"
            }
        }

        Firewall "F-GceClusterHelper"
        {
            Name = "GceClusterHelper"
            DisplayName = "GCE Cluster helper"
            Ensure = "Present"
            Enabled = "True"
            Direction = "InBound"
            LocalPort = ("59998")
            Protocol = "TCP"
            Description = "Enables GCP Internal Load Balancer to check which node in the cluster is active to route traffic to the cluster IP."
        }

        WaitForADDomain "WFAD"
        {
            DomainName  = $($Parameters.domainName)
            Credential = $credentialAdminDomain
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $($Parameters.domainName)
            Credential = $credentialAdminDomain
            DependsOn = "[WaitForADDomain]WFAD"
        }

        Group "G-Administrators"
        {
            GroupName = "Administrators"
            Credential = $credentialAdminDomain
            MembersToInclude = $admins
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteDesktopUsers"
        {
            GroupName = "Remote Desktop Users"
            Credential = $credentialAdminDomain
            MembersToInclude = "$($Parameters.domainName)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $credentialAdminDomain
            MembersToInclude = "$($Parameters.domainName)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        if($Parameters.provisionCluster -ne $false)
        {
            if($Parameters.isFirst)
            {
                xCluster "CreateCluster"
                {
                    Name = "sofs-cl"
                    DomainAdministratorCredential = $credentialAdminDomain
                    StaticIPAddress = $Parameters.ipCluster
                    DependsOn = "[WindowsFeature]WF-Failover-clustering"
                }

                xClusterQuorum "Quorum"
                {
                    Type = "NodeMajority"
                    IsSingleInstance = "Yes"
                    DependsOn = "[xCluster]CreateCluster"
                }

                Script IncreaseClusterTimeouts
                {
                    GetScript = {
                        $cluster = Get-Cluster;
                        if($cluster.SameSubnetDelay -eq 2000 -and `
                            $cluster.SameSubnetThreshold -eq 15 -and `
                            $cluster.CrossSubnetDelay -eq 3000 -and `
                            $cluster.CrossSubnetThreshold -eq 15)
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
                        $cluster = Get-Cluster;
                        $cluster.SameSubnetDelay = 2000;
                        $cluster.SameSubnetThreshold = 15;
                        $cluster.CrossSubnetDelay = 3000;
                        $cluster.CrossSubnetThreshold = 15;
                    }
                    
                    DependsOn = "[xCluster]CreateCluster"
                }

                $nodes = @();
                for($i = 1; $i -lt $Parameters.nodeCount; $i++) {
                    $nodes += "$($Parameters.nodePrefix)-$i";
                };

                WaitForAll "ClusterJoin"
                {
                    ResourceName = "[xCluster]JoinNodeToCluster"
                    NodeName = $nodes
                    RetryIntervalSec = 20
                    RetryCount = 60
                    DependsOn = "[xCluster]CreateCluster"
                }

                Script EnableS2D
                {
                    GetScript = {
                        if((Get-ClusterS2D).State -eq "Enabled")
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
                        Enable-ClusterS2D -CollectPerformanceHistory $false -Confirm:0;
                    }
                    
                    DependsOn = "[WaitForAll]ClusterJoin"
                }

                Script CreateSofs
                {
                    GetScript = {
                        if((Get-ClusterGroup -Name "sofs" | Where-Object { $_.GroupType -eq "ScaleoutFileServer" }) -ne $Null)
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
                        Add-ClusterScaleOutFileServerRole -Name "sofs";
                    }
                    
                    DependsOn = "[Script]EnableS2D"
                }

                Script CreateVolume
                {
                    GetScript = {
                        if((Get-Volume -FriendlyName "sofs" -ErrorAction Ignore) -ne $Null)
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
                        New-Volume -FriendlyName "sofs" -StoragePoolFriendlyName "S2D on sofs-cl" -FileSystem CSVFS_ReFS -Size 50GB;
                    }
                    
                    DependsOn = "[Script]EnableS2D"
                }

                Script CreateShare
                {
                    GetScript = {
                        if((Get-SmbShare -Name "sofs" -ErrorAction Ignore) -ne $Null)
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
                        New-SmbShare -Name "sofs" -Path "C:\ClusterStorage\sofs" -CachingMode None -FolderEnumerationMode Unrestricted -ContinuouslyAvailable $true -FullAccess "sofs.lab\Domain Admins","sofs.lab\johndoe";
                    }
                    
                    DependsOn = "[Script]CreateVolume"
                }
            }
            else
            {
                xWaitForCluster "WFC-sofs-cl"
                {
                    Name = "sofs-cl"
                    RetryIntervalSec = 10
                    RetryCount = 60
                    DependsOn = "[WindowsFeature]WF-Failover-clustering"
                }

                xCluster "JoinNodeToCluster"
                {
                    Name = "sofs-cl"
                    DomainAdministratorCredential = $credentialAdminDomain
                    DependsOn = "[xWaitForCluster]WFC-sofs-cl"
                }
            }
        }
    }
}