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
        "FS-iSCSITarget-Server"
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

        $sizeDiskData = $Parameters.sizeDiskData;
        Script "FormatDisk"
        {
            GetScript = {
                $volume = Get-Volume -DriveLetter D -ErrorAction "SilentlyContinue";
                if($null -ne $volume)
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
                $disk = Get-PhysicalDisk -CanPool $true | Where-Object -Property Size -EQ -Value ($Using:sizeDiskData * 1GB);
                Clear-Disk -UniqueId $disk.UniqueId -RemoveData -RemoveOEM -Confirm:$false -ErrorAction "SilentlyContinue";
                Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle GPT -PassThru |
                    New-Partition -UseMaximumSize -DriveLetter "D" |
                    Format-Volume -FileSystem "NTFS" -NewFileSystemLabel "data" |
                    Out-Null;
            }
        }

        $nameTarget = "$($Parameters.nameTarget).$($Parameters.nameDomain)";
        Script "NewIscsiTarget"
        {
            GetScript = {
                $target  = Get-IscsiServerTarget -TargetName $Using:nameTarget -ErrorAction "SilentlyContinue";
                if($null -ne $target -and $target.InitiatorIds.Length -gt 0 -and $target.InitiatorIds[0].Value -eq "iqn.1991-05.com.microsoft:$Using:nameTarget")
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
                New-IscsiServerTarget -TargetName $Using:nameTarget -InitiatorIds @("IQN:iqn.1991-05.com.microsoft:$Using:nameTarget")
            }
        }

        Script "NewIscsiVirtualDisk"
        {
            GetScript = {
                $disk  = Get-IscsiVirtualDisk -Path "D:\data.vhdx" -ErrorAction "SilentlyContinue";
                if($null -ne $disk -and (Test-Path -Path "D:\data.vhdx"))
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
                Remove-Item -Path "D:\data.vhdx" -Force -ErrorAction "SilentlyContinue";
                New-IscsiVirtualDisk -Path "D:\data.vhdx" -UseFixed -Size 9GB;
                Add-IscsiVirtualDiskTargetMapping -TargetName $Using:nameTarget -Path "D:\data.vhdx";
            }

            DependsOn = "[Script]FormatDisk"
        }
    }
}
