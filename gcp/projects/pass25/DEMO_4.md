# Demo 4

High performance storage subsystem with up to 500,000 IOPS and 10 GiB/s throughput using Hyperdisk Extreme.

## Prep

### Initialize disk on sql-0

```powershell
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $letter = [int][char]'T';
    $disks = Get-Disk | Where-Object -Property PartitionStyle -Value RAW -EQ

    foreach($disk in $disks)
    {
        Initialize-Disk -UniqueId $disk.UniqueId -PassThru | 
            New-Partition -DriveLetter ([char]$letter) -UseMaximumSize | 
            Format-Volume -FileSystem ReFS;

        # Add access for s-SqlEngine
        icacls t:\ /grant "PASS\s-SqlEngine:(OI)(CI)(F)";

        $letter++;
    }
}
```

### Configure SQL Server and restore database

```powershell
$secret = gcloud secrets versions access 1 --secret pass-demo-gcs --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
-- Server configuration
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 20480;
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
for($i = 0; $i -lt 2; $i++)
{
    $query += @"
-- Restore database
RESTORE DATABASE [demo4_${i}]
FROM
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_01.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_02.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_03.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_04.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_05.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_06.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_07.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_08.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_09.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_10.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_11.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_12.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_13.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_14.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_15.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_16.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_17.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_18.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_19.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_20.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_21.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_22.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_23.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_24.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_25.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_26.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_27.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_28.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_29.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_30.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_31.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_32.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_33.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_34.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_35.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_36.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_37.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_38.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_39.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_40.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_41.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_42.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_43.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_44.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_45.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_46.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_47.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_48.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_49.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_50.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_51.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_52.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_53.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_54.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_55.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_56.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_57.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_58.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_59.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_60.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_61.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_62.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_63.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_64.bak'
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

### Create HammerDB configuration & runner scripts

```powershell
$pathTools = "C:\tools";

for($i = 0; $i -lt 2; $i++)
{
    $scriptConfiguration = @"
#!/bin/tclsh

set tmpdir `$::env(TMP)
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

diset tpcc mssqls_dbase demo4_${i}
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
set of [ open `$tmpdir/demo4_${i} w ]
puts `$of `$jobid
close `$of
"@;

    $scriptRunner = @"
`$pathTools = "C:\tools";
`$pathHammerdb = Join-Path -Path `$pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path `$pathHammerdb;

# Start run
.\hammerdbcli auto `$pathTools/pass_run_${i}.tcl
"@

    $fileConfiguration = Join-Path -Path $pathTools -ChildPath "pass_run_$i.tcl";
    $fileRunner = Join-Path -Path $pathTools -ChildPath "pass_run_$i.ps1";
    Set-Content -Path $fileConfiguration -Value $scriptConfiguration;
    Set-Content -Path $fileRunner -Value $scriptRunner;
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
\tools\pass_run_0.ps1
```

```powershell
\tools\pass_run_1.ps1
```
