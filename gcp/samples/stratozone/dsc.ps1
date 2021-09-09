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
        "NET-Framework-Features"
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

        if($Parameters.enableDomain)
        {
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
        }

        if($Parameters.enableStratozone)
        {
            $redistributables = @{
                "2013" = @{
                    "uri" = "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    "productName" = "Microsoft Visual C++ 2013 x64 Minimum Runtime - 12.0.21005"
                }
                "2015" = @{
                    "uri" = "http://download.microsoft.com/download/2/a/2/2a2ef9ab-1b4b-49f0-9131-d33f79544e70/vc_redist.x64.exe"
                    "productName" = "Microsoft Visual C++ 2015 x64 Minimum Runtime - 14.0.24212"
                }
            };

            foreach($version in $redistributables.Keys)
            {
                $uri = $redistributables[$version]["uri"];
                $productName = $redistributables[$version]["productName"];

                Script "DownloadVcRedistributable-$version"
                {
                    GetScript = {
                        $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "vc_redist_$Using:version.exe";
                        if((Test-Path -Path $path))
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
                        $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "vc_redist_$Using:version.exe";
                        Start-BitsTransfer -Source $Using:uri -Destination $path;
                    }
                }

                Package "InstallVcRedistributable-$version"
                {
                    Ensure = "Present"
                    Name = $productName
                    ProductID = ""
                    Path = "C:\Windows\temp\vc_redist_$version.exe"
                    Arguments = "/install /quiet"
                    DependsOn = "[Script]DownloadVcRedistributable-$version"
                }
            }
            
            Script "DownloadStratozone"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "stratozone.exe";
                    if((Test-Path -Path $path))
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "stratozone.exe";
                    Start-BitsTransfer -Source "https://portal.stratozone.com/Home/DownloadAppliance.aspx?folder=collector" -Destination $path;
                }
            }

            Script "InstallStratozone"
            {
                GetScript = {
                    $path  = "C:\Program Files\StratoProbe";
                    if((Test-Path -Path $path))
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "stratozone.exe";
                    Start-Process -FilePath $path -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES" -Wait;
                }

                DependsOn = "[Package]InstallVcRedistributable-2013","[Package]InstallVcRedistributable-2015","[Script]DownloadStratozone"
            }
        }
    }
}
