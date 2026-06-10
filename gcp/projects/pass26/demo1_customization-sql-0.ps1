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
        ComputerManagementDsc, SqlServerDsc;

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
            $letter = 'T';
            $disks = Get-Disk | Where-Object -Property PartitionStyle -Value RAW -EQ | Get-PhysicalDisk;
            $subsystem = Get-StorageSubSystem -Model "Windows Storage";

            $pool = New-StoragePool -FriendlyName "pass" -PhysicalDisks $disks `
                -StorageSubSystemUniqueId $subsystem.UniqueId -ProvisioningTypeDefault "Fixed" `
                -ResiliencySettingNameDefault "Simple";

            $disk = New-VirtualDisk -FriendlyName "pass" -StoragePoolUniqueId $pool.UniqueId -UseMaximumSize;

            # Initialize disk
            Initialize-Disk -UniqueId $disk.UniqueId -PassThru | 
                New-Partition -DriveLetter $letter -UseMaximumSize | 
                Format-Volume;

            # Add access for s-SqlEngine to the disk
            $acl = Get-Acl -Path "${letter}:\";
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("PASS\s-SqlEngine", "FullControl", "Allow");
            $acl.SetAccessRule($accessRule);
            $acl | Set-Acl -Path "${letter}:\";
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
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_configure 'max server memory', 153600;
RECONFIGURE WITH OVERRIDE;
GO

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
}
