configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        ActiveDirectoryDsc, SqlServerDsc;

    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Credential.Password);

    SqlSetup "SqlServerSetup"
    {
        Action = "INSTALL"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        SkipRule = "Cluster_VerifyForErrors"

        PsDscRunAsCredential = $Credential
    }

    ADServicePrincipalName "SetSpnHostname"
    {
        ServicePrincipalName = "MSSQLSvc/$($Node.NodeName):1433"
        Account = "s-SqlEngine"
        PsDscRunAsCredential = $Credential
    }

    ADServicePrincipalName "SetSpnFqdn"
    {
        ServicePrincipalName = "MSSQLSvc/$($Node.NodeName).$($Parameters.domainName):1433"
        Account = "s-SqlEngine"
        PsDscRunAsCredential = $Credential
    }

    SqlAlwaysOnService "EnableAlwaysOn"
    {
        Ensure = "Present"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }

    SqlServiceAccount "EngineAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "DatabaseEngine"
        ServiceAccount = $engineCredential
        RestartService = $true

        DependsOn = "[ADServicePrincipalName]SetSpnHostname", "[ADServicePrincipalName]SetSpnFqdn", "[SqlAlwaysOnService]EnableAlwaysOn"
        PsDscRunAsCredential = $Credential
    }

    SqlServiceAccount "AgentAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "SQLServerAgent"
        ServiceAccount = $agentCredential
        RestartService = $true

        DependsOn = "[SqlAlwaysOnService]EnableAlwaysOn"
        PsDscRunAsCredential = $Credential
    }

    SqlScriptQuery "ConfigureEndpointPermission"
    {
        Id = "ConfigureEndpointPermission"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
SELECT 'true' AS result
"@
        GetQuery = "SELECT 'true' AS result"
        SetQuery = @"
USE [master];
CREATE LOGIN [$($engineCredential.UserName)] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$($engineCredential.UserName)];
GO
"@;
        Variable = @("FilePath=C:\windows\temp\configureendpoints")
        
        DependsOn = "[Script]DownloadAdventurWorks2016"
        PsDscRunAsCredential = $Credential
    }
}