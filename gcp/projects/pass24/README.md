# PASS 2024

## Initialize disk

```powershell
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
```

## Run `fio`

### IOPS

```shell
fio --name=iops --rw=randrw --rwmixread=70 --bs=4k --numjobs=96 --time_based --runtime=60m --direct=1 --verify=0 --iodepth=3 --filesize=1G --filename=t\:\\benchmark.fio
```

### Throughput

```shell
fio --name=throughput --rw=randrw --rwmixread=70 --bs=96k --numjobs=96 --time_based --runtime=60m --direct=1 --verify=0 --iodepth=3 --filesize=1G --filename=t\:\\benchmark.fio
```

# SQL Server configuration

## Server settings

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'max degree of parallelism', 8;
EXEC sp_configure 'max worker threads', 6000;
EXEC sp_configure 'min server memory', 0;
EXEC sp_configure 'max server memory', 65536;

-- https://www.hammerdb.com/blog/uncategorized/hammerdb-best-practice-for-sql-server-performance-and-scalability/
-- https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-recovery-interval-server-configuration-option?view=sql-server-ver16#use-transact-sql
EXEC sp_configure 'recovery interval (min)', 0;
EXEC sp_configure 'lightweight pooling', 1;
EXEC sp_configure 'priority boost', 1;
RECONFIGURE WITH OVERRIDE;
```

## Database

```sql
DROP DATABASE [pass];
CREATE DATABASE [pass] ON 
	PRIMARY (
		NAME = N'pass', 
		FILENAME = N'T:\MSSQL16.MSSQLSERVER\MSSQL\Data\pass.mdf',
		SIZE = 256GB,
		FILEGROWTH = 0
	)
	LOG ON (
		NAME = N'pass_log',
		FILENAME = N'T:\MSSQL16.MSSQLSERVER\MSSQL\Data\pass_log.ldf',
		SIZE = 32GB,
		FILEGROWTH = 0
)
ALTER DATABASE [pass] SET RECOVERY SIMPLE;
ALTER DATABASE [pass] SET TORN_PAGE_DETECTION OFF;
ALTER DATABASE [pass] SET PAGE_VERIFY NONE;
-- https://learn.microsoft.com/en-us/sql/relational-databases/logs/change-the-target-recovery-time-of-a-database-sql-server?view=sql-server-ver16
-- ALTER DATABASE [pass] SET TARGET_RECOVERY_TIME = 60 MINUTES;
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [pass] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
```

## Traces to identify checkpointing

```sql
DBCC TRACEON (3502, -1);
DBCC TRACEON (3504, -1);
DBCC TRACEON (3605, -1);
```

## GCS backup

pass24-gcs-access
```powershell
$secret = gcloud secrets versions access 1 --secret pass24-gcs-access --project cbpetersen-shared;
$command = @"
	-- Credentials
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/pass-demo-2024]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';
"@;

sqlcmd -S "tcp:sql-0" -Q "$command"
```

```sql

-- Backup
BACKUP DATABASE [pass]
TO
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_01.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_02.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_03.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_04.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_05.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_06.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_07.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_08.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_09.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_10.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_11.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_12.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_13.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_14.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_15.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_16.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_17.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_18.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_19.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_20.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_21.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_22.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_23.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_24.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_25.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_26.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_27.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_28.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_29.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_30.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_31.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_32.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_33.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_34.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_35.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_36.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_37.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_38.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_39.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_40.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_41.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_42.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_43.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_44.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_45.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_46.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_47.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_48.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_49.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_50.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_51.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_52.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_53.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_54.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_55.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_56.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_57.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_58.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_59.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_60.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_61.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_62.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_63.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_64.bak'
WITH
	COMPRESSION,
	STATS = 10,
	MAXTRANSFERSIZE = 20971520;

-- Restore
RESTORE DATABASE [pass]
FROM
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_01.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_02.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_03.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_04.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_05.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_06.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_07.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_08.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_09.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_10.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_11.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_12.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_13.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_14.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_15.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_16.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_17.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_18.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_19.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_20.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_21.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_22.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_23.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_24.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_25.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_26.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_27.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_28.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_29.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_30.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_31.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_32.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_33.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_34.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_35.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_36.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_37.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_38.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_39.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_40.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_41.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_42.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_43.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_44.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_45.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_46.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_47.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_48.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_49.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_50.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_51.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_52.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_53.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_54.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_55.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_56.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_57.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_58.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_59.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_60.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_61.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_62.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_63.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_64.bak'
WITH 
	MOVE 'pass' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\Data\pass.mdf',
	MOVE 'pass_log' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\DATA\pass_log.ldf',
	STATS = 10, 
	RECOVERY,
	REPLACE;
GO
```

## HammerDB

Warehouses: 2500
User: 150

## Complete configuration

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max degree of parallelism', 8;
EXEC sp_configure 'max worker threads', 6000;
EXEC sp_configure 'min server memory', 0;

-- Limit memory to force disk I/O
EXEC sp_configure 'max server memory', 65536;

-- https://www.hammerdb.com/blog/uncategorized/hammerdb-best-practice-for-sql-server-performance-and-scalability/
-- https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-recovery-interval-server-configuration-option?view=sql-server-ver16#use-transact-sql
EXEC sp_configure 'recovery interval (min)', 0;
EXEC sp_configure 'lightweight pooling', 1;
EXEC sp_configure 'priority boost', 1;
RECONFIGURE;

ALTER DATABASE [pass] SET RECOVERY SIMPLE;
ALTER DATABASE [pass] SET TORN_PAGE_DETECTION OFF;
ALTER DATABASE [pass] SET PAGE_VERIFY NONE;
-- https://learn.microsoft.com/en-us/sql/relational-databases/logs/change-the-target-recovery-time-of-a-database-sql-server?view=sql-server-ver16
ALTER DATABASE [pass] SET TARGET_RECOVERY_TIME = 60 MINUTES;

-- Enabled traces
DBCC TRACEON (3502, -1);
DBCC TRACEON (3504, -1);
DBCC TRACEON (3605, -1);

-- Backup
BACKUP DATABASE [pass]
TO
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_01.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_02.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_03.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_04.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_05.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_06.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_07.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_08.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_09.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_10.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_11.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_12.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_13.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_14.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_15.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_16.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_17.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_18.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_19.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_20.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_21.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_22.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_23.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_24.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_25.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_26.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_27.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_28.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_29.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_30.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_31.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_32.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_33.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_34.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_35.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_36.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_37.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_38.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_39.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_40.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_41.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_42.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_43.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_44.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_45.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_46.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_47.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_48.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_49.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_50.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_51.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_52.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_53.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_54.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_55.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_56.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_57.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_58.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_59.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_60.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_61.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_62.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_63.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_64.bak'
WITH
	FORMAT,
	COMPRESSION,
	STATS = 10,
	MAXTRANSFERSIZE = 20971520;

-- Restore
RESTORE DATABASE [pass]
FROM
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_01.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_02.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_03.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_04.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_05.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_06.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_07.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_08.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_09.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_10.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_11.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_12.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_13.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_14.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_15.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_16.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_17.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_18.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_19.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_20.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_21.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_22.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_23.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_24.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_25.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_26.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_27.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_28.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_29.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_30.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_31.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_32.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_33.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_34.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_35.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_36.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_37.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_38.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_39.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_40.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_41.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_42.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_43.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_44.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_45.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_46.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_47.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_48.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_49.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_50.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_51.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_52.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_53.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_54.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_55.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_56.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_57.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_58.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_59.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_60.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_61.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_62.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_63.bak',
	URL = 's3://storage.googleapis.com/pass-demo-2024/pass_2500_64.bak'
WITH 
	MOVE 'pass' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\Data\pass.mdf',
	MOVE 'pass_log' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\DATA\pass_log.ldf',
	STATS = 10, 
	RECOVERY,
	REPLACE;
GO
```