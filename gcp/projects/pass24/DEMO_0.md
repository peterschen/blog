# DEMO_0

Preparation of demo environment.

## Initialize disk on sql-0

```powershell
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $friendlyName = "pass24";
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
    icacls t:\ /grant "PASS24\s-SqlEngine:(OI)(CI)(F)"
}
```

## Configure SQL Server and restore database

```powershell
# Add 
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $path = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters";
    if(-not (Get-ItemProperty -Path $path -Name "SQLArg3" -ErrorAction SilentlyContinue))
    {
        Set-ItemProperty -Path $path -Name "SQLArg3" -Value "-k";
    }

    Restart-Service -Name "MSSQLSERVER";
}

$secret = gcloud secrets versions access 1 --secret pass24-gcs-access --project cbpetersen-shared;
$command = @"
    -- Server configuration
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'max degree of parallelism', 8;
    EXEC sp_configure 'max worker threads', 6000;
    EXEC sp_configure 'min server memory', 0;
    EXEC sp_configure 'max server memory', 131072;
    EXEC sp_configure 'recovery interval (min)', 15;
    EXEC sp_configure 'lightweight pooling', 1;
    EXEC sp_configure 'priority boost', 1;
    RECONFIGURE;

    -- Enable checkpoint tracing
    DBCC TRACEON (3502, -1);
    DBCC TRACEON (3504, -1);
    DBCC TRACEON (3605, -1);

    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/pass-demo-2024]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';

    -- Restore database
    RESTORE DATABASE [pass_5000]
    FROM
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_01.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_02.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_03.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_04.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_05.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_06.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_07.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_08.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_09.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_10.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_11.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_12.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_13.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_14.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_15.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_16.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_17.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_18.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_19.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_20.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_21.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_22.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_23.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_24.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_25.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_26.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_27.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_28.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_29.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_30.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_31.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_32.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_33.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_34.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_35.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_36.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_37.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_38.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_39.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_40.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_41.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_42.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_43.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_44.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_45.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_46.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_47.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_48.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_49.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_50.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_51.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_52.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_53.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_54.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_55.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_56.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_57.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_58.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_59.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_60.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_61.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_62.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_63.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_5000_64.bak'
    WITH 
        MOVE 'pass' TO 'T:\pass_5000.mdf',
        MOVE 'pass_log' TO 'T:\pass_5000_log.ldf',
        STATS = 10, 
        RECOVERY,
        REPLACE;
    ALTER DATABASE [pass_5000] MODIFY FILE ( NAME = N'pass_log', MAXSIZE = 128GB, FILEGROWTH = 128MB)
    ALTER DATABASE [pass_5000] SET RECOVERY SIMPLE;
    ALTER DATABASE [pass_5000] SET TORN_PAGE_DETECTION OFF;
    ALTER DATABASE [pass_5000] SET PAGE_VERIFY NONE;
    ALTER DATABASE [pass_5000] SET TARGET_RECOVERY_TIME = 15 MINUTES;
"@;
sqlcmd -S "tcp:sql-0" -Q "$command"
```
