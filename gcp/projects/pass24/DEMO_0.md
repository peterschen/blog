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
$secret = gcloud secrets versions access 1 --secret pass24-gcs-access --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
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
    GO

    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/pass-demo-2024]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';

    -- Restore database
    RESTORE DATABASE [pass_1]
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
        MOVE 'pass' TO 'T:\pass_1.mdf',
        MOVE 'pass_log' TO 'T:\pass_1_log.ldf',
        STATS = 10, 
        RECOVERY,
        REPLACE;
    GO

    ALTER DATABASE [pass_1] MODIFY FILE ( NAME = N'pass_log', SIZE = 128GB, FILEGROWTH = 0)
    ALTER DATABASE [pass_1] SET RECOVERY SIMPLE;
    ALTER DATABASE [pass_1] SET TORN_PAGE_DETECTION OFF;
    ALTER DATABASE [pass_1] SET PAGE_VERIFY NONE;
    ALTER DATABASE [pass_1] SET TARGET_RECOVERY_TIME = 15 MINUTES;
    GO

    RESTORE DATABASE [pass_2]
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
        MOVE 'pass' TO 'T:\pass_2.mdf',
        MOVE 'pass_log' TO 'T:\pass_2_log.ldf',
        STATS = 10, 
        RECOVERY,
        REPLACE;
    GO

    ALTER DATABASE [pass_2] MODIFY FILE ( NAME = N'pass_log', SIZE = 128GB, FILEGROWTH = 0)
    ALTER DATABASE [pass_2] SET RECOVERY SIMPLE;
    ALTER DATABASE [pass_2] SET TORN_PAGE_DETECTION OFF;
    ALTER DATABASE [pass_2] SET PAGE_VERIFY NONE;
    ALTER DATABASE [pass_2] SET TARGET_RECOVERY_TIME = 15 MINUTES;
    GO
"@;
```

## Create HammerDB configuration

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

diset tpcc mssqls_dbase pass_1
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 5
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 250
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open $tmpdir/pass_1 w ]
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

diset tpcc mssqls_dbase pass_2
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 5
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 250
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open $tmpdir/pass_2 w ]
puts $of $jobid
close $of
'@;

$fileRun2 = Join-Path -Path $pathTools -ChildPath "pass_run_2.tcl";
Set-Content -Path $fileRun1 -Value $scriptRun1;
Set-Content -Path $fileRun2 -Value $scriptRun2;
```