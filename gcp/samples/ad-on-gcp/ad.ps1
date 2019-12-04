configuration ConfigurationAD
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [securestring] $Password,

	    [int] $RetryCount = 20,
        [int] $RetryInterval = 30
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        xActiveDirectory, xPSDesiredStateConfiguration, NetworkingDsc;

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

    $components = $DomainName.Split(".");
    $dc = "";
    foreach($component in $components)
    {
        if(-not [string]::IsNullOrEmpty($dc))
        {
            $dc += ",";
        }

        $dc += "dc=$component";
    }
    $ou = "ou=$DomainName,$dc"
    
    $ous = @(
        @{Name = $DomainName; Path = $dc},
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

        xADDomain "AD-FirstDC"
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
		    DependsOn = "[WindowsFeature]WF-AD-Domain-Services"
        }

        xWaitForADDomain "WFAD-FirstDC"
        {
            DomainName = $DomainName
            DomainUserCredential = $domainCredential
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryInterval
            DependsOn = "[xADDomain]AD-FirstDC"
        }

        $ous | ForEach-Object {
            xADOrganizationalUnit "ADOU-$($_.Name)"
            {
                Name = $_.Name
                Path = $_.Path
                Ensure = "Present"
                DependsOn = "[xWaitForADDomain]WFAD-FirstDC"
            }
        }

        $users | ForEach-Object {
            xADUser "ADU-$($_.Name)"
            {
                DomainName = $DomainName
                UserPrincipalName = "$($_.Name)@$($DomainName)"
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
                DomainController = "$($Node.NodeName).$($DomainName)"
                DependsOn = "[xADUser]ADU-johndoe"
            }
        }

        $builtinGroups | ForEach-Object {
            xADGroup "ADG-$($_.Name)"
            {
                GroupName = $_.Name
                GroupScope = "DomainLocal"
                Ensure = "Present"
                Path = $_.Path
                MembersToInclude = $_.Members
                DomainController = "$($Node.NodeName).$($DomainName)"
                DependsOn = "[xADGroup]ADG-g-LocalAdmins", "[xADGroup]ADG-g-RemoteDesktopUsers", "[xADGroup]ADG-g-RemoteManagementUsers"
            }
        }
    }
}