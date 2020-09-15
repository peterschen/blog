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
        ComputerManagementDsc, ActiveDirectoryDsc, SqlServerDsc;

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

    $features = @(
        "RSAT-AD-PowerShell"
    );

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-sql-agent)", $Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-sql-engine)", $Password);

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

        WaitForADDomain "WFAD"
        {
            DomainName  = $Parameters.domainName
            Credential = $domainCredential
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $Parameters.domainName
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
            MembersToInclude = "$($Parameters.domainName)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        ADUser "ServiceSqlEngine"
        {
            DomainName = $Parameters.domainName
            UserPrincipalName = "s-sql-engine@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-sql-engine"
            Password = $domainCredential
            PasswordNeverExpires = $true
            Ensure = "Present"
            Path = "ou=Services,ou=Accounts,$ou"
        }

        ADUser "ServiceSqlAgent"
        {
            DomainName = $Parameters.domainName
            UserPrincipalName = "s-sql-agent@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-sql-agent"
            Password = $domainCredential
            PasswordNeverExpires = $true
            Ensure = "Present"
            Path = "ou=Services,ou=Accounts,$ou"
        }

        ADGroup "SqlAdministrators"
        {
            GroupName = "g-SqlAdministrators"
            GroupScope = "Global"
            Ensure = "Present"
            Path = "ou=Groups,$ou"
            MembersToInclude = @("johndoe")
            Credential = $domainCredential
        }

        SqlSetup "SqlServerSetup"
        {
            SourcePath = "C:\sql_server_install"
            Features = "SQLENGINE,FULLTEXT"
            InstanceName = "MSSQLSERVER"
            SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
            SQLSvcAccount = $engineCredential
            AgtSvcAccount = $agentCredential
            DependsOn = "[ADUser]ServiceSqlEngine","[ADUser]ServiceSqlAgent","[ADGroup]SqlAdministrators"
        }

        SqlWindowsFirewall "SqlServerFirewall"
        {
            SourcePath = "C:\sql_server_install"
            InstanceName = "MSSQLSERVER"
            Features = "SQLENGINE,FULLTEXT"
            DependsOn = "[SqlSetup]SqlServerSetup"
        }
    }
}
