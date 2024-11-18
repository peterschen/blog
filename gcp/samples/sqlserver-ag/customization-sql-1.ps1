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

    SqlProtocol "SqlProtocol"
    {
        InstanceName = "MSSQLSERVER"
        ProtocolName = "TcpIp"
        Enabled = $true
        ListenOnAllIpAddresses = $true
        DependsOn = "[SqlSetup]SqlServerSetup"
    }

    SqlProtocolTcpIp "SqlProtocolTcpIp"
    {
        InstanceName = "MSSQLSERVER"
        IpAddressGroup = "IPAll"
        TcpPort = 1433
        DependsOn = "[SqlProtocol]SqlProtocol"
    }

    SqlScriptQuery "SetServerName"
    {
        Id = "SetServerName"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Encrypt = "Optional"

        TestQuery = @"
IF (SELECT @@SERVERNAME) != $($Node.NodeName)
BEGIN
RAISERROR ('Server name is not set correctly', 16, 1)
END
ELSE
BEGIN
PRINT 'Server name is set correctly'
END
"@
        GetQuery = "SELECT @@SERVERNAME"
        SetQuery = @"
sp_dropserver @@SERVERNAME;
GO

sp_addserver '$($Node.NodeName)', local;
GO
"@;
        Variable = @("FilePath=C:\windows\temp\SetServerMame")

        DependsOn = "[SqlProtocolTcpIp]SqlProtocolTcpIp"
        PsDscRunAsCredential = $Credential
    }

    SqlServiceAccount "EngineAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "DatabaseEngine"
        ServiceAccount = $engineCredential
        RestartService = $false

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }

    SqlServiceAccount "AgentAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "SQLServerAgent"
        ServiceAccount = $agentCredential
        RestartService = $true

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }

    SqlLogin "AddNTServiceClusSvc"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Name = "NT SERVICE\ClusSvc"
        LoginType = "WindowsUser"

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }

    SqlScriptQuery "SetClusterPermission"
    {
        Id = "SetClusterPermission"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"

        TestQuery = "RAISERROR ('Always false', 16, 1)"
        GetQuery = "SELECT 'false' AS result"
        SetQuery = @"
GRANT ALTER ANY AVAILABILITY GROUP TO [NT SERVICE\ClusSvc]
GRANT VIEW SERVER STATE TO [NT SERVICE\ClusSvc]
GO
"@;
        Variable = @("FilePath=C:\windows\temp\SetClusterPermission")

        DependsOn = "[SqlLogin]AddNTServiceClusSvc"
        PsDscRunAsCredential = $Credential
    }

    SqlAlwaysOnService "EnableAlwaysOn"
    {
        Ensure = "Present"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"

        DependsOn = "[SqlScriptQuery]SetServerName", "[SqlServiceAccount]EngineAccount"
        PsDscRunAsCredential = $Credential
    }

    SqlLogin "EngineAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Name = "$($Parameters.domainName.Split(".")[0])\$($engineCredential.UserName.Split("\")[1])"
        LoginType = "WindowsUser"
        PsDscRunAsCredential = $Credential
    }

    SqlEndpoint "CreateEndpoint"
    {
        EndpointName = "AdventureWorks"
        EndpointType = "DatabaseMirroring"
        InstanceName = "MSSQLSERVER"

        DependsOn = "[SqlAlwaysOnService]EnableAlwaysOn"
        PsDscRunAsCredential = $Credential
    }

    SqlEndpointPermission "EndpointPermission"
    {
        Ensure = "Present"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Name = "AdventureWorks"
        Principal = "$($Parameters.domainName.Split(".")[0])\$($engineCredential.UserName.Split("\")[1])"
        Permission = "CONNECT"

        DependsOn = "[SqlEndpoint]CreateEndpoint"
        PsDscRunAsCredential = $Credential
    }
}