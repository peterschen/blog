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
            xCluster CreateCluster
            {
                Name = 'sofs-cl'
                DomainAdministratorCredential = $credentialAdminDomain
                StaticIPAddress = $Parameters.ipCluster
                DependsOn = '[WindowsFeature]WF-Failover-clustering'
            }
        }
        else
        {
            xWaitForCluster "WFC-sofs-cl"
            {
                Name = "sofs-cl"
                DomainAdministratorCredential = $credentialAdminDomain
                RetryIntervalSec = 10
                RetryCount = 60
                DependsOn = '[WindowsFeature]WF-Failover-clustering'
            }

            xCluster JoinSecondNodeToCluster
            {
                Name = "sofs-cl"
                DomainAdministratorCredential = $domainCredential
                DependsOn = '[xWaitForCluster]WFC-sofs-cl'
            }
        }
    }
}