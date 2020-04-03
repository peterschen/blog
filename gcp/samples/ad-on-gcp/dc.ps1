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
        ActiveDirectoryDsc, xPSDesiredStateConfiguration, NetworkingDsc, xDnsServer;

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
        @{Name = "g-ClusterResources"; Path = "ou=Groups,$ou"; Members = @())}
    );

    $builtinGroups = @(
        @{Name = "Administrators"; Members =@("g-LocalAdmins")},
        @{Name = "Remote Desktop Users"; Members =@("g-RemoteDesktopUsers")}
        @{Name = "Remote Management Users"; Members =@("g-RemoteManagementUsers")}
    );
    
    $credentialAdmin = New-Object System.Management.Automation.PSCredential ("Administrator", $Password);
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

        if($Parameters.isFirst)
        {
            # This configuration is applied to the first DC
            # in the domain and will setup the AD, add some
            # user groups

            ADDomain "AD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                Credential = $credentialAdmin
                SafemodeAdministratorPassword = $credentialAdmin
                DependsOn = "[WindowsFeature]WF-AD-Domain-Services"
            }

            WaitForADDomain "WFAD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                Credential = $credentialAdminDomain
                DependsOn = "[ADDomain]AD-CreateDomain"
            }

            ADReplicationSite "ReplicationSite-$($Parameters.zone)"
            {
                Ensure = "Present"
                Name = "$($Parameters.zone)"
                RenameDefaultFirstSiteName = $Parameters.isFirst
                DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
            }

            ADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.zone
                Location = "GCP"
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.zone)"
            }

            $ous | ForEach-Object {
                ADOrganizationalUnit "ADOU-$($_.Name)"
                {
                    Name = $_.Name
                    Path = $_.Path
                    Ensure = "Present"
                    DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
                }
            }

            $users | ForEach-Object {
                ADUser "ADU-$($_.Name)"
                {
                    DomainName = $Parameters.domainName
                    UserPrincipalName = "$($_.Name)@$($Parameters.domainName)"
                    Credential = $credentialAdminDomain
                    UserName = $_.Name
                    Password = $credentialAdmin
                    PasswordNeverExpires = $true
                    Ensure = "Present"
                    Path = $_.Path
                    DependsOn = "[ADOrganizationalUnit]ADOU-Services","[ADOrganizationalUnit]ADOU-Users"
                }
            }
    
            $groups | ForEach-Object {
                ADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "Global"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[ADUser]ADU-johndoe"
                }
            }

            $builtinGroups | ForEach-Object {
                ADGroup "ADG-dc-0-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[ADGroup]ADG-g-LocalAdmins", "[ADGroup]ADG-g-RemoteDesktopUsers", "[ADGroup]ADG-g-RemoteManagementUsers"
                }
            }

            ADObjectPermissionEntry "ClusterGroupPermissions"
            {
                Path = "ou=Groups,$ou"
                IdentityReference = "g-ClusterResources"
                ActiveDirectoryRights = "GenericRead", "CreateChild", "DeleteChild"
                AccessControlType = "Allow"
                ObjectType = "bf967a86-0de6-11d0-a285-00aa003049e2"
                ActiveDirectorySecurityInheritance = "All"
                InheritedObjectType = "00000000-0000-0000-0000-000000000000"
                PsDscRunAsCredential = $credentialAdminDomain
                DependsOn = "[ADGroup]ADG-g-ClusterResources"
            }

            xDnsServerSetting "DSS-DnsConfiguration"
            { 
                Name = "dns-server-forwarders"
                Forwarders = "8.8.8.8", "8.8.4.4"
                DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
            }
        }
        else
        {
            # This configuration is applied to subsequent DCs
            # and will wait until the domain is created before
            # adding an additional DC.

            WaitForADDomain "WFAD-CreateDomain"
            {
                DomainName = $Parameters.domainName
                Credential = $credentialAdminDomain
                RestartCount = 2
            }

            ADDomainController 'ADC-DC'
            {
                DomainName = $Parameters.domainName
                Credential = $credentialAdminDomain
                SafemodeAdministratorPassword = $credentialAdminDomain
                DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
            }

            ADReplicationSite "ReplicationSite-$($Parameters.zone)"
            {
                Ensure = "Present"
                Name = "$($Parameters.zone)"
                RenameDefaultFirstSiteName = $Parameters.isFirst
                DependsOn = "[ADDomainController]ADC-DC"
            }

            ADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.zone
                Location = "GCP"
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.zone)"
            }

            $builtinGroups | ForEach-Object {
                ADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    DependsOn = "[ADDomainController]ADC-DC"
                }
            }
        }
    }
}