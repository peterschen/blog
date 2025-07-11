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
            # Ensure status of disks is current
            Get-PhysicalDisk | Reset-PhysicalDisk;

            $disks = Get-PhysicalDisk -CanPool $true;
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
                icacls ${driveletter}:\ /grant "PASS\s-SqlEngine:(OI)(CI)(F)"

                $index++;
            }
        }
    }

    Script "CreateCredential"
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

    SqlScriptQuery "RestoreDatabase"
    {
        Id = "RestoreDatabase"
        ServerName = "sql-0"
        InstanceName = "MSSQLSERVER"

        TestQuery = @"
IF (SELECT COUNT(name) FROM sys.databases WHERE name = 'AdventureWorks2022') = 0
BEGIN
    RAISERROR ('Did not find database [AdventureWorks2022]', 16, 1)
END
ELSE
BEGIN
    PRINT 'Found database [AdventureWorks2022]'
END
"@
        GetQuery = "SELECT name FROM sys.databases WHERE name = 'AdventureWorks2022'"
        SetQuery = @"
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
    MOVE 'AdventureWorks2022' TO 'T:\AdventureWorks2022.mdf',
    MOVE 'AdventureWorks2022_log' TO 'L:\AdventureWorks2022_log.ldf',
    STATS = 10, 
    RECOVERY,
    REPLACE;
GO
"@;
        DependsOn = "[Script]CreateCredential"
        PsDscRunAsCredential = $Credential
    }
}