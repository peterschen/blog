# PASS 2024

## Initialize disk

```powershell
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
icacls t:\ /grant "PASS\s-SqlEngine:(OI)(CI)(F)"
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

### Single thread latency

#### Reads

```shell
fio --name=iops --rw=randrw --rwmixread=0 --bs=4k --numjobs=1 --time_based --runtime=60m --direct=1 --verify=0 --iodepth=1 --filesize=50G --filename=t\:\\benchmark.fio -randrepeat=0
```

```
iops: (groupid=0, jobs=1): err= 0: pid=20092: Wed Jul 2 07:12:51 2025
  write: IOPS=1316, BW=5266KiB/s (5392kB/s)(83.6MiB/16254msec); 0 zone resets
    slat (usec): min=4, max=573, avg=23.84, stdev=89.05
    clat (usec): min=302, max=2735, avg=493.75, stdev=85.54
     lat (usec): min=309, max=2741, avg=517.60, stdev=124.94
    clat percentiles (usec):
     |  1.00th=[  363],  5.00th=[  392], 10.00th=[  408], 20.00th=[  429],
     | 30.00th=[  449], 40.00th=[  465], 50.00th=[  482], 60.00th=[  498],
     | 70.00th=[  519], 80.00th=[  545], 90.00th=[  594], 95.00th=[  635],
     | 99.00th=[  766], 99.50th=[  840], 99.90th=[ 1037], 99.95th=[ 1254],
     | 99.99th=[ 1942]
   bw (  KiB/s): min= 4888, max= 8144, per=100.00%, avg=7625.27, stdev=783.28, samples=22
   iops        : min= 1222, max= 2036, avg=1905.91, stdev=195.75, samples=22
  lat (usec)   : 500=61.52%, 750=37.31%, 1000=1.05%
  lat (msec)   : 2=0.12%, 4=0.01%
  cpu          : usr=0.00%, sys=0.00%, ctx=0, majf=0, minf=0
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,21398,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=5266KiB/s (5392kB/s), 5266KiB/s-5266KiB/s (5392kB/s-5392kB/s), io=83.6MiB (87.6MB), run=16254-16254msec
```

#### Writes

```shell
fio --name=iops --rw=randrw --rwmixread=0 --bs=4k --numjobs=1 --time_based --runtime=60m --direct=1 --verify=0 --iodepth=1 --filesize=50G --filename=t\:\\benchmark.fio -randrepeat=0
```

```
iops: (groupid=0, jobs=1): err= 0: pid=12876: Wed Jul 2 07:16:17 2025
  read: IOPS=1475, BW=5901KiB/s (6043kB/s)(152MiB/26393msec)
    slat (usec): min=3, max=149, avg= 4.49, stdev= 2.10
    clat (usec): min=377, max=105472, avg=672.72, stdev=1172.09
     lat (usec): min=381, max=105485, avg=677.21, stdev=1172.51
    clat percentiles (usec):
     |  1.00th=[  449],  5.00th=[  482], 10.00th=[  498], 20.00th=[  523],
     | 30.00th=[  545], 40.00th=[  562], 50.00th=[  586], 60.00th=[  603],
     | 70.00th=[  627], 80.00th=[  668], 90.00th=[  717], 95.00th=[  791],
     | 99.00th=[ 2180], 99.50th=[ 3359], 99.90th=[14222], 99.95th=[22414],
     | 99.99th=[57410]
   bw (  KiB/s): min=  358, max= 6664, per=100.00%, avg=5902.67, stdev=1514.06, samples=52
   iops        : min=   89, max= 1666, avg=1475.44, stdev=378.56, samples=52
  lat (usec)   : 500=11.21%, 750=81.52%, 1000=4.78%
  lat (msec)   : 2=0.89%, 4=1.15%, 10=0.30%, 20=0.09%, 50=0.04%
  lat (msec)   : 100=0.01%, 250=0.01%
  cpu          : usr=0.00%, sys=0.00%, ctx=0, majf=0, minf=0
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=38936,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=5901KiB/s (6043kB/s), 5901KiB/s-5901KiB/s (6043kB/s-6043kB/s), io=152MiB (159MB), run=26393-26393msec
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

```powershell
$secret = gcloud secrets versions access 1 --secret pass-demo-gcs --project cbpetersen-shared;
$command = @"
	-- Credentials
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/cbpetersen-demos]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';
"@;

sqlcmd -S "tcp:sql-0" -Q "$command"
```

```sql

-- Backup
BACKUP DATABASE [demo4]
TO
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_64.bak'
WITH
	COMPRESSION,
	STATS = 10,
	MAXTRANSFERSIZE = 20971520;

-- Restore
RESTORE DATABASE [pass]
FROM
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_64.bak'
WITH 
	MOVE 'pass' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\Data\pass.mdf',
	MOVE 'pass_log' TO 'T:\MSSQL16.MSSQLSERVER\MSSQL\DATA\pass_log.ldf',
	STATS = 10, 
	RECOVERY,
	REPLACE;
GO
```

## HammerDB

### Build for  HdB (160k)

Warehouses: 2500
Virtual users: 250

### Build for  HdX (350k)

Warehouses: 5000
Virtual users: 500

### Run for  HdB (160k)

Warehouses: 2500
Virtial users: 100

### Run for  HdX (350k)

Memory: 130 GiB (163840 MiB)
Recovery interval: 0
Warehouses: 5000
Virtual users: 450
Warmup: 4 mins

### Run for  HdX (500k)

Warehouses: 5000
Virtual users: 450?

## Complete configuration

```sql
-- https://www.hammerdb.com/blog/uncategorized/hammerdb-best-practice-for-sql-server-performance-and-scalability/
-- https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-recovery-interval-server-configuration-option?view=sql-server-ver16#use-transact-sql

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max degree of parallelism', 8;
EXEC sp_configure 'max worker threads', 6000;
EXEC sp_configure 'min server memory', 0;
EXEC sp_configure 'max server memory', 307200;
EXEC sp_configure 'recovery interval (min)', 60;
EXEC sp_configure 'lightweight pooling', 1;
EXEC sp_configure 'priority boost', 1;
RECONFIGURE;

-- Enabled traces
DBCC TRACEON (3502, -1);
DBCC TRACEON (3504, -1);
DBCC TRACEON (3605, -1);

-- Backup
BACKUP DATABASE [pass_2500]
TO
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_64.bak'
WITH
	COMPRESSION,
	STATS = 10,
	MAXTRANSFERSIZE = 20971520;

-- Restore
RESTORE DATABASE [pass_2500]
FROM
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_250_64.bak'
WITH 
	MOVE 'pass' TO 'T:\demo4.mdf',
	MOVE 'pass_log' TO 'T:\demo4_log.ldf',
	STATS = 10, 
	RECOVERY,
	REPLACE;
ALTER DATABASE [pass_2500] MODIFY FILE ( NAME = N'pass_log', FILEGROWTH = 0)
ALTER DATABASE [pass_2500] SET RECOVERY SIMPLE;
ALTER DATABASE [pass_2500] SET TORN_PAGE_DETECTION OFF;
ALTER DATABASE [pass_2500] SET PAGE_VERIFY NONE;
ALTER DATABASE [pass_2500] SET TARGET_RECOVERY_TIME = 0 MINUTES;
GO

BACKUP DATABASE [pass_5000]
TO
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_64.bak'
WITH
	COMPRESSION,
	STATS = 10,
	MAXTRANSFERSIZE = 20971520;

-- Restore
RESTORE DATABASE [pass_5000]
FROM
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_01.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_02.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_03.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_04.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_05.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_06.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_07.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_08.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_09.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_10.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_11.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_12.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_13.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_14.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_15.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_16.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_17.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_18.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_19.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_20.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_21.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_22.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_23.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_24.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_25.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_26.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_27.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_28.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_29.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_30.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_31.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_32.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_33.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_34.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_35.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_36.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_37.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_38.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_39.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_40.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_41.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_42.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_43.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_44.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_45.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_46.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_47.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_48.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_49.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_50.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_51.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_52.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_53.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_54.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_55.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_56.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_57.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_58.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_59.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_60.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_61.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_62.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_63.bak',
	URL = 's3://storage.googleapis.com/cbpetersen-demos/pass_5000_64.bak'
WITH 
	MOVE 'pass' TO 'T:\pass_5000.mdf',
	MOVE 'pass_log' TO 'T:\pass_5000_log.ldf',
	STATS = 10, 
	RECOVERY,
	REPLACE;
ALTER DATABASE [pass_5000] MODIFY FILE ( NAME = N'pass_log', SIZE=131072, FILEGROWTH = 0)
ALTER DATABASE [pass_5000] SET RECOVERY SIMPLE;
ALTER DATABASE [pass_5000] SET TORN_PAGE_DETECTION OFF;
ALTER DATABASE [pass_5000] SET PAGE_VERIFY NONE;
ALTER DATABASE [pass_5000] SET TARGET_RECOVERY_TIME = 15 MINUTES;
GO
```