configuration ConfigurationWorkload
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [securestring] $Password,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters        
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        ComputerManagementDsc, ActiveDirectoryDsc;

    $features = @(
        "NET-Framework-Features",
        "Storage-Replica"
        "RSAT-Storage-Replica"
    );

    $rules = @(
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP"
    );

    $admins = @(
        "$($Parameters.nameDomain)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.nameDomain)\Administrator", $Password);

    Node $ComputerName
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        foreach($rule in $rules)
        {
            Firewall "$rule"
            {
                Name = "$rule"
                Ensure = "Present"
                Enabled = "True"
            }
        }

        WaitForADDomain "WFAD"
        {
            DomainName  = $Parameters.nameDomain
            Credential = $domainCredential
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $Parameters.nameDomain
            Credential = $domainCredential
            DependsOn = "[WaitForADDomain]WFAD"
        }

        Group "G-Administrators"
        {
            GroupName = "Administrators"
            Credential = $domainCredential
            MembersToInclude = $admins
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteDesktopUsers"
        {
            GroupName = "Remote Desktop Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.nameDomain)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.nameDomain)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Service "MSiSCSI"
        {
            Name = "MSiSCSI"
            StartupType = "Automatic"
            State = "Running"
        }
        
        $targetServers = @(
            "sr-source",
            "sr-target"
        );

        WaitForAll "IscsiReady"
        {
            ResourceName = "[Script]NewIscsiVirtualDisk"
            NodeName = $targetServers
            RetryIntervalSec = 5
            RetryCount = 120
            DependsOn = "[Service]MSiSCSI"
        }

        Script "ConnectIscsi"
        {
            GetScript = {
                $result = "Present";
                
                foreach($targetServer in $Using:targetServers)
                {
                    $target = Get-IscsiTargetPortal -TargetPortalAddress "$targetServer.sandbox.lab" -ErrorAction "SilentlyContinue";
                    if($null -eq $target)
                    {
                        $result = "Absent";
                        break;
                    }
                }

                return @{Ensure = $result};
            }

            TestScript = {
                $state = [scriptblock]::Create($GetScript).Invoke();
                return $state.Ensure -eq "Present";
            }

            SetScript = {
                foreach($targetServer in $Using:targetServers)
                {
                    New-IscsiTargetPortal -TargetPortalAddress "$targetServer.sandbox.lab";
                }

                $targets = Get-IscsiTarget | Where-Object -Property IsConnected -EQ -Value $false;
                foreach($target in $targets)
                { 
                    Connect-IscsiTarget -NodeAddress $target.NodeAddress -IsPersistent $true -ErrorAction "SilentlyContinue";
                }
            }

            DependsOn = "[WaitForAll]IscsiReady"
        }

        $sizeDiskData = $Parameters.sizeDiskData - 1;
        $sizeDiskLog = $Parameters.sizeDiskLog;
        Script "FormatDisks"
        {
            GetScript = {
                $volumeD = Get-Volume -DriveLetter "D" -ErrorAction "SilentlyContinue";
                $volumeE = Get-Volume -DriveLetter "E" -ErrorAction "SilentlyContinue";
                $volumeF = Get-Volume -DriveLetter "F" -ErrorAction "SilentlyContinue";
                $volumeG = Get-Volume -DriveLetter "G" -ErrorAction "SilentlyContinue";
                
                if($null -ne $volumeD -and $null -ne $volumeE -and $null -ne $volumeF -and $null -ne $volumeG)
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
                $devices = @(1, 2);
                foreach($device in $devices)
                {
                    $disk = Get-PhysicalDisk -DeviceNumber $device;
                    Clear-Disk -UniqueId $disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
                    Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle GPT -PassThru -ErrorAction "SilentlyContinue" |
                        New-Partition -UseMaximumSize -DriveLetter ([char](67 + $device)) |
                        Format-Volume -FileSystem "NTFS" -NewFileSystemLabel "log" |
                        Out-Null;
                }
                
                $devices = @(3, 4);
                foreach($device in $devices)
                {
                    $disk = Get-PhysicalDisk -DeviceNumber $device;
                    Clear-Disk -UniqueId $disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
                    Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle GPT -PassThru -ErrorAction "SilentlyContinue" |
                        New-Partition -UseMaximumSize -DriveLetter ([char](67 + $device)) |
                        Format-Volume -FileSystem "NTFS" -NewFileSystemLabel "data" |
                        Out-Null;
                }
            }

            DependsOn = "[Script]ConnectIscsi"
        }

        Script "EnableStorageReplica"
        {
            GetScript = {
                $partnership  = Get-SRPartnership -SourceComputerName $Using:ComputerName -DestinationComputerName $Using:ComputerName;
                if($null -ne $partnership)
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
                New-SRPartnership -SourceComputerName $Using:ComputerName -SourceRGName "sr-source" -SourceVolumeName "f:" -SourceLogVolumeName "d:" `
                    -DestinationComputerName $Using:ComputerName -DestinationRGName "sr-target" -DestinationVolumeName "g:" -DestinationLogVolumeName "e:";
            }

            DependsOn = "[Script]FormatDisks"
        }
    }
}