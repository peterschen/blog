
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

    Script "DownloadAdventurWorks2016"
    {
        GetScript = {
            $path  = Join-Path -Path "C:\" -ChildPath "AdventureWorks2016.bak";
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
            $path  = Join-Path -Path "C:\" -ChildPath "AdventureWorks2016.bak";
            Start-BitsTransfer -Source "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2016.bak" -Destination $path;
        }

        PsDscRunAsCredential = $Credential
    }

    Script "SetPermissions"
    {
        GetScript = {
            $acl = Get-Acl -Path "C:\AdventureWorks2016.bak";
            if($acl.Owner.Contains("s-SqlEngine"))
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
            $acl = Get-Acl -Path "C:\AdventureWorks2016.bak";
            $owner = New-Object System.Security.Principal.NTAccount($engineCredential.UserName);
            $acl.SetOwner($owner);
            Set-Acl -Path "C:\AdventureWorks2016.bak" -AclObject $acl;
        }

        DependsOn = "[Script]DownloadAdventurWorks2016"
        PsDscRunAsCredential = $Credential
    }

    SqlScriptQuery "RestoreDatabase"
    {
        Id = "RestoreDatabase"
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'AdventureWorks2016') = 0
BEGIN
    RAISERROR ('Did not find database [AdventureWorks2016]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [AdventureWorks2016]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'AdventureWorks2016'"
        SetQuery = @"
-- Restore database
RESTORE DATABASE [AdventureWorks2016]
FROM
    DISK = 'C:\AdventureWorks2016.bak'
WITH
    MOVE N'AdventureWorks2016_Data' TO N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\AdventureWorks2016_Data.mdf',
    MOVE N'AdventureWorks2016_Log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA\AdventureWorks2016_Log.ldf', 
    RECOVERY,
    REPLACE
GO

ALTER DATABASE [AdventureWorks2016]
SET
    RECOVERY FULL WITH NO_WAIT
GO

BACKUP DATABASE [AdventureWorks2016]
TO
    DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\AdventureWorks2016.bak'
WITH
    NOFORMAT,
    NOINIT,
    NAME = N'AdventureWorks2016',
    SKIP,
    NOREWIND,
    NOUNLOAD
GO

USE [master];
CREATE LOGIN [$($engineCredential.UserName)] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$($engineCredential.UserName)];
GO

USE [AdventureWorks2016];
CREATE USER [$($engineCredential.UserName)] FOR LOGIN [$($engineCredential.UserName)];
GO
"@;
        Variable = @("FilePath=C:\windows\temp\restoredatabase")
        
        DependsOn = "[Script]DownloadAdventurWorks2016"
        PsDscRunAsCredential = $Credential
    }
}