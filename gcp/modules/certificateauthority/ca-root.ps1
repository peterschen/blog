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
        ComputerManagementDsc, ActiveDirectoryDsc, ActiveDirectoryCSDsc;

    $features = @(
        "ADCS-Cert-Authority",
        "ADCS-Online-Cert"
        "RSAT-ADCS"
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
    }
}
