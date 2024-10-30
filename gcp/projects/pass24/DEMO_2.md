# Demo 2

SQL Server FCI with shared storage provided by Hyperdisk

## Prep

### Initialize disk on sql-0

```powershell
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $disk = Get-PhysicalDisk -CanPool $true;

    # Initialize disk
    Initialize-Disk -UniqueId $disk.UniqueId -PassThru |
        New-Partition -DriveLetter "T" -UseMaximumSize | 
        Format-Volume;

    # Add disk to cluster
    $clusterDisk = Get-ClusterAvailableDisk | Add-ClusterDisk;
    $resource = Add-ClusterSharedVolume -Name $clusterDisk.Name;

    # Bring disk online if necessary
    Resume-ClusterResource -InputObject $resource;
}
```

### Install SQL Server on sql-0

```powershell
$zone = (Invoke-RestMethod `
          -Headers @{'Metadata-Flavor' = 'Google'} `
          -Uri "http://metadata.google.internal/computeMetadata/v1/instance/zone")

$index = $zone.LastIndexOf("/")
$length = $zone.Length - $index - 3;
$region = $zone.Substring($index + 1, $length);

$ip = gcloud compute addresses describe wsfc-sql --region $region --format "value(address)";

# Validate cluster
Test-Cluster -Include "List Disks";

c:\sql_server_install\setup.exe /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS /Q /ACTION=InstallFailoverCluster /FEATURES=SQLEngine,FullText /INSTANCENAME=MSSQLSERVER /FAILOVERCLUSTERIPADDRESSES="IPv4;$ip;Cluster Network 1;255.255.0.0" /FAILOVERCLUSTERDISKS="Cluster Disk 1" /FAILOVERCLUSTERNETWORKNAME=sql /AGTSVCACCOUNT=PASS24\s-SqlAgent /AGTSVCPASSWORD=Admin123Admin123 /SQLSVCACCOUNT=PASS24\s-SqlEngine /SQLSVCPASSWORD=Admin123Admin123 /INSTALLSQLDATADIR=C:\ClusterStorage\Volume1 /SqlSysadminAccounts=PASS24\g-SqlAdministrators
```

### Install SQL Server on sql-1

```powershell
$zone = (Invoke-RestMethod `
          -Headers @{'Metadata-Flavor' = 'Google'} `
          -Uri "http://metadata.google.internal/computeMetadata/v1/instance/zone")

$index = $zone.LastIndexOf("/")
$length = $zone.Length - $index - 3;
$region = $zone.Substring($index + 1, $length);

$ip = gcloud compute addresses describe wsfc-sql --region $region --format "value(address)";

c:\sql_server_install\setup.exe /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS /Q /ACTION=AddNode /INSTANCENAME=MSSQLSERVER /FAILOVERCLUSTERIPADDRESSES="IPv4;$ip;Cluster Network 1;255.255.0.0" /FAILOVERCLUSTERNETWORKNAME=sql /AGTSVCACCOUNT=PASS24\s-SqlAgent /AGTSVCPASSWORD=Admin123Admin123 /SQLSVCACCOUNT=PASS24\s-SqlEngine /SQLSVCPASSWORD=Admin123Admin123 /CONFIRMIPDEPENDENCYCHANGE=0
```

## Restore database

```powershell
$secret = gcloud secrets versions access 1 --secret pass24-gcs-access --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/pass-demo-2024]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';

    -- Restore database
    RESTORE DATABASE [AdventureWorks2022]
    FROM
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_01.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_02.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_03.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_04.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_05.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_06.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_07.bak',
        URL = 's3://storage.googleapis.com/pass-demo-2024/pass_adventureworks_08.bak'
    WITH 
        MOVE 'AdventureWorks2022' TO 'T:\AdventureWorks2022.mdf',
        MOVE 'AdventureWorks2022_log' TO 'L:\AdventureWorks2022_log.ldf',
        STATS = 10, 
        RECOVERY,
        REPLACE;
    GO
"@;
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
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-4.12";
Set-Location -Path $pathHammerdb;

# Start first run
.\hammerdbcli auto $pathTools/pass_run_1.tcl

# Start second run
.\hammerdbcli auto $pathTools/pass_run_2.tcl
```