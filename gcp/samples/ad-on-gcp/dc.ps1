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
        xActiveDirectory, xPSDesiredStateConfiguration, NetworkingDsc, xDnsServer;

    $features = @(
        "AD-Domain-Services"
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
    
    $ous = @(
        @{Name = $Parameters.domainName; Path = $dc},
        @{Name = "Groups"; Path = $ou},
        @{Name = "Accounts"; Path = $ou},
        @{Name = "Services"; Path = "ou=Accounts,$ou"},
        @{Name = "Users"; Path = "ou=Accounts,$ou"}
    );

    $userJohndoe = @{Name = "johndoe"; Path = "ou=Users,ou=Accounts,$ou"};

    $users = @(
        $userJohndoe
    );

    $groups = @(
        @{Name = "g-LocalAdmins"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
        @{Name = "g-RemoteDesktopUsers"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
        @{Name = "g-RemoteManagementUsers"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
    );

    $builtinGroups = @(
        @{Name = "Administrators"; Members =@("g-LocalAdmins")},
        @{Name = "Remote Desktop Users"; Members =@("g-RemoteDesktopUsers")}
        @{Name = "Remote Management Users"; Members =@("g-RemoteManagementUsers")}
    );
    
    $domainCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $Password);

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

        if($Parameters.isFirst)
        {
            # This configuration is applied to the first DC
            # in the domain and will setup the AD, add some
            # user groups

            xADDomain "AD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                DomainAdministratorCredential = $domainCredential
                SafemodeAdministratorPassword = $domainCredential
                DependsOn = "[WindowsFeature]WF-AD-Domain-Services"
            }

            xWaitForADDomain "WFAD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                DomainUserCredential = $domainCredential
                RetryCount = 30
                RetryIntervalSec = 10
                DependsOn = "[xADDomain]AD-CreateDomain"
            }

            xADReplicationSite "ReplicationSite-$($Parameters.zone)"
            {
                Ensure = "Present"
                Name = "$($Parameters.zone)"
                RenameDefaultFirstSiteName = $false
                DependsOn = "[xWaitForADDomain]WFAD-CreateDomain"
            }

            xADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.zone
                Location = "GCP"
                DependsOn = "[xADReplicationSubnet]ReplicationSite-$($Parameters.zone)"
            }

            $ous | ForEach-Object {
                xADOrganizationalUnit "ADOU-$($_.Name)"
                {
                    Name = $_.Name
                    Path = $_.Path
                    Ensure = "Present"
                    DependsOn = "[xWaitForADDomain]WFAD-CreateDomain"
                }
            }

            $users | ForEach-Object {
                xADUser "ADU-$($_.Name)"
                {
                    DomainName = $Parameters.domainName
                    UserPrincipalName = "$($_.Name)@$($Parameters.domainName)"
                    DomainAdministratorCredential = $domainCredential
                    UserName = $_.Name
                    Password = $domainCredential
                    PasswordNeverExpires = $true
                    Ensure = "Present"
                    Path = $_.Path
                    DependsOn = "[xADOrganizationalUnit]ADOU-Services","[xADOrganizationalUnit]ADOU-Users"
                }
            }
    
            $groups | ForEach-Object {
                xADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "Global"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[xADUser]ADU-johndoe"
                }
            }

            $builtinGroups | ForEach-Object {
                xADGroup "ADG-dc-0-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[xADGroup]ADG-g-LocalAdmins", "[xADGroup]ADG-g-RemoteDesktopUsers", "[xADGroup]ADG-g-RemoteManagementUsers"
                }
            }

            xDnsServerSetting "DSS-DnsConfiguration"
            { 
                Name = "dns-server-forwarders"
                Forwarders = "8.8.8.8", "8.8.4.4"
                DependsOn = "[xWaitForADDomain]WFAD-CreateDomain"
            }
        }
        else
        {
            # This configuration is applied to subsequent DCs
            # and will wait until the domain is created before
            # adding an additional DC.

            xWaitForADDomain "WFAD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                DomainUserCredential = $domainCredential
                RetryCount = 30
                RetryIntervalSec = 10
            }

            xADDomainController 'ADC-DC'
            {
                DomainName = $Parameters.domainName
                DomainAdministratorCredential = $domainCredential
                SafemodeAdministratorPassword = $domainCredential
                DependsOn = "[xWaitForADDomain]WFAD-CreateDomain"
            }

            xADReplicationSite "ReplicationSite-$($Parameters.zone)"
            {
                Ensure = "Present"
                Name = "$($Parameters.zone)"
                RenameDefaultFirstSiteName = $false
                DependsOn = "[xADDomainController]ADC-DC"
            }

            xADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.zone
                Location = "GCP"
                DependsOn = "[xADReplicationSubnet]ReplicationSite-$($Parameters.zone)"
            }

            $builtinGroups | ForEach-Object {
                xADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[xADDomainController]ADC-DC"
                }
            }
        }
    }
}