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
        "RSAT-Clustering",
        "RSAT-Storage-Replica",
        "RSAT-ADDS",
        "RSAT-AD-PowerShell",
        "RSAT-DNS-Server",
        "RSAT-File-Services",
        "Web-Mgmt-Console",
        "GPMC"
    );

    $rules = @(
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

        Script "DownloadChrome"
        {
            GetScript = {
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "chrome.msi";
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
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "chrome.msi";
                Invoke-WebRequest -Uri "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi" -OutFile $path;
            }
        }

        Package "InstallChrome"
        {
            Ensure = "Present"
            Name = "Google Chrome"
            ProductID = ""
            Path = "C:\Windows\temp\chrome.msi"
            Arguments = "/quiet"
            DependsOn = "[Script]DownloadChrome"
        }

        Script "DownloadMremoteng"
        {
            GetScript = {
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mremoteng.msi";
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
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mremoteng.msi";
                Invoke-WebRequest -Uri "https://github.com/mRemoteNG/mRemoteNG/releases/download/v1.76.20/mRemoteNG-Installer-1.76.20.24615.msi" -OutFile $path;
            }
        }

        Package "InstallMremoteng"
        {
            Ensure = "Present"
            Name = "mRemoteNG"
            ProductID = ""
            Path = "C:\Windows\temp\mremoteng.msi"
            Arguments = "/quiet"
            DependsOn = "[Script]DownloadMremoteng"
        }

        Script "DownloadVscode"
        {
            GetScript = {
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "vscode.exe";
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
                $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "vscode.exe";
                Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?Linkid=852157" -OutFile $path;
            }
        }

        Package "InstallVscode"
        {
            Ensure = "Present"
            Name = "Microsoft Visual Studio Code"
            ProductID = ""
            Path = "C:\Windows\temp\vscode.exe"
            Arguments = "/VERYSILENT"
            DependsOn = "[Script]DownloadVscode"
        }

        if($Parameters.enableSsms)
        {
            Script "DownloadSsms"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "SSMS-Setup-ENU.exe";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "SSMS-Setup-ENU.exe";
                    Invoke-WebRequest -Uri "https://aka.ms/ssmsfullsetup" -OutFile $path;
                }
            }

            Package "InstallSsms"
            {
                Ensure = "Present"
                Name = "Microsoft SQL Server Management Studio"
                ProductID = ""
                Path = "C:\Windows\temp\SSMS-Setup-ENU.exe"
                Arguments = "/install /quiet"
                DependsOn = "[Script]DownloadSsms"
            }
        }

        if($Parameters.enableHammerdb)
        {
            Script "DownloadMsoledbsql"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "msoledbsql.msi";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "msoledbsql.msi";
                    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2117515" -OutFile $path;
                }
            }

            Package "InstallMsoledb"
            {
                Ensure = "Present"
                Name = "Microsoft OLE DB Driver for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\msoledbsql.msi"
                Arguments = "/install /quiet"
                DependsOn = "[Script]DownloadMsoledbsql"
            }

            Script "DownloadHammerdb"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "hammerdb.zip";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "hammerdb.zip";
                    Invoke-WebRequest -Uri "https://github.com/TPC-Council/HammerDB/releases/download/v3.3/HammerDB-3.3-Win.zip" -OutFile $path;
                }
            }

            Archive "ExpandHammerdb"
            {
                Destination = "c:\tools\hammerdb"
                Path = "C:\Windows\temp\hammerdb.zip"
                DependsOn = "[Script]DownloadHammerdb"
            }
        }

        if($Parameters.enableIometer)
        {
            Script "DownloadIometer"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "iometer.zip";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "iometer.zip";
                    $timestamp = Get-Date -UFormat %s -Millisecond 0;
                    $uri = "https://downloads.sourceforge.net/project/iometer/iometer-stable/1.1.0/iometer-1.1.0-win64.x86_64-bin.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiometer%2Ffiles%2Fiometer-stable%2F1.1.0%2Fiometer-1.1.0-win64.x86_64-bin.zip%2Fdownload&ts=$timestamp";
                    Invoke-WebRequest -Uri $uri -OutFile $path;
                }
            }

            Archive "ExpandIometer"
            {
                Destination = "c:\tools\iometer"
                Path = "C:\Windows\temp\iometer.zip"
                DependsOn = "[Script]DownloadIometer"
            }
        }

        if($Parameters.enableDiskspd)
        {
            Script "DownloadDiskspd"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "diskspd.zip";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "diskspd.zip";
                    $uri = "https://github.com/microsoft/diskspd/releases/download/v2.0.21a/DiskSpd.zip";
                    Invoke-WebRequest -Uri $uri -OutFile $path;
                }
            }

            Archive "ExpandDiskspd"
            {
                Destination = "c:\tools\diskspd"
                Path = "C:\Windows\temp\diskspd.zip"
                DependsOn = "[Script]DownloadDiskspd"
            }
        }
    }
}
