# Demo 4

High performance storage subsystem with up to 500,000 IOPS and 10 GiB/s throughput using Hyperdisk Extreme.

## Prep

### Initialize disk on sql-0

```powershell
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $friendlyName = "demo4";
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
    icacls t:\ /grant "PASS25\s-SqlEngine:(OI)(CI)(F)"
}
```

### Configure SQL Server and restore database

```powershell
$secret = gcloud secrets versions access 2 --secret demo4 --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
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

    -- Restore database
    RESTORE DATABASE [demo4_1]
    FROM
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_01.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_02.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_03.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_04.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_05.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_06.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_07.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_08.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_09.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_10.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_11.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_12.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_13.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_14.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_15.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_16.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_17.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_18.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_19.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_20.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_21.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_22.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_23.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_24.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_25.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_26.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_27.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_28.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_29.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_30.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_31.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_32.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_33.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_34.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_35.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_36.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_37.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_38.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_39.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_40.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_41.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_42.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_43.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_44.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_45.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_46.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_47.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_48.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_49.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_50.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_51.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_52.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_53.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_54.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_55.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_56.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_57.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_58.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_59.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_60.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_61.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_62.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_63.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_64.bak'
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

    RESTORE DATABASE [demo4_2]
    FROM
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_01.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_02.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_03.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_04.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_05.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_06.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_07.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_08.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_09.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_10.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_11.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_12.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_13.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_14.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_15.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_16.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_17.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_18.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_19.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_20.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_21.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_22.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_23.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_24.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_25.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_26.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_27.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_28.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_29.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_30.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_31.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_32.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_33.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_34.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_35.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_36.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_37.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_38.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_39.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_40.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_41.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_42.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_43.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_44.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_45.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_46.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_47.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_48.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_49.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_50.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_51.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_52.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_53.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_54.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_55.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_56.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_57.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_58.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_59.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_60.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_61.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_62.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_63.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_400_64.bak'
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
```

### Create HammerDB configuration

```powershell
$pathTools = "C:\tools";

$scriptRun1 = @'
#!/bin/tclsh
# maintainer: Pooja Jain

set tmpdir $::env(TMP)
puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_azure false
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true
diset connection mssqls_authentication windows
diset connection mssqls_server {sql-0}

diset tpcc mssqls_dbase demo4_1
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 60
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 400
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open $tmpdir/demo4_1 w ]
puts $of $jobid
close $of
'@;

$scriptRun2 = @'
#!/bin/tclsh
# maintainer: Pooja Jain

set tmpdir $::env(TMP)
puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_azure false
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true
diset connection mssqls_authentication windows
diset connection mssqls_server {sql-0}

diset tpcc mssqls_dbase demo4_2
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 60
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 400
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open $tmpdir/demo4_2 w ]
puts $of $jobid
close $of
'@;

$fileRun1 = Join-Path -Path $pathTools -ChildPath "pass_run_1.tcl";
$fileRun2 = Join-Path -Path $pathTools -ChildPath "pass_run_2.tcl";
Set-Content -Path $fileRun1 -Value $scriptRun1;
Set-Content -Path $fileRun2 -Value $scriptRun2;
```

## Setting the scene

1. Show disks in Cloud Console
    * [Disks](https://console.cloud.google.com/compute/disks)
1. Show storage configuration on sql-0
    * Storage Pool configuration
    * Disk configuration
1. Show SQL Server configuration
    * Tuned to drive IOPS
1. Show HammerDB
1. Show performance dashboard in Cloud Console
    * [PASS - Demo 4 - Disk Performance](https://console.cloud.google.com/monitoring/dashboards)

## Run

```powershell
$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path $pathHammerdb;

# Start first run
.\hammerdbcli auto $pathTools/pass_run_1.tcl
```

```powershell
$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path $pathHammerdb;

# Start second run
.\hammerdbcli auto $pathTools/pass_run_2.tcl
```