# Configure

```powershell
$secret = gcloud secrets versions access 1 --secret smtoff-gcs --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/cbpetersen-smtoff]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';

    -- Restore database
    RESTORE DATABASE [smtoff]
    FROM
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_01.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_02.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_03.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_04.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_05.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_06.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_07.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_08.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_09.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_10.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_11.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_12.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_13.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_14.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_15.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_16.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_17.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_18.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_19.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_20.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_21.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_22.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_23.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_24.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_25.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_26.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_27.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_28.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_29.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_30.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_31.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_32.bak'
    WITH 
        MOVE 'smtoff' TO 'T:\smtoff.mdf',
        MOVE 'smtoff_log' TO 'T:\smtoff_log.ldf',
        STATS = 10, 
        RECOVERY,
        REPLACE;
    GO

    ALTER DATABASE [smtoff] MODIFY FILE ( NAME = N'smtoff_log', SIZE = 64GB, FILEGROWTH = 64MB, MAXSIZE = UNLIMITED)
    ALTER DATABASE [smtoff] SET RECOVERY SIMPLE;
    GO
"@;
```

```powershell
$counters = @(
    '\\sql-0\Processor(_Total)\% Processor Time',
    '\\sql-0\PhyiscalDisk(1 D:)\Disk Bytes/sec',
    '\\sql-0\PhyiscalDisk(1 D:)\Disk Transfer/sec'
)
Get-Counter -Counter $counters -SampleInterval 1 -Continous | ForEach-Object {
    $_.CounterSamples | ForEach-Object {
        [PSCustomObject]@{
            TimeStamp = $_.TimeStamp
            Path = $_.Path
            Value = $_.CookedValue
        }
    }
} | Export-Csv -Path PerfMonCounters.csv -NoTypeInformation

$job = Start-Job -Name "smtoff" -ScriptBlock {
    $counters = @(
        '\\sql-0\Processor(_Total)\% Processor Time',
        '\\sql-0\PhyiscalDisk(1 D:)\Disk Bytes/sec',
        '\\sql-0\PhyiscalDisk(1 D:)\Disk Transfer/sec'
    )
    Get-Counter -Counter $counters -SampleInterval 1 -Continous
};

param($users);
$job = Get-Job -Name "smtoff";
Stop-Job -Job $job;
Receive-Job -Job $job | ForEach-Object {
    $_.CounterSamples | ForEach-Object {
        [PSCustomObject]@{
            Users = $users
            TimeStamp = $_.TimeStamp
            Path = $_.Path
            Value = $_.CookedValue
        }
    }
} | Export-Csv -Path c:\tools\.csv -NoTypeInformation
```

# Save

```powershell
gsutil cp $env:TEMP\hammer.DB gs://cbpetersen-smtoff/hammerdb/
gsutil cp c:\tools\perfcounter.csv gs://cbpetersen-smtoff/data/
```

```powershell
$secret = gcloud secrets versions access 1 --secret smtoff-gcs --project cbpetersen-shared;
sqlcmd -S "tcp:sql-0" -Q @"
    -- Configure credential for GCS
	IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
		CREATE CREDENTIAL [s3://storage.googleapis.com/cbpetersen-smtoff]
		WITH
			IDENTITY = 'S3 Access Key',
			SECRET = '${secret}';
    
    BACKUP DATABASE [smtoff]
    TO
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_01.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_02.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_03.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_04.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_05.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_06.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_07.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_08.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_09.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_10.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_11.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_12.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_13.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_14.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_15.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_16.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_17.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_18.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_19.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_20.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_21.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_22.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_23.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_24.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_25.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_26.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_27.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_28.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_29.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_30.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_31.bak',
        URL = 's3://storage.googleapis.com/cbpetersen-smtoff/db/smtoff_32.bak'
    WITH 
        FORMAT,
        STATS = 10,
        COMPRESSION;
    GO
"@;
```

# Run

```powershell
$configurations = @(
    @{
        Sku = "c4-highcpu-16"
        ThreadsPerCore = 2
    },

    @{
        Sku = "c4-highcpu-16"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c4-highcpu-32"
        ThreadsPerCore = 2
    },

    @{
        Sku = "c4-highcpu-32"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c4-highcpu-48"
        ThreadsPerCore = 2
    },

    @{
        Sku = "c4-highcpu-48"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c4-highcpu-96"
        ThreadsPerCore = 2
    },

    @{
        Sku = "c4-highcpu-96"
        ThreadsPerCore = 1
    }
)

$target = "sql-0";
foreach($configuration in $configurations)
{
    gcloud compute instances stop $target
    gcloud compute instances set-machine-type $target --machine-type $configuration.Sku
    gcloud compute instances update-from-file $target --source c:\tools\config_tpc_$($configuration.ThreadsPerCore).yaml
    gcloud compute instance start

    Start-Sleep -Minutes 2;
}

```