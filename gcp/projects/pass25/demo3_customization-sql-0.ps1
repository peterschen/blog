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
    FILENAME = 'L:\pass.ldf'
);
GO
"@;
        DependsOn = "[Script]InitDisk"
        PsDscRunAsCredential = $Credential
    }
}