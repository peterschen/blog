# Demo 5

Using Async PD to replicate data and log volumes consistently across regions.

## Prep

## Fix deployment

In some cases the disk status is not properly set when starting the replication. These commands will import the resource so the project can be deleted successfully.

```sh
project="terraform output -raw project_id_module3"
zone=="terraform output -raw zone_demo3"

terraform import google_compute_disk_async_replication.demo3_data[0] projects/$project/zones/$zone/disks/data
terraform import google_compute_disk_async_replication.demo3_log[0] projects/$project/zones/$zone/disks/log
```

### Initialize disk on sql-0

```powershell
Invoke-Command -ComputerName "sql-0" -ScriptBlock {
    $disks = Get-PhysicalDisk -CanPool $true | Sort-Object -Descending -Property Size;
    $driveletters = ("T", "L")

    $index = 0;
    foreach($disk in $disks)
    {
        $driveletter = $driveletters[$index];

        # Initialize disks
        Initialize-Disk -UniqueId $disk.UniqueId -PassThru | 
            New-Partition -DriveLetter $driveletter -UseMaximumSize | 
            Format-Volume;

        # Add access for s-SqlEngine
        icacls ${driveletter}:\ /grant "PASS24\s-SqlEngine:(OI)(CI)(F)"

        $index++;
    }
}
```

### Restore database

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
1. Show Asynchronous replication configuration
    * [Asynchronous replication](https://console.cloud.google.com/compute/asynchronousReplication)
1. Write order consistency ensured through consistency groups
1. Show storage configuration on sql-0
    * Disk configuration
    * Explain two separate drives for data and log and impact on consistency

## Show primary database

1. Show database and create sample record

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

SELECT
	*
FROM 
	Person.Person
WHERE FirstName = 'Christoph'
AND LastName = 'Petersen'
GO
```

## Clone replicated disks

1. Create clone from secondary disk and attach it to a VM in that region

```sh
project=`terraform output -raw project_id_demo3`
zone=`terraform output -raw zone_demo3`
zone_secondary=`terraform output -raw zone_secondary_demo3`
group=`gcloud compute resource-policies list --project $project --filter "region=europe-west3" --format "value(self_link)"`

gcloud compute disks bulk create \
    --source-consistency-group-policy=$group \
    --project $project \
    --zone $zone_secondary

# Attach disks
disks=`gcloud compute disks list --project $project --filter "name~data- OR name~log-" --format "value(name)" | sort`
for disk in $disks; do
    gcloud compute instances attach-disk sql-clone-0 \
        --disk $disk \
        --device-name $disk \
        --project $project \
        --zone $zone_secondary
    sleep 5
done
```

2. Show disks in Cloud Console

## Attach database

1. Attach database and run query
```sql
CREATE DATABASE AdventureWorks2022
ON 
	(FILENAME = N'D:\AdventureWorks2022.mdf'),
	(FILENAME = N'E:\AdventureWorks2022_log.ldf')
FOR ATTACH
GO

USE AdventureWorks2022;
SELECT
	*
FROM 
	Person.Person
WHERE FirstName = 'Christoph'
AND LastName = 'Petersen'
GO
```