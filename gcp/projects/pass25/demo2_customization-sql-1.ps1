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
        SqlServerDsc;

    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Credential.Password);

    WaitForAll "SqlServerSetup"
    {
        ResourceName = "[SqlSetup]SqlServerSetup::[Customization]Customization"
        NodeName = "$($Parameters.nodePrefix)-0"
        RetryIntervalSec = 5
        RetryCount = 120
    }

    SqlSetup "SqlServerSetup"
    {
        Action = "AddNode"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        FailoverClusterNetworkName = $Parameters.nodePrefix
        FailoverClusterIPAddress = $Parameters.ipSql

        SkipRule = "Cluster_VerifyForErrors"

        PsDscRunAsCredential = $Credential
        DependsOn = "[WaitForAll]SqlServerSetup"
    }

    SqlScriptQuery "CreateDatabase"
    {
        Id = "CreateDatabase"
        ServerName = "sql"
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'pass') = 0
BEGIN
    RAISERROR ('Did not find database [pass]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [pass]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'pass'"
        SetQuery = @"
CREATE DATABASE [pass]
ON (
    NAME = pass,
    FILENAME = 'C:\ClusterStorage\Volume1\MSSQL16.MSSQLSERVER\pass.mdf'
)
LOG ON (
    NAME = pass_log,
    FILENAME = 'C:\ClusterStorage\Volume1\MSSQL16.MSSQLSERVER\pass.ldf'
);
GO
"@;
        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }
}