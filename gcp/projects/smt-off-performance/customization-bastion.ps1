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
        xCredSSP;

    $nodes = @();
    for($i = 0; $i -lt 1; $i++) {
        $nodes += "sql-$i";
    };

    xCredSSP Client
    {
        Ensure = "Present"
        Role = "Client"
        DelegateComputers = $nodes
    }

    $configurations = @();
    for($i = 1; $i -lt 31; $i++)
    {
        $users = $i * 5;
        $configurations += $users;
    }

    Script "SmtoffConfiguration" {
        GetScript = {
            # Write file every time
            $exists = $False;
            if($exists)
            {
                $result = "Present";
            }
            else
            {
                $partition = "Absent";
            }
            
            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
            $contents = @"
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

diset tpcc mssqls_dbase smtoff
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 1
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse false

loadscript
foreach z { $using:configurations } {
    puts "`$z VU TEST"
    vuset vu `$z
    vucreate
    set ppid [ exec powershell "c:/tools/perfcounter_start.ps1 `$z" & ]
    tcstart
    tcstatus
    set jobid [ vurun ]
    runtimer 60
    tcstop
    exec powershell "c:/tools/perfcounter_stop.ps1 `$ppid" &
    vudestroy
}
"@
            Set-Content -Path "c:\tools\hammerdb_smtoff.tcl" -Value $contents -Encoding "ASCII";
        }

        PsDscRunAsCredential = $Credential
    } 

    for($i = 1; $i -lt 3; $i++)
    {
        File "TpcConfig-$i" {
            DestinationPath = "c:\tools\config_tpc_$i.yaml"
            Contents = @"
advancedMachineFeatures:
  threadsPerCore: $i
"@
            Type = "File"
        }
    }

    File ControlScript {
        DestinationPath = "c:\tools\smtoff.ps1"
        Contents = @"
`$ErrorActionPreference = "Stop";
`$configurations = @(
    @{
        Sku = "c3-standard-8-lssd"
        ThreadsPerCore = 2
    },
    
    @{
        Sku = "c3-standard-8-lssd"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c3-standard-22-lssd"
        ThreadsPerCore = 2
    },
    
    @{
        Sku = "c3-standard-22-lssd"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c3-standard-44-lssd"
        ThreadsPerCore = 2
    },
    
    @{
        Sku = "c3-standard-44-lssd"
        ThreadsPerCore = 1
    },

    @{
        Sku = "c3-standard-88-lssd"
        ThreadsPerCore = 2
    },
    
    @{
        Sku = "c3-standard-88-lssd"
        ThreadsPerCore = 1
    }

    # @{
    #     Sku = "c4-highcpu-16"
    #     ThreadsPerCore = 2
    # },

    # @{
    #     Sku = "c4-highcpu-16"
    #     ThreadsPerCore = 1
    # },

    # @{
    #     Sku = "c4-highcpu-32"
    #     ThreadsPerCore = 2
    # },

    # @{
    #     Sku = "c4-highcpu-32"
    #     ThreadsPerCore = 1
    # },

    # @{
    #     Sku = "c4-highcpu-48"
    #     ThreadsPerCore = 2
    # },

    # @{
    #     Sku = "c4-highcpu-48"
    #     ThreadsPerCore = 1
    # },

    # @{
    #     Sku = "c4-highcpu-96"
    #     ThreadsPerCore = 2
    # },

    # @{
    #     Sku = "c4-highcpu-96"
    #     ThreadsPerCore = 1
    # }
)

`$date = (Get-Date -Format "yyyy-MM-ddTHH:mmK");

Write-Host "Restoring HammerDB from GCS";
gsutil cp gs://cbpetersen-smtoff/hammerdb/hammer.DB `$env:TEMP\hammer.DB;

`$target = "sql-0";
`$region = "europe-west4";
`$zone = "europe-west4-a";
`$previousVmName = "sql-0"; 

Write-Host "Stopping VM";
gcloud compute instances stop `$previousVmName --discard-local-ssd true --zone `$zone --quiet;

Write-Host "Detaching boot disk";
gcloud compute instances detach-disk `$previousVmName --device-name "persistent-disk-0" --zone `$zone;

foreach(`$configuration in `$configurations)
{
    Write-Host "Creating new instance";
    `$vmName = "sql-`$(`$configuration.Sku)-t`$(`$configuration.ThreadsPerCore)";
    gcloud compute instances create `$vmName ``
        --zone `$zone ``
        --machine-type `$(`$configuration.Sku) ``
        --network-interface "stack-type=IPV4_ONLY,subnet=europe-west4,no-address" ``
        --scopes https://www.googleapis.com/auth/cloud-platform ``
        --tags "mssql,rdp,wsfc" ``
        --disk "boot=yes,device-name=persistent-disk-0,mode=rw,name=sql-0" ``
        --shielded-secure-boot ``
        --shielded-vtpm ``
        --shielded-integrity-monitoring ``
        --threads-per-core 2;

    `$ip = gcloud compute instances describe `$vmName --zone `$zone --format "value(networkInterfaces.networkIP)";

    Write-Host "Starting VM";
    gcloud compute instances start `$vmName --zone `$zone --quiet;

    # Update DNS
    Write-Host "Updating DNS"
    `$oldRecord = Get-DnsServerResourceRecord -ComputerName "dc-0" -ZoneName "smtoff.lab" -Name `$target -RRType "A";
    `$newRecord = [ciminstance]::new(`$oldRecord);
    `$newRecord.RecordData.IPv4Address = `$ip;
    Set-DnsServerResourceRecord -ComputerName "dc-0" -NewInputObject `$newRecord -OldInputObject `$oldRecord -ZoneName "smtoff.lab";
    ipconfig /flushdns

    # Wait for SQL Server to become available
    `$connectionSuceeded = `$False;
    Write-Host "Waiting for SQL Server to become available";
    while(-not `$connectionSucceeded)
    {
        `$result = Test-NetConnection -ComputerName `$ip -Port 1433;
        `$connectionSucceeded = `$result.TcpTestSucceeded;
        Start-Sleep -Seconds 10;
    }

    Invoke-Command -ComputerName `$target -ScriptBlock {
        `$friendlyName = "lssd-stripe";
        `$disks = Get-PhysicalDisk -CanPool `$true;
        `$subsystem = Get-StorageSubSystem -Model "Windows Storage";

        # Create storage pool across all disks
        `$pool = New-StoragePool -FriendlyName `$friendlyName -PhysicalDisks `$disks ``
            -StorageSubSystemUniqueId `$subsystem.UniqueId -ProvisioningTypeDefault "Fixed" ``
            -ResiliencySettingNameDefault "Simple";

        # Create virtual disk in the pool
        `$disk = New-VirtualDisk -FriendlyName `$friendlyName -StoragePoolUniqueId `$pool.UniqueId -UseMaximumSize;

        # Initialize disk
        Initialize-Disk -UniqueId `$disk.UniqueId -PassThru | 
            New-Partition -DriveLetter "T" -UseMaximumSize | 
            Format-Volume;

        # Add access for s-SqlEngine
        icacls t:\ /grant "s-SqlEngine:(OI)(CI)(F)"
    }

    # Restore database
    Write-Host "Restoring database";
    sqlcmd -S "tcp:`$target" -Q `@"
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
"`@;

    # Run benchmark
    Write-Host "Running HammerDB";
    c:\tools\hammerdb_smtoff.ps1

    # Save data
    Write-Host "Saving data to GCS";
    gsutil cp `$env:TEMP\hammer.DB gs://cbpetersen-smtoff/hammerdb/
    gsutil cp c:\tools\perfcounter.csv gs://cbpetersen-smtoff/data/`$date/perfcounter-`$(`$configuration.Sku)-t`$(`$configuration.ThreadsPerCore).csv

    # Clean up
    Remove-Item -Path "c:\tools\perfcounter.csv" -ErrorAction "SilentlyContinue";
    Remove-Item -Path "c:\tools\config.yaml" -ErrorAction "SilentlyContinue";

    Write-Host "Stopping VM";
    gcloud compute instances stop `$vmName --discard-local-ssd true --zone `$zone --quiet;

    Write-Host "Detaching boot disk";
    gcloud compute instances detach-disk `$vmName --device-name "persistent-disk-0" --zone `$zone;

    Write-Host "Deleting VM";
    gcloud compute instances delete `$vmName --zone `$zone --quiet;

    `$previousVmName = `$vmName;

    if((Test-Path -Path "c:\tools\smtoff-stop.txt"))
    {
        Write-Host "smtoff-stop.txt found, stopping run";
        break;
    }
}
"@
        Type = "File"
    }

    File SmtoffScript {
        DestinationPath = "c:\tools\hammerdb_smtoff.ps1"
        Contents = @"
`$path = (Get-Location).Path;

try
{
    `$pathTools = "C:\tools";
    `$pathHammerdb = Join-Path -Path `$pathTools -ChildPath "hammerdb\HammerDB-4.12";
    Set-Location -Path `$pathHammerdb;

    .\hammerdbcli auto `$pathTools/hammerdb_smtoff.tcl
}
finally
{
    Set-Location -Path `$path;
}
"@;
        Type = "File"
    }

    File PerfCounterStart {
        DestinationPath = "c:\tools\perfcounter_start.ps1"
        Contents = @"
param(`$users);
`$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\PhysicalDisk(1 T:)\Disk Bytes/sec",
    "\PhysicalDisk(1 T:)\Disk Transfers/sec",
    "\SQLServer:Buffer Manager\Lazy writes/sec"
)

Get-Counter -Counter `$counters -ComputerName "sql-0" -SampleInterval 1 -Continuous | ForEach-Object {
    `$_.CounterSamples | ForEach-Object {
        [PSCustomObject]@{
            Users = [int]::Parse(`$users)
            TimeStamp = `$_.TimeStamp
            Path = `$_.Path
            Value = `$_.CookedValue
        }
    }
} |  Export-Csv -Path "c:\tools\perfcounter.csv" -Append -NoTypeInformation;
"@;
        Type = "File"
    }

    File PerfCounterStop {
        DestinationPath = "c:\tools\perfcounter_stop.ps1"
        Contents = @"
param(`$processId);
Stop-Process -Id `$processId;
"@;
        Type = "File"
    }
}
