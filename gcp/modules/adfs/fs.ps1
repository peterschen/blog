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
        ComputerManagementDsc, ActiveDirectoryDsc, CertificateDsc, AdfsDsc;

    $features = @(
        "ADFS-Federation"
    );

    $rules = @(
    );

    $admins = @(
        "$($Parameters.nameDomain)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.nameDomain)\Administrator", $Password);
    $adfsCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.nameDomain)\s-adfs", $Password);

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

        WaitForCertificateServices "WaitForCa"
        {
            CARootName = "CA"
            CAServerFQDN = "ca.${$Parameters.nameDomain}"
            DependsOn = "[WaitForADDomain]WFAD"
        }

        Script UpdateGroupPolicies
        {
            GetScript = {
                return @{Ensure = "Absent"};
            }

            TestScript = {
                $state = [scriptblock]::Create($GetScript).Invoke();
                return $state.Ensure -eq "Present";
            }

            SetScript = {
                gpupdate /force
            }

            PsDscRunAsCredential = $domainCredential
            DependsOn = "[WaitForCertificateServices]WaitForCa"
        }

        CertReq "Certificate"
        {
            Subject = "$ComputerName.$($Parameters.nameDomain)"
            SubjectAltName = "dns=fs.$($Parameters.nameDomain)&dns=certauth.fs.$($Parameters.nameDomain)&dns=$($Parameters.nameDomain)"
            Exportable = $true
            CertificateTemplate = "WebServer"
            AutoRenew = $true
            UseMachineContext = $true
            DependsOn = "[Script]UpdateGroupPolicies"
        }

        Script InstallAdfs
        {
            GetScript = {
                if((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ADFS").FSConfigurationStatus -eq 2)
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
                $domain = $($using:Parameters.nameDomain);
                $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$($using:ComputerName).$domain"};
                Install-AdfsFarm -CertificateThumbprint $certificate.Thumbprint -FederationServiceName "$($using:ComputerName).$domain" `
                    -ServiceAccountCredential $using:adfsCredential -FederationServiceDisplayName "$domain ADFS";

                # Set DSC reboot flag
                $global:DSCMachineStatus = 1;
            }
            
            PsDscRunAsCredential = $domainCredential
            DependsOn = "[CertReq]Certificate"
        }

        AdfsRelyingPartyTrust CloudIdentity
        {
            Name = "Cloud Identity"
            Enabled = $true
            Notes = "Cloud Identity federation"
            SamlEndpoint = @(
                MSFT_AdfsSamlEndpoint
                {
                    Binding = "POST"
                    Index = 0
                    IsDefault = $false
                    Protocol = "SAMLAssertionConsumer"
                    Uri = "https://www.google.com/a/$($Parameters.cloudIdentityDomain)/acs"
                }
                MSFT_AdfsSamlEndpoint
                {
                    Binding = "POST"
                    Index = 0
                    IsDefault = $false
                    Protocol = "SAMLLogout"
                    Uri = "https://$ComputerName.$($Parameters.nameDomain)/adfs/ls/?wa=wsignout1.0"
                }
            )
            Identifier = @(
                "google.com",
                "google.com/a/$($Parameters.cloudIdentityDomain)"
            )
            AccessControlPolicyName = "Permit Everyone"
            IssuanceTransformRules  = @(
                MSFT_AdfsIssuanceTransformRule
                {
                    TemplateName = 'CustomClaims'
                    Name = 'Load UPN'
                    CustomRule = 'c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname", Issuer == "AD AUTHORITY"]
                        => add(store = "Active Directory", types = ("http://temp.google.com/upn"), query = ";userPrincipalName;{0}", param = c.Value);'
                }
                MSFT_AdfsIssuanceTransformRule
                {
                    TemplateName = 'CustomClaims'
                    Name = 'Transform UPN'
                    CustomRule = 'c:[Type == "http://temp.google.com/upn"]
                        => issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", Value = RegexReplace(c.Value, "@(.*?)$", "@' + $($Parameters.cloudIdentityDomain) + '"));'
                }
            )
            
            DependsOn = "[Script]InstallAdfs"
        }
    }
}
