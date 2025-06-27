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
    icacls t:\ /grant "PASS\s-SqlEngine:(OI)(CI)(F)"
}
```

### Configure SQL Server and restore database

```powershell
$secret = gcloud secrets versions access 1 --secret pass-demo-gcs --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
-- Server configuration
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 131072;
EXEC sp_configure 'recovery interval (min)', 15;
RECONFIGURE;

-- Configure credential for GCS
IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
    CREATE CREDENTIAL [s3://storage.googleapis.com/cbpetersen-demos]
    WITH
        IDENTITY = 'S3 Access Key',
        SECRET = '${secret}';
"@

$query = "";
for($i = 0; $i -lt 3; $i++)
{
    $query += @"
-- Restore database
RESTORE DATABASE [demo4_${i}]
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
    MOVE 'demo4' TO 'T:\demo4_${i}.mdf',
    MOVE 'demo4_log' TO 'T:\demo4_${i}_log.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO

ALTER DATABASE [demo4_${i}] SET RECOVERY FULL;
ALTER DATABASE [demo4_${i}] SET TARGET_RECOVERY_TIME = 15 MINUTES;
GO
"@
}
```

### Create HammerDB configuration

```powershell
$pathTools = "C:\tools";

for($i = 0; $i -lt 3; $i++)
{
    $scriptRun = @'
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


'@

    $scriptRun += "diset tpcc mssqls_dbase demo4_$i";

    $scriptRun += @'

diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 60
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile false
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 400
vuset delay 100
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

    $fileRun = Join-Path -Path $pathTools -ChildPath "pass_run_$i.tcl";
    Set-Content -Path $fileRun -Value $scriptRun;
}
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
$query = "";
for($i = 0; $i -lt 5; $i++)
{
    $query += @"
USE [demo4_${i}];
CHECKPOINT;
GO

"@;
}

sqlcmd -S "tcp:sql-0" -Q $query;

$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path $pathHammerdb;

# Start run
.\hammerdbcli auto $pathTools/pass_run_0.tcl
```

```powershell
$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path $pathHammerdb;

# Start run
.\hammerdbcli auto $pathTools/pass_run_1.tcl
```

```powershell
$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path $pathHammerdb;

# Start run
.\hammerdbcli auto $pathTools/pass_run_2.tcl
```