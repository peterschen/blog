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
        ComputerManagementDsc, ActiveDirectoryDsc, xPSDesiredStateConfiguration,
        NetworkingDsc, xDnsServer, CertificateDsc;

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
        "RemoteSvcAdmin-RPCSS-In-TCP",
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP"
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
        @{Name = "Cloud Identity"; Path = "ou=Groups,$ou"},
        @{Name = "Accounts"; Path = $ou},
        @{Name = "Services"; Path = "ou=Accounts,$ou"},
        @{Name = "Users"; Path = "ou=Accounts,$ou"},
        @{Name = "Projects"; Path = $ou},
        @{Name = $Parameters.projectName; Path = "OU=Projects,$ou"}
    );

    $userJohndoe = @{Name = "johndoe"; Path = "ou=Users,ou=Accounts,$ou"; TrustedForDelegation = $false};
    $userAdjoiner = @{Name = "s-adjoiner"; Path = "ou=Services,ou=Accounts,$ou"; TrustedForDelegation = $false};
    $userAdfs = @{Name = "s-adfs"; Path = "ou=Services,ou=Accounts,$ou"; TrustedForDelegation = $false};
    $userSqlAgent = @{Name = "s-SqlAgent"; Path = "ou=Services,ou=Accounts,$ou"; TrustedForDelegation = $false};
    $userSqlEngine = @{Name = "s-SqlEngine"; Path = "ou=Services,ou=Accounts,$ou"; TrustedForDelegation = $false};

    $users = @(
        $userJohndoe,
        $userAdjoiner,
        $userAdfs,
        $userSqlAgent,
        $userSqlEngine
    );

    $groups = @(
        @{Name = "g-DirectorySync"; Path = "$ou"; Members = @()},
        @{Name = "g-LocalAdmins"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
        @{Name = "g-RemoteDesktopUsers"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
        @{Name = "g-RemoteManagementUsers"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
        @{Name = "g-DistributedComUsers"; Path = "ou=Groups,$ou"; Members = @("$($Parameters.domainName)\Administrator", "$($userJohndoe.Name)")}
        @{Name = "g-ClusterResources"; Path = "ou=Groups,$ou"; Members = @()}
        @{Name = "g-IisUsers"; Path = "ou=Groups,$ou"; Members = @()}
        @{Name = "g-CloudSqlAdmins"; Path = "ou=Groups,$ou"; Members = @("$($userJohndoe.Name)")}
    );

    $builtinGroups = @(
        @{Name = "Administrators"; Members =@("g-LocalAdmins")},
        @{Name = "Remote Desktop Users"; Members =@("g-RemoteDesktopUsers")}
        @{Name = "Remote Management Users"; Members =@("g-RemoteManagementUsers")}
        @{Name = "Distributed COM Users"; Members =@("g-DistributedComUsers")}
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

            ADReplicationSite "ReplicationSite-$($Parameters.region)"
            {
                Ensure = "Present"
                Name = "$($Parameters.region)"
                RenameDefaultFirstSiteName = $Parameters.isFirst
                DependsOn = "[ADDomain]AD-CreateDomain"
            }

            ADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.region
                Location = "GCP"
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.region)"
            }

            $ous | ForEach-Object {
                ADOrganizationalUnit "ADOU-$($_.Name)"
                {
                    Name = $_.Name
                    Path = $_.Path
                    Ensure = "Present"
                    DependsOn = "[ADDomain]AD-CreateDomain"
                }
            }

            $users | ForEach-Object {
                ADUser "ADU-$($_.Name)"
                {
                    DomainName = $Parameters.domainName
                    UserPrincipalName = "$($_.Name)@$($Parameters.domainName)"
                    UserName = $_.Name
                    Password = $credentialAdmin
                    PasswordNeverExpires = $true
                    Ensure = "Present"
                    TrustedForDelegation = $_.TrustedForDelegation
                    Path = $_.Path
                    PsDscRunAsCredential = $credentialAdminDomain
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
                    PsDscRunAsCredential = $credentialAdminDomain
                    DependsOn = "[ADUser]ADU-johndoe"
                }
            }

            $builtinGroups | ForEach-Object {
                ADGroup "ADG-dc-0-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    PsDscRunAsCredential = $credentialAdminDomain
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

            xDnsServerSetting "DnsForwarders"
            {
                DnsServer = "localhost"
                Forwarders = "8.8.8.8", "8.8.4.4"
                DependsOn = "[ADDomain]AD-CreateDomain"
            }

            Script SetAdjoinerPermissions
            {
                GetScript = {
                    $dn = "OU=Projects,$($using:ou)";
                    $acl = (Get-Acl -Path "ad:$dn").Access | Where-Object {$_.IdentityReference.Value.Contains($using:userAdjoiner.Name)};
                    
                    if($acl.Count -eq 16)
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
                    $dn = "OU=Projects,{0}" -f $using:ou;
                    $upn = (Get-ADUser -Identity $using:userAdjoiner.Name).UserPrincipalName;
                    
                    & dsacls.exe $dn /G "$($upn):CCDC;Computer" /I:T | Out-Null;
                    & dsacls.exe $dn /G "$($upn):LC;;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):RC;;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WD;;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WP;;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):RP;;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):CA;Reset Password;Computer" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):CA;Change Password;Computer" /I:S | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WS;Validated write to service principal name;Computer" /I:S | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WS;Validated write to DNS host name;Computer" /I:S | Out-Null;
                    & dsacls.exe $dn /G "$($upn):CCDC;Group" /I:T | Out-Null;
                    & dsacls.exe $dn /G "$($upn):LC;;Group" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):RC;;Group" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WD;;Group" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):WP;;Group" /I:S  | Out-Null;
                    & dsacls.exe $dn /G "$($upn):RP;;Group" /I:S  | Out-Null;   
                }
                
                DependsOn = "[ADOrganizationalUnit]ADOU-Projects"
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
                WaitTimeout = 600
                RestartCount = 2
            }

            ADDomainController 'ADC-DC'
            {
                DomainName = $Parameters.domainName
                Credential = $credentialAdminDomain
                SafemodeAdministratorPassword = $credentialAdminDomain
                DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
            }

            ADReplicationSite "ReplicationSite-$($Parameters.region)"
            {
                Ensure = "Present"
                Name = $Parameters.region
                RenameDefaultFirstSiteName = $Parameters.isFirst
                DependsOn = "[ADDomainController]ADC-DC"
            }

            ADReplicationSiteLink "DefaultReplicationSiteLink"
            {
                Ensure = "Present"
                Name = "DEFAULTIPSITELINK"
                SitesIncluded = $Parameters.regions
                ReplicationFrequencyInMinutes = 15
                OptionChangeNotification = $true
                OptionTwoWaySync = $true
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.region)"
            }

            ADReplicationSubnet "ReplicationSubnet-$($Parameters.networkRange)"
            {
                Name = "$($Parameters.networkRange)"
                Site = $Parameters.region
                Location = "GCP"
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.region)"
            }

            $builtinGroups | ForEach-Object {
                ADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($Parameters.domainName)"
                    PsDscRunAsCredential = $credentialAdminDomain
                    DependsOn = "[ADDomainController]ADC-DC"
                }
            }

            Script MoveDc
            {
                GetScript = {
                    if((Get-ADDomainController -Server $using:Node.NodeName).Site -eq $using:Parameters.region)
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
                    Get-ADDomainController -Identity "$($using:Node.NodeName).$($using:Parameters.domainName)" | Move-ADDirectoryServer -Site $using:Parameters.region;
                }
                
                DependsOn = "[ADReplicationSite]ReplicationSite-$($Parameters.region)"
            }
        }

        File "Share"
        {
            DestinationPath = "C:\share"
            Type = "Directory"
        }

        SmbShare "Share"
        {
            Name = "Share"
            Path = "C:\share"
            EncryptData = $false
            FolderEnumerationMode = "Unrestricted"
            CachingMode = "None"
            ContinuouslyAvailable = $false
            FullAccess = @(
                "$($Parameters.domainName)\Domain Computers",
                "$($Parameters.domainName)\Domain Admins",
                "$($Parameters.domainName)\s-SqlEngine"
            )
            
            DependsOn = "[File]Share"
        }

        if($Parameters.enableSsl)
        {
            WaitForCertificateServices "WaitForCa"
            {
                CARootName = "CA"
                CAServerFQDN = "ca.$($Parameters.domainName)"
                DependsOn = "[WaitForADDomain]WFAD-CreateDomain"
            }

            Script EnableSsl
            {
                GetScript = {
                    $certificates = Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$($using:Parameters.NodeName).$($using:Parameters.DomainName)" };
                    if($null -ne $certificates -and $certificates.Length -gt 0)
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
                    # Updating Group Policy will trigger automatic request of Domain Controller certificate
                    gpupdate /force
                }
                
                DependsOn = "[WaitForCertificateServices]WaitForCa"
            }
        }
    }
}