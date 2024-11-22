
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

    Script "InitDisk"
    {
        GetScript = {
            $disk = Get-PhysicalDisk -CanPool $true;
            if($disk -eq $null)
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
            $disk = Get-PhysicalDisk -CanPool $true;

            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru |
                New-Partition -DriveLetter "T" -UseMaximumSize | 
                Format-Volume;

            New-Item -Path "T:\AdventureWorks" -Type "Directory";
        }
    }

    Script "AddClusterDisk"
    {
        GetScript = {
            $resource = Get-ClusterSharedVolume -Name "Cluster Disk 1" -ErrorAction "SilentlyContinue";
            if($resource -ne $null)
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
            # Add disk to cluster
            $clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk;
            $resource = Add-ClusterSharedVolume -Name $clusterDisk.Name;

            # Bring disk online if necessary
            Resume-ClusterResource -InputObject $resource;
        }

        PsDscRunAsCredential = $Credential
        DependsOn = "[Script]InitDisk"
    }

    SqlSetup "SqlServerSetup"
    {
        Action = "INSTALLFAILOVERCLUSTER"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        FailoverClusterNetworkName = $Parameters.nodePrefix
        FailoverClusterIPAddress = $Parameters.ipSql
        InstallSQLDataDir = "C:\ClusterStorage\Volume1"

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

    SqlServiceAccount "EngineAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "DatabaseEngine"
        ServiceAccount = $engineCredential
        RestartService = $true

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
    MOVE N'AdventureWorks2016_Data' TO N'C:\ClusterStorage\Volume1\AdventureWorks\AdventureWorks2016_Data.mdf',
    MOVE N'AdventureWorks2016_Log' TO N'C:\ClusterStorage\Volume1\AdventureWorks\AdventureWorks2016_Log.ldf',
    RECOVERY,
    REPLACE
GO
"@;
        DependsOn = "[SqlSetup]SqlServerSetup", "[Script]DownloadAdventurWorks"
        PsDscRunAsCredential = $Credential
    }
}