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
        "RSAT-ADCS",
        "Web-Mgmt-Console",
        "GPMC"
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

        File "benchmark.ps1" 
        {
            DestinationPath = "c:\tools\benchmark.ps1"
            Type = "File"
            Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Parameters.fileContentBenchmark))
        }

        File "benchmark_configurations.json" 
        {
            DestinationPath = "c:\tools\benchmark_configurations.json"
            Type = "File"
            Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Parameters.fileContentBenchmarkConfigurations))
        }

        File "benchmark_scenarios.json" 
        {
            DestinationPath = "c:\tools\benchmark_scenarios.json"
            Type = "File"
            Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Parameters.fileContentBenchmarkScenarios))
        }

        if($Parameters.enableDomain)
        {
            WaitForADDomain "WFAD"
            {
                DomainName  = $Parameters.nameDomain
                Credential = $domainCredential
                WaitTimeout = 600
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

#region Chrome
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
                Start-BitsTransfer -Source "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi" -Destination $path;
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
#endregion

#region mRemoteNG
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
                Start-BitsTransfer -Source "https://github.com/mRemoteNG/mRemoteNG/releases/download/v1.76.20/mRemoteNG-Installer-1.76.20.24615.msi" -Destination $path;
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
#endregion

#region Visual Studio Code
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
                Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?Linkid=852157" -Destination $path;
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
#endregion

#region SQL Server Management Studio
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
                    Start-BitsTransfer -Source "https://aka.ms/ssmsfullsetup" -Destination $path;
                }
            }

            Package "InstallSsms"
            {
                Ensure = "Present"
                Name = "SQL Server Management Studio"
                ProductID = ""
                Path = "C:\Windows\temp\SSMS-Setup-ENU.exe"
                Arguments = "/install /quiet"
                DependsOn = "[Script]DownloadSsms"
            }
        }
#endregion

#region HammerDB
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
                    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?linkid=2278038" -Destination $path;
                }
            }

            Script "DownloadMsodbcsql"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "msodbcsql.msi";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "msodbcsql.msi";
                    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?linkid=2280794" -Destination $path;
                }
            }

            Script "DownloadMssqlcmd"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mssqlcmd.msi";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mssqlcmd.msi";
                    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?linkid=2230791" -Destination $path;
                }
            }

            Package "InstallMsoledb"
            {
                Ensure = "Present"
                Name = "Microsoft OLE DB Driver 19 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\msoledbsql.msi"
                Arguments = "/quiet /log c:\windows\temp\oledb.log IACCEPTMSOLEDBSQLLICENSETERMS=YES"
                DependsOn = "[Script]DownloadMsoledbsql"
            }

            Package "InstallMsodbc"
            {
                Ensure = "Present"
                Name = "Microsoft ODBC Driver 18 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\msodbcsql.msi"
                Arguments = "/quiet /log c:\windows\temp\odbc.log IACCEPTMSODBCSQLLICENSETERMS=YES"
                DependsOn = "[Script]DownloadMsodbcsql"
            }

            Package "InstallMssqlcmd"
            {
                Ensure = "Present"
                Name = "Microsoft Command Line Utilities 15 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\mssqlcmd.msi"
                Arguments = "/quiet /log c:\windows\temp\sqlcmd.log IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES"
                DependsOn = "[Script]DownloadMssqlcmd"
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
                    Start-BitsTransfer -Source "https://github.com/TPC-Council/HammerDB/releases/download/v4.12/HammerDB-4.12-Win.zip" -Destination $path;
                }
            }

            Archive "ExpandHammerdb"
            {
                Destination = "c:\tools\hammerdb"
                Path = "C:\Windows\temp\hammerdb.zip"
                DependsOn = "[Script]DownloadHammerdb"
            }
        }
#endregion

#region Diskspd
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
                    $uri = "https://github.com/microsoft/diskspd/releases/download/v2.1/DiskSpd.zip";
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
#endregion

#region Python
        if($Parameters.enablePython)
        {
            Script "DownloadPython"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "python.exe";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "python.exe";
                    $uri = "https://www.python.org/ftp/python/3.10.1/python-3.10.1-amd64.exe";
                    Start-BitsTransfer -Source $uri -Destination $path;
                }
            }

            Package "InstallPython"
            {
                Ensure = "Present"
                Name = "Python 3.10.1 Executables (64-bit)"
                ProductID = ""
                Path = "C:\Windows\temp\python.exe"
                Arguments = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
                DependsOn = "[Script]DownloadPython"
            }
        }
#endregion

#region Migration Center Discovery Client
        if($Parameters.enableDiscoveryClient)
        {
            Script "DownloadDiscoveryClient"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mcc_setup.exe";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mcc_setup.exe";
                    Start-BitsTransfer -Source "https://storage.googleapis.com/mc-collector-download-prod-eu/download/mcc_setup.exe" -Destination $path;
                }
            }

            Script "InstallDiscoveryClient"
            {
                GetScript = {
                    $path  = "C:\Program Files\Migration Center Discovery Client";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "mcc_setup.exe";
                    Start-Process -FilePath $path -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES" -Wait;
                }

                DependsOn = "[Script]DownloadDiscoveryClient"
            }
        }
#endregion Migration Center Discovery Client

#region Windows Admin Center
        if($Parameters.enableWindowsAdminCenter)
        {
            Script "DownloadWindowsAdminCenter"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "WindowsAdminCenter.msi";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "WindowsAdminCenter.exe";
                    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?linkid=2220149&clcid=0x409&culture=en-us&country=us" -Destination $path;
                }
            }

            Script "InstallWindowsAdminCenter"
            {
                GetScript = {
                    $path  = "C:\Program Files\Windows Admin Center";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "WindowsAdminCenter.msi";
                    Start-Process -FilePath "msiexec" -ArgumentList "/i $path", "/qn", "SME_PORT=443", "SSL_CERTIFICATE_OPTION=generate" -Wait;
                }

                DependsOn = "[Script]DownloadWindowsAdminCenter"
            }
        }
#endregion Windows Admin Center

        # Enable customization configuration which gets inlined into this file
        Customization "Customization"
        {
            Credential = $domainCredential
            Parameters = $Parameters
            
            # Composite configurations don't support dependencies
            # see https://dille.name/blog/2015/01/11/reusing-psdsc-node-configuration-with-nested-configurations-the-horror/
            # DependsOn = $customizationDependency
        }
    }
}
