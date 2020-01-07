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

            xClusterProperty "IncreaseClusterTimeouts"
            {
                SameSubnetDelay = 2000
                SameSubnetThreshold = 15
                CrossSubnetDelay = 3000
                CrossSubnetThreshold = 15
                DependsOn = "[xCluster]CreateCluster"
            }

            $nodes = @();
            for($i = 1; $i -gt $Parameters.nodeCount; $i++) {
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
                SetScript = "Enable-ClusterS2D -Confirm:0;"
                TestScript = "(Get-ClusterS2D).S2DEnabled -eq 1"
                GetScript = "@{Ensure = if ((Get-ClusterS2D).S2DEnabled -eq 1) {'Present'} else {'Absent'}}"
                DependsOn = "[WaitForAll]ClusterJoin"
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