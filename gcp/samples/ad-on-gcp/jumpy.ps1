configuration ConfigurationWorkload
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [securestring] $Password
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        ComputerManagementDsc;

    $features = @(
        "RSAT-ADDS"
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
        "$DomainName\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$DomainName\Administrator", $Password);

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
            DomainName  = $DomainName
            WaitTimeout = 300
            Restart = 2
            PsDscRunAsCredential = $domainCredential
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $DomainName
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
            MembersToInclude = "$DomainName\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$DomainName\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }
    }
}