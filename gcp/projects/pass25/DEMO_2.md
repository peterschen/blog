# Demo 2

SQL Server FCI with shared storage provided by Hyperdisk

## Prep

### Install SQL Server on sql-0

```powershell
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

$zone = (Invoke-RestMethod `
          -Headers @{'Metadata-Flavor' = 'Google'} `
          -Uri "http://metadata.google.internal/computeMetadata/v1/instance/zone")

$index = $zone.LastIndexOf("/")
$length = $zone.Length - $index - 3;
$region = $zone.Substring($index + 1, $length);

$ip = gcloud compute addresses describe wsfc-sql --region $region --format "value(address)";

# Validate cluster
Test-Cluster -Include "List Disks";

c:\sql_server_install\setup.exe /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS /Q /ACTION=InstallFailoverCluster /FEATURES=SQLEngine,FullText /INSTANCENAME=MSSQLSERVER /FAILOVERCLUSTERIPADDRESSES="IPv4;$ip;Cluster Network 1;255.255.0.0" /FAILOVERCLUSTERDISKS="Cluster Disk 1" /FAILOVERCLUSTERNETWORKNAME=sql /AGTSVCACCOUNT\s-SqlAgent /AGTSVCPASSWORD=Admin123Admin123 /SQLSVCACCOUNT=PASS\s-SqlEngine /SQLSVCPASSWORD=Admin123Admin123 /INSTALLSQLDATADIR=C:\ClusterStorage\Volume1 /SqlSysadminAccounts=PASS\g-SqlAdministrators
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

c:\sql_server_install\setup.exe /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS /Q /ACTION=AddNode /INSTANCENAME=MSSQLSERVER /FAILOVERCLUSTERIPADDRESSES="IPv4;$ip;Cluster Network 1;255.255.0.0" /FAILOVERCLUSTERNETWORKNAME=sql /AGTSVCACCOUNT=PASS\s-SqlAgent /AGTSVCPASSWORD=Admin123Admin123 /SQLSVCACCOUNT=PASS\s-SqlEngine /SQLSVCPASSWORD=Admin123Admin123 /CONFIRMIPDEPENDENCYCHANGE=0
```

### Configure secret for GCS

```powershell
$secret = gcloud secrets versions access 1 --secret pass-demo-gcs --project cbpetersen-shared;
sqlcmd -S "tcp:sql" -Q @"
    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [cbpetersen-demos]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';
"@
```

## Setting the scene

1. Show disks in Cloud Console
    * [Disks](https://console.cloud.google.com/compute/disks)
    * Elaborate on multi-writer configuration
1. Show Windows Server Failover Cluster
    * Cluster Shared Volume
1. Restore database

```sql
-- Restore database
RESTORE DATABASE [AdventureWorks2022]
FROM
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_01.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_02.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_03.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_04.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_05.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_06.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_07.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo2_08.bak'
WITH
    WITH CREDENTIAL = 'cbpetersen-demos',
    MOVE 'AdventureWorks2022' TO 'C:\ClusterStorage\Volume1\MSSQL16.MSSQLSERVER\AdventureWorks2022.mdf',
    MOVE 'AdventureWorks2022_log' TO 'C:\ClusterStorage\Volume1\MSSQL16.MSSQLSERVER\AdventureWorks2022_log.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO
```

4. Create record
```sql
USE AdventureWorks2022;

INSERT INTO Person.BusinessEntity (
    ModifiedDate
)
VALUES (
    CURRENT_TIMESTAMP
)

INSERT INTO Person.Person (
    BusinessEntityID,
    PersonType,
    NameStyle,
    Title,
    FirstName,
    MiddleName,
    LastName,
    Suffix,
    EmailPromotion,
    AdditionalContactInfo,
    Demographics
)
VALUES (
    IDENT_CURRENT('Person.BusinessEntity'),
    'EM',
    0,
    'Mr.',
    'Christoph',
    'B',
    'Petersen',
    NULL,
    0, 
    null, 
    '<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"><TotalPurchaseYTD>0</TotalPurchaseYTD></IndividualSurvey>'
);
GO
```

5. Query for the record

```sql
USE AdventureWorks2022;

SELECT
	*
FROM 
	Person.Person
WHERE FirstName = 'Christoph'
AND LastName = 'Petersen'
GO
```

5. Failover to sql-1
6. Query for record again