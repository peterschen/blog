configuration Config
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="5.5.0.0"},
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="8.0.0.0"},
        @{ModuleName="ComputerManagementDsc";ModuleVersion="6.0.0.0"};

    node localhost
    {
        # Fix issues with downloading from GitHub due to deprecation of TLS 1.0 and 1.1
        # https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405#issuecomment-379932793
        Registry SchUseStrongCrypto
        {
            Key                         = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        Registry SchUseStrongCrypto64
        {
            Key                         = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        File "tools"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools"
        }

        File "DiskSpd"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools\DiskSpd"
            DependsOn = "[File]tools"
        }

        xRemoteFile "DiskSpd"
        {
            Uri = "https://gallery.technet.microsoft.com/DiskSpd-A-Robust-Storage-6ef84e62/file/199535/2/DiskSpd-2.0.21a.zip"
            DestinationPath = "c:\tools\DiskSpd"
            DependsOn = "[File]DiskSpd"
        }

        Archive "PSTools"
        {
            Path = "c:\tools\DiskSpd\DiskSpd-2.0.21a.zip"
            Destination = "C:\tools\DiskSpd"
            DependsOn = "[xRemoteFile]DiskSpd"
        }

        ScheduledTask DiskSpd
        {
            TaskName = "DiskSpd"
            TaskPath = '\Monitoring Hackathon'
            ActionExecutable = "C:\tools\DiskSpd\amd64\diskspd.exe"
            ActionArguments = "-b8K -d200 -o4 -t8 -h -r -w25 -L -Z125M -c1G C:\iotest.dat"
            ScheduleType = "Daily"
            DaysInterval = 1
            RepeatInterval = "00:03:00"
            RepetitionDuration = "Indefinitely"
            ExecutionTimeLimit = "00:02:30"
        }

        ScheduledTask CpuMemoryLoad
        {
            TaskName = "CpuMemoryLoad"
            TaskPath = '\Monitoring Hackathon'
            ActionExecutable = "powershell.exe"
            ActionArguments = "-Command 1..50|%{`$x=1}{[array]`$x+=`$x}"
            ScheduleType = "Daily"
            DaysInterval = 1
            RepeatInterval = "00:03:00"
            RepetitionDuration = "Indefinitely"
            ExecutionTimeLimit = "00:02:30"
        }
    }
}

# Login-AzureRmAccount;
# Publish-AzureRmVMDscConfiguration -ConfigurationPath .\Config.ps1 -ConfigurationDataPath .\Data.psd1 -ResourceGroupName "labassets" `
#     -StorageAccountName "labassets" -ContainerName "monitoring-hackathon" -Force;