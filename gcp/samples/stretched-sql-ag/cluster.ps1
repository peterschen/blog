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
        ComputerManagementDsc, ActiveDirectoryDsc, NetworkingDsc, 
        xFailOverCluster;

    $components = $Parameters.domainName.Split(".");
    $dc = "";
    foreach($component in $components)
    {
        if(-not [string]::IsNullOrEmpty($dc))
        {
            $dc += ",";
        }

        $dc += "dc=$component";
    }
    $ou = "ou=$($Parameters.domainName),$dc"

    $features = @(
        "Failover-clustering",
        "RSAT-Clustering-PowerShell",
        "RSAT-AD-PowerShell"
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
        "RemoteSvcAdmin-RPCSS-In-TCP",
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP"
    );

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);

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

        WaitForADDomain "WFAD"
        {
            DomainName  = $($Parameters.domainName)
            Credential = $domainCredential
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $($Parameters.domainName)
            Credential = $domainCredential
            DependsOn = "[WaitForADDomain]WFAD"
        }

        Group "G-Administrators"
        {
            GroupName = "Administrators"
            Credential = $domainCredential
            MembersToInclude = $admins
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteDesktopUsers"
        {
            GroupName = "Remote Desktop Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        if($Parameters.enableCluster -ne $false)
        {
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

            if($Parameters.isFirst)
            {
                ADComputer "PrestageClusterResource"
                {
                    ComputerName = "$($Parameters.nodePrefix)-cl"
                    EnabledOnCreation = $false
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[Computer]JoinDomain"
                }

                ADGroup "AddClusterResourceToGroup"
                {
                    GroupName = "g-ClusterResources"
                    GroupScope = "Global"
                    Ensure = "Present"
                    Path = "ou=Groups,$ou"
                    MembersToInclude = "$($Parameters.nodePrefix)-cl`$"
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[ADComputer]PrestageClusterResource"
                }
                
                xCluster "CreateCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    DomainAdministratorCredential = $domainCredential
                    StaticIPAddress = $Parameters.ipCluster
                    DependsOn = "[WindowsFeature]WF-Failover-clustering","[ADGroup]AddClusterResourceToGroup"
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
                    RetryIntervalSec = 5
                    RetryCount = 120
                    DependsOn = "[xCluster]CreateCluster"
                }
            }
            else
            {
                WaitForAll "WaitForCluster"
                {
                    ResourceName = "[xCluster]CreateCluster"
                    NodeName = "$($Parameters.nodePrefix)-0"
                    RetryIntervalSec = 5
                    RetryCount = 120
                    PsDscRunAsCredential = $domainCredential
                }

                xCluster "JoinNodeToCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    DomainAdministratorCredential = $domainCredential
                    DependsOn = "[WaitForAll]WaitForCluster"
                }
            }
        }
    }
}