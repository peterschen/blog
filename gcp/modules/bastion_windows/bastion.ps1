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
        xPSDesiredStateConfiguration, ComputerManagementDsc, ActiveDirectoryDsc;

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
        xRemoteFile "DownloadChrome"
        {
            Uri = "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi"
            DestinationPath = "C:\Windows\temp\chrome.msi"
        }

        Package "InstallChrome"
        {
            Ensure = "Present"
            Name = "Google Chrome"
            ProductID = ""
            Path = "C:\Windows\temp\chrome.msi"
            Arguments = "/quiet"
            DependsOn = "[xRemoteFile]DownloadChrome"
        }
#endregion

#region IAP Desktop
        xRemoteFile "DownloadIapdesktop"
        {
            Uri = "https://github.com/GoogleCloudPlatform/iap-desktop/releases/download/2.46.1737/IapDesktop.msi"
            DestinationPath = "C:\Windows\temp\iapdesktop.msi"
        }

        Package "InstallIapdesktop"
        {
            Ensure = "Present"
            Name = "IAP Desktop"
            ProductID = ""
            Path = "C:\Windows\temp\iapdesktop.msi"
            Arguments = "/quiet"
            DependsOn = "[xRemoteFile]DownloadIapdesktop"
        }
#endregion

#region Visual Studio Code
        xRemoteFile "DownloadVscode"
        {
            Uri = "https://go.microsoft.com/fwlink/?Linkid=852157"
            DestinationPath = "C:\Windows\temp\vscode.exe"
        }

        Package "InstallVscode"
        {
            Ensure = "Present"
            Name = "Microsoft Visual Studio Code"
            ProductID = ""
            Path = "C:\Windows\temp\vscode.exe"
            Arguments = "/VERYSILENT"
            DependsOn = "[xRemoteFile]DownloadVscode"
        }
#endregion

#region SQL Server Management Studio
        if($Parameters.enableSsms)
        {
            xRemoteFile "DownloadSsms"
            {
                Uri = "https://aka.ms/ssmsfullsetup"
                DestinationPath = "C:\Windows\temp\SSMS-Setup-ENU.exe"
            }

            Package "InstallSsms"
            {
                Ensure = "Present"
                Name = "SQL Server Management Studio"
                ProductID = ""
                Path = "C:\Windows\temp\SSMS-Setup-ENU.exe"
                Arguments = "/install /quiet"
                DependsOn = "[xRemoteFile]DownloadSsms"
            }
        }
#endregion

#region HammerDB
        if($Parameters.enableHammerdb)
        {
            xRemoteFile "DownloadMsoledbsql"
            {
                Uri = "https://go.microsoft.com/fwlink/?linkid=2278038"
                DestinationPath = "C:\Windows\temp\msoledbsql.msi"
            }

            xRemoteFile "DownloadMsodbcsql"
            {
                Uri = "https://go.microsoft.com/fwlink/?linkid=2280794"
                DestinationPath = "C:\Windows\temp\msodbcsql.msi"
            }
        
            xRemoteFile "DownloadMssqlcmd"
            {
                Uri = "https://go.microsoft.com/fwlink/?linkid=2230791"
                DestinationPath = "C:\Windows\temp\mssqlcmd.msi"
            }

            Package "InstallMsoledb"
            {
                Ensure = "Present"
                Name = "Microsoft OLE DB Driver 19 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\msoledbsql.msi"
                Arguments = "/quiet /log c:\windows\temp\oledb.log IACCEPTMSOLEDBSQLLICENSETERMS=YES"
                DependsOn = "[xRemoteFile]DownloadMsoledbsql"
            }

            Package "InstallMsodbc"
            {
                Ensure = "Present"
                Name = "Microsoft ODBC Driver 18 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\msodbcsql.msi"
                Arguments = "/quiet /log c:\windows\temp\odbc.log IACCEPTMSODBCSQLLICENSETERMS=YES"
                DependsOn = "[xRemoteFile]DownloadMsodbcsql"
            }

            Package "InstallMssqlcmd"
            {
                Ensure = "Present"
                Name = "Microsoft Command Line Utilities 15 for SQL Server"
                ProductID = ""
                Path = "C:\Windows\temp\mssqlcmd.msi"
                Arguments = "/quiet /log c:\windows\temp\sqlcmd.log IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES"
                DependsOn = "[xRemoteFile]DownloadMssqlcmd"
            }

            xRemoteFile "DownloadHammerdb"
            {
                Uri = "https://github.com/TPC-Council/HammerDB/releases/download/v5.0/HammerDB-5.0-Win-x64-Setup.exe"
                DestinationPath = "C:\Windows\temp\hammerdb.exe"
            }

            Package "InstallHammerdb"
            {
                Ensure = "Present"
                Name = "HammerDB"
                ProductID = ""
                Path = "C:\Windows\temp\hammerdb.exe"
                Arguments = "--mode unattended --prefix c:\tools\HammerDB\HammerDB-5.0"
                DependsOn = "[xRemoteFile]DownloadHammerdb"
            }
        }
#endregion

#region Diskspd
        if($Parameters.enableDiskspd)
        {
            xRemoteFile "DownloadDiskspd"
            {
                Uri = "https://github.com/microsoft/diskspd/releases/download/v2.1/DiskSpd.zip"
                DestinationPath = "C:\Windows\temp\diskspd.zip"
            }

            Archive "ExpandDiskspd"
            {
                Destination = "c:\tools\diskspd"
                Path = "C:\Windows\temp\diskspd.zip"
                DependsOn = "[xRemoteFile]DownloadDiskspd"
            }
        }
#endregion

#region Python
        if($Parameters.enablePython)
        {
            xRemoteFile "DownloadPython"
            {
                Uri = "https://www.python.org/ftp/python/3.10.1/python-3.10.1-amd64.exe"
                DestinationPath = "C:\Windows\temp\python.exe"
            }

            Package "InstallPython"
            {
                Ensure = "Present"
                Name = "Python 3.10.1 Executables (64-bit)"
                ProductID = ""
                Path = "C:\Windows\temp\python.exe"
                Arguments = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
                DependsOn = "[xRemoteFile]DownloadPython"
            }
        }
#endregion

#region Migration Center Discovery Client
        if($Parameters.enableDiscoveryClient)
        {
            xRemoteFile "DownloadDiscoveryClient"
            {
                Uri = "https://storage.googleapis.com/mc-collector-download-prod-eu/download/mcc_setup.exe"
                DestinationPath = "C:\Windows\temp\mcc_setup.exe"
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

                DependsOn = "[xRemoteFile]DownloadDiscoveryClient"
            }
        }
#endregion Migration Center Discovery Client

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
