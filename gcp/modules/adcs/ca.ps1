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
        ComputerManagementDsc, ActiveDirectoryDsc, NetworkingDsc, ActiveDirectoryCSDsc;

    $features = @(
        "ADCS-Cert-Authority",
        "ADCS-Online-Cert"
        "RSAT-AD-PowerShell",
        "RSAT-ADDS-Tools"
    );

    $rules = @(
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP",
        "IIS-WebServerRole-HTTP-In-TCP",
        "IIS-WebServerRole-HTTPS-In-TCP",
        "Microsoft-Windows-CertificateServices-CertSvc-RPC-NP-In",
        "Microsoft-Windows-CertificateServices-CertSvc-RPC-TCP-In",
        "Microsoft-Windows-CertificateServices-CertSvc-RPC-EPMAP-In",
        "Microsoft-Windows-CertificateServices-CertSvc-DCOM-In",
        "Microsoft-Windows-CertificateServices-CertSvc-TCP-Out"
    );

    $admins = @(
        "$($Parameters.nameDomain)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.nameDomain)\Administrator", $Password);

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
            DomainName  = $Parameters.nameDomain
            Credential = $domainCredential
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $Parameters.nameDomain
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
            MembersToInclude = "$($Parameters.nameDomain)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.nameDomain)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        AdcsCertificationAuthority "CertificateAuthority"
        {
            IsSingleInstance = "Yes"
            Ensure = "Present"
            Credential = $domainCredential
            CAType = "EnterpriseRootCA"
            CACommonName = "CA"
            DependsOn = "[WindowsFeature]WF-ADCS-Cert-Authority", "[Computer]JoinDomain"
        }

        AdcsOnlineResponder "OnlineResponder"
        {
            IsSingleInstance = "Yes"
            Ensure = "Present"
            Credential = $domainCredential
            DependsOn = "[AdcsCertificationAuthority]CertificateAuthority"
        }

        Script EnableWebServerTemplate
        {
            GetScript = {
                $filter = "(cn=WebServer)";
                $context = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$(([ADSI]"LDAP://RootDSE").configurationNamingContext)";
                $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$context", $filter);
                $template = $searcher.FindOne().GetDirectoryEntry();
                
                if ($template -ne $null)
                {
                    $domain = (Get-ADDomain).NetBIOSName;
                    $account = New-Object System.Security.Principal.NTAccount($domain, "Domain Computers");
                    $guid = [Guid]::Parse("0e10c968-78fb-11d2-90d4-00c04f79dc55");
                    
                    foreach($rule in $template.ObjectSecurity.Access)
                    {
                        if($rule.IdentityReference -eq $account)
                        {
                            if($rule.ObjectType -eq $guid)
                            {
                                Write-Verbose "TestScript: Enroll permissions for Domain Computers on WebServer template exists"
                                return @{Ensure = "Present"};
                            }
                        }
                    }
                }
                
                return @{Ensure = "Absent"};
            }

            TestScript = {
                $state = [scriptblock]::Create($GetScript).Invoke();
                return $state.Ensure -eq "Present";
            }

            SetScript = {
                $filter = "(cn=WebServer)";
                $context = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$(([ADSI]"LDAP://RootDSE").configurationNamingContext)";
                $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$context", $filter);
                $template = $searcher.FindOne().GetDirectoryEntry();
                
                if ($template -ne $null)
                {
                    $domain = (Get-ADDomain).NetBIOSName;
                    $account = New-Object System.Security.Principal.NTAccount($domain, "Domain Computers");
                    $guid = [Guid]::Parse("0e10c968-78fb-11d2-90d4-00c04f79dc55");
                    
                    $right = [System.DirectoryServices.ActiveDirectoryRights]"ExtendedRight";
                    $type = [System.Security.AccessControl.AccessControlType]"Allow";
                    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $account, $right, $type, $guid;
                    $template.ObjectSecurity.AddAccessRule($rule);
                    $template.CommitChanges();
                    
                    $dcs = (Get-ADDomainController -Filter *).Name;
                    foreach($dc in $dcs)
                    {
                        repadmin /syncall $dc (Get-ADDomain).DistinguishedName /e /A
                    }

                    Write-Verbose "SetScript: Set Enroll permissions for Domain Computers in WebServer template"
                }
            }
            
            PsDscRunAsCredential = $domainCredential
            DependsOn = "[AdcsCertificationAuthority]CertificateAuthority"
        }
    }
}
