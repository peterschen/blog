
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
        Encrypt = "Optional"

        TestQuery = "RAISERROR ('Always false', 16, 1)"
        GetQuery = "SELECT 'false' AS result"
        SetQuery = @"
GRANT ALTER ANY AVAILABILITY GROUP TO [NT SERVICE\ClusSvc]
GRANT VIEW SERVER STATE TO [NT SERVICE\ClusSvc]
GO
"@;
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

    SqlAG "CreateAvailabilityGroup"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Name = "AdventureWorks"
        AvailabilityMode = "SynchronousCommit"
        FailoverMode = "Automatic"
        SeedingMode = "Manual"
        EndpointHostName = "$($Node.NodeName).$($Parameters.domainName)"
        AutomatedBackupPreference = "Secondary"

        DependsOn = "[SqlEndpointPermission]EndpointPermission"
        PsDscRunAsCredential = $Credential
    }

    SqlAGListener "AddListener"
    {
        Ensure = "Present"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        AvailabilityGroup = "AdventureWorks"
        Name = "AdventureWorks"
        IpAddress = "$($Parameters.ipSql)/$($Parameters.networkMask)"
        Port = 1433

        DependsOn = "[SqlAG]CreateAvailabilityGroup"
        PsDscRunAsCredential = $Credential
    }

    Script "DownloadAdventurWorks"
    {
        GetScript = {
            $path  = Join-Path -Path "C:\data" -ChildPath "AdventureWorks2016.bak";
            if((Test-Path -Path $path))
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
            $path  = Join-Path -Path "C:\data" -ChildPath "AdventureWorks2016.bak";
            Start-BitsTransfer -Source "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2016.bak" -Destination $path;
        }

        PsDscRunAsCredential = $Credential
    }

    SqlScriptQuery "RestoreDatabase"
    {
        Id = "RestoreDatabase"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        Encrypt = "Optional"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'AdventureWorks') = 0
BEGIN
    RAISERROR ('Did not find database [AdventureWorks]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [AdventureWorks]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'AdventureWorks'"
        SetQuery = @"
-- Restore database
RESTORE DATABASE [AdventureWorks]
FROM
    DISK = 'C:\data\AdventureWorks2016.bak'
WITH
    MOVE N'AdventureWorks2016_Data' TO N'C:\data\AdventureWorks2016_Data.mdf',
    MOVE N'AdventureWorks2016_Log' TO N'C:\data\AdventureWorks2016_Log.ldf',
    RECOVERY,
    REPLACE
GO

ALTER DATABASE [AdventureWorks]
SET
    RECOVERY FULL WITH NO_WAIT
GO

BACKUP DATABASE [AdventureWorks]
TO
    DISK = N'C:\data\AdventureWorksAG.bak'
WITH
    NOFORMAT,
    NOINIT,
    NAME = N'AdventureWorks',
    SKIP,
    NOREWIND,
    NOUNLOAD
GO
"@;
        DependsOn = "[SqlSetup]SqlServerSetup", "[Script]DownloadAdventurWorks"
        PsDscRunAsCredential = $Credential
    }

    SqlDatabaseUser "AdventureWorks"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        DatabaseName = "AdventureWorks"
        Name = "$($Parameters.domainName.Split(".")[0])\$($engineCredential.UserName.Split("\")[1])"
        UserType = "Login"
        LoginName = "$($Parameters.domainName.Split(".")[0])\$($engineCredential.UserName.Split("\")[1])"

        DependsOn = "[SqlScriptQuery]RestoreDatabase"
        PsDscRunAsCredential = $Credential
    }

    SqlAGDatabase "AdventureWorks"
    {
        Ensure = "Present"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        AvailabilityGroupName = "AdventureWorks"
        BackupPath = "\\dc-0\share"
        DatabaseName = "AdventureWorks"

        DependsOn = "[SqlDatabaseUser]AdventureWorks"
        PsDscRunAsCredential = $Credential
    }

    for($i = 1; $i -lt $Parameters.nodeCount; $i++) {
        $nodeName = "$($Parameters.nodePrefix)-$i";

        WaitForAll "Node-$nodeName"
        {
            ResourceName = "[SqlEndpointPermission]EndpointPermission::[Customization]Customization"
            NodeName = $nodeName
            RetryIntervalSec = 5
            RetryCount = 120

            DependsOn = "[SqlAGDatabase]AdventureWorks"
        }

        SqlAGReplica "AddReplica-$nodeName"
        {
            ServerName = $nodeName
            InstanceName = "MSSQLSERVER"
            AvailabilityGroupName = "AdventureWorks"
            Name = $nodeName.ToUpper()

            PrimaryReplicaServerName = $Node.NodeName
            PrimaryReplicaInstanceName = "MSSQLSERVER"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"
            SeedingMode = "Manual"
            EndpointHostName = "$($nodeName).$($Parameters.domainName)"

            DependsOn = "[WaitForAll]Node-$nodeName"
            PsDscRunAsCredential = $Credential
        }

        SqlScriptQuery "GrantPermission-$nodeName"
        {
            Id = "GrantPermission-$nodeName"
            ServerName = $nodeName
            InstanceName = "MSSQLSERVER"
            Encrypt = "Optional"

            TestQuery = "RAISERROR ('Always false', 16, 1)"
            GetQuery = "SELECT 'false' AS result"
            SetQuery = @"
ALTER AVAILABILITY GROUP [AdventureWorks]
    GRANT CREATE ANY DATABASE
"@;
            DependsOn = "[SqlAGReplica]AddReplica-$nodeName"
            PsDscRunAsCredential = $Credential
        }

        SqlScriptQuery "EnableSeeding-$nodeName"
        {
            Id = "EnableSeeding-$nodeName"
            ServerName = $Node.NodeName
            InstanceName = "MSSQLSERVER"
            Encrypt = "Optional"

            TestQuery = "RAISERROR ('Always false', 16, 1)"
            GetQuery = "SELECT 'false' AS result"
            SetQuery = @"
ALTER AVAILABILITY GROUP [AdventureWorks]
    MODIFY REPLICA ON '$nodeName'
    WITH (SEEDING_MODE = AUTOMATIC)
"@;
            DependsOn = "[SqlScriptQuery]GrantPermission-$nodeName"
            PsDscRunAsCredential = $Credential
        }
    }
}