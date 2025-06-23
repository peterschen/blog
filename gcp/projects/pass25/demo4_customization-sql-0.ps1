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

    Script "InitDisk"
    {
        GetScript = {
            $disks = Get-PhysicalDisk -CanPool $true;
            if($disks -eq $null)
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
            $friendlyName = "pass";
            $disks = Get-PhysicalDisk -CanPool $true;
            $subsystem = Get-StorageSubSystem -Model "Windows Storage";

            # Create storage pool across all disks
            $pool = New-StoragePool -FriendlyName $friendlyName -PhysicalDisks $disks `
                -StorageSubSystemUniqueId $subsystem.UniqueId -ProvisioningTypeDefault "Fixed" `
                -ResiliencySettingNameDefault "Simple";

            # Create virtual disk in the pool
            $disk = New-VirtualDisk -FriendlyName $friendlyName -StoragePoolUniqueId $pool.UniqueId -UseMaximumSize;

            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru | 
                New-Partition -DriveLetter "T" -UseMaximumSize | 
                Format-Volume;

            # Add access for s-SqlEngine
            icacls t:\ /grant "PASS\s-SqlEngine:(OI)(CI)(F)";
        }
    }

    Script "ConfigureDatabase"
    {
        GetScript = {
            $result = Invoke-Sqlcmd -Query "SELECT name FROM sys.credentials WHERE credential_identity = 'S3 Access Key'" -ServerInstance "sql-0";
            if($result -ne $null)
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
            $secret = gcloud secrets versions access 1 --secret pass25-demo-gcs --project cbpetersen-shared;
            $query = @"
-- Server configuration
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
-- EXEC sp_configure 'max degree of parallelism', 8;
-- EXEC sp_configure 'max worker threads', 6000;
-- EXEC sp_configure 'min server memory', 0;
-- EXEC sp_configure 'max server memory', 131072;
-- EXEC sp_configure 'recovery interval (min)', 15;
-- EXEC sp_configure 'lightweight pooling', 1;
-- EXEC sp_configure 'priority boost', 1;
RECONFIGURE;

-- Enable checkpoint tracing
DBCC TRACEON (3502, -1);
DBCC TRACEON (3504, -1);
DBCC TRACEON (3605, -1);
GO

-- Configure credential for GCS
IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
    CREATE CREDENTIAL [s3://storage.googleapis.com/cbpetersen-demos]
    WITH
        IDENTITY = 'S3 Access Key',
        SECRET = '${secret}';
"@;
            Invoke-Sqlcmd -Query $query -ServerInstance "sql-0";
        }
    }

    SqlScriptQuery "RestoreDatabase1"
    {
        Id = "RestoreDatabase1"
        ServerName = "sql-0"
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'demo4_1') = 0
BEGIN
    RAISERROR ('Did not find database [demo4_1]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [demo4_1]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'demo4_1'"
        SetQuery = @"
-- Restore database
RESTORE DATABASE [demo4_1]
FROM
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_01.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_02.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_03.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_04.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_05.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_06.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_07.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_08.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_09.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_10.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_11.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_12.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_13.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_14.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_15.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_16.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_17.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_18.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_19.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_20.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_21.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_22.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_23.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_24.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_25.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_26.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_27.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_28.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_29.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_30.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_31.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_32.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_33.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_34.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_35.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_36.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_37.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_38.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_39.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_40.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_41.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_42.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_43.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_44.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_45.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_46.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_47.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_48.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_49.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_50.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_51.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_52.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_53.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_54.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_55.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_56.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_57.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_58.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_59.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_60.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_61.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_62.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_63.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_64.bak'
WITH 
    MOVE 'demo4' TO 'T:\demo4_1.mdf',
    MOVE 'demo4_log' TO 'T:\demo4_1_log.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO

-- ALTER DATABASE [demo4_1] MODIFY FILE ( NAME = N'demo4_log', SIZE = 128GB, FILEGROWTH = 0)
ALTER DATABASE [demo4_1] SET RECOVERY SIMPLE;
-- ALTER DATABASE [demo4_1] SET TORN_PAGE_DETECTION OFF;
-- ALTER DATABASE [demo4_1] SET PAGE_VERIFY NONE;
-- ALTER DATABASE [demo4_1] SET TARGET_RECOVERY_TIME = 15 MINUTES;
GO
"@;
        DependsOn = "[Script]ConfigureDatabase"
        PsDscRunAsCredential = $Credential
    }

    SqlScriptQuery "RestoreDatabase2"
    {
        Id = "RestoreDatabase2"
        ServerName = "sql-0"
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'demo4_2') = 0
BEGIN
    RAISERROR ('Did not find database [demo4_2]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [demo4_2]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'demo4_2'"
        SetQuery = @"
-- Restore database
RESTORE DATABASE [demo4_2]
FROM
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_01.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_02.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_03.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_04.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_05.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_06.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_07.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_08.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_09.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_10.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_11.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_12.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_13.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_14.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_15.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_16.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_17.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_18.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_19.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_20.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_21.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_22.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_23.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_24.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_25.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_26.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_27.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_28.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_29.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_30.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_31.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_32.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_33.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_34.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_35.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_36.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_37.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_38.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_39.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_40.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_41.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_42.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_43.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_44.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_45.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_46.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_47.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_48.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_49.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_50.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_51.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_52.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_53.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_54.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_55.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_56.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_57.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_58.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_59.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_60.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_61.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_62.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_63.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_2500_64.bak'
WITH 
    MOVE 'demo4' TO 'T:\demo4_2.mdf',
    MOVE 'demo4_log' TO 'T:\demo4_2_log.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO

-- ALTER DATABASE [demo4_2] MODIFY FILE ( NAME = N'demo4_log', SIZE = 128GB, FILEGROWTH = 0)
ALTER DATABASE [demo4_2] SET RECOVERY SIMPLE;
-- ALTER DATABASE [demo4_2] SET TORN_PAGE_DETECTION OFF;
-- ALTER DATABASE [demo4_2] SET PAGE_VERIFY NONE;
-- ALTER DATABASE [demo4_2] SET TARGET_RECOVERY_TIME = 15 MINUTES;
GO
"@;
        DependsOn = "[Script]ConfigureDatabase"
        PsDscRunAsCredential = $Credential
    }
}