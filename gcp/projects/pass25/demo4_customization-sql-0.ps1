configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        SqlServerDsc;

    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Credential.Password);

    Script "InitDisk"
    {
        GetScript = {
            $disks = Get-Disk | Where-Object -Property PartitionStyle -Value RAW -EQ;
            if($disks -eq $null)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }
            
            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
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
    }

    Script "ConfigureDatabase"
    {
        GetScript = {
            $result = Invoke-Sqlcmd -Query "SELECT name FROM sys.credentials WHERE credential_identity = 'S3 Access Key'" -ServerInstance "sql-0";
            if($result -ne $null)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }
            
            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
            $secret = gcloud secrets versions access 1 --secret pass-demo-gcs --project cbpetersen-shared;
            $query = @"
-- Server configuration
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 20480;
EXEC sp_configure 'recovery interval (min)', 15;
RECONFIGURE;

-- Configure credential for GCS
IF NOT EXISTS (SELECT * FROM sys.credentials WHERE credential_identity = 'S3 Access Key')
    CREATE CREDENTIAL [cbpetersen-demos]
    WITH
        IDENTITY = 'S3 Access Key',
        SECRET = '${secret}';
"@;
            Invoke-Sqlcmd -Query $query -ServerInstance "sql-0";
        }
    }

    $letter = [int][char]'T';
    for($i = 0; $i -lt 2; $i++)
    {
        SqlScriptQuery "RestoreDatabase${i}"
        {
            Id = "RestoreDatabase${i}"
            ServerName = "sql-0"
            InstanceName = "MSSQLSERVER"

            TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'demo4_${i}') = 0
BEGIN
    RAISERROR ('Did not find database [demo4_${i}]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [demo4_${i}]'
END
"@
            GetQuery = "SELECT name FROM sys.databases WHERE name = 'demo4_${i}'"
            SetQuery = @"
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
    CREDENTIAL = 'cbpetersen-demos',
    MOVE 'demo4' TO '$([char]$letter):\demo4_${i}.mdf',
    MOVE 'demo4_log' TO '$([char]$letter):\demo4_${i}.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO

ALTER DATABASE [demo4_${i}] SET RECOVERY SIMPLE;
ALTER DATABASE [demo4_${i}] SET TORN_PAGE_DETECTION OFF;
ALTER DATABASE [demo4_${i}] SET PAGE_VERIFY NONE;
ALTER DATABASE [demo4_${i}] SET TARGET_RECOVERY_TIME = 15 MINUTES;
"@;
            DependsOn = "[Script]ConfigureDatabase"
            PsDscRunAsCredential = $Credential
        }

        $letter++;
    }

    SqlScriptQuery "CreateDatabase"
    {
        Id = "CreateDatabase"
        ServerName = "sql-0"
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'pass') = 0
BEGIN
    RAISERROR ('Did not find database [pass]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [pass]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'pass'"
        SetQuery = @"
CREATE DATABASE [pass]
ON (
    NAME = pass,
    FILENAME = 'T:\pass.mdf'
)
LOG ON (
    NAME = pass_log,
    FILENAME = 'T:\pass.ldf'
);
GO
"@;
        DependsOn = "[Script]ConfigureDatabase"
        PsDscRunAsCredential = $Credential
    }
}
