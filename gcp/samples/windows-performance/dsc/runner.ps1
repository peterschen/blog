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
        ComputerManagementDsc, NetworkingDsc;

    $features = @(
    );

    $rules = @(
        "FPS-NB_Datagram-In-UDP",
        "FPS-NB_Name-In-UDP",
        "FPS-NB_Session-In-TCP",
        "FPS-SMB-In-TCP",
        "RemoteFwAdmin-In-TCP",
        "RemoteFwAdmin-RPCSS-In-TCP",
        "RemoteEventLogSvc-In-TCP",
        "RemoteEventLogSvc-NP-In-TCP",
        "RemoteEventLogSvc-RPCSS-In-TCP",
        "RemoteSvcAdmin-In-TCP",
        "RemoteSvcAdmin-NP-In-TCP",
        "RemoteSvcAdmin-RPCSS-In-TCP"
    );

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
            Name = "Microsoft SQL Server Management Studio 18.8"
            ProductID = ""
            Path = "C:\Windows\temp\SSMS-Setup-ENU.exe"
            Arguments = "/install /quiet"
            DependsOn = "[Script]DownloadSsms"
        }

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
                Start-BitsTransfer -Source "https://github.com/TPC-Council/HammerDB/releases/download/v4.0/HammerDB-4.0-Win.zip" -Destination $path;
            }
        }

        Archive "ExpandHammerdb"
        {
            Destination = "c:\tools\hammerdb"
            Path = "C:\Windows\temp\hammerdb.zip"
            DependsOn = "[Script]DownloadHammerdb"
        }

        File "benchmark.b64"
        {
            DestinationPath = "c:\tools\benchmark.b64"
            Contents = $Parameters.scriptBenchmark
            Ensure = "Present"
        }

        Script "benchmark.ps1"
        {
            GetScript = {
                $path  = Join-Path -Path "c:\tools" -ChildPath "benchmark.ps1";
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
                $content = Get-Content -Path (Join-Path -Path "c:\tools" -ChildPath "benchmark.b64");
                $pathDestination = Join-Path -Path "c:\tools" -ChildPath "benchmark.ps1";
                [IO.File]::WriteAllBytes($pathDestination, [Convert]::FromBase64String($content));
            }

            DependsOn = "[File]benchmark.b64"
        }

        File "conversion.b64"
        {
            DestinationPath = "c:\tools\conversion.b64"
            Contents = $Parameters.scriptConversion
            Ensure = "Present"
        }

        Script "conversion.ps1"
        {
            GetScript = {
                $path  = Join-Path -Path "c:\tools" -ChildPath "conversion.ps1";
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
                $content = Get-Content -Path (Join-Path -Path "c:\tools" -ChildPath "conversion.b64");
                $pathDestination = Join-Path -Path "c:\tools" -ChildPath "conversion.ps1";
                [IO.File]::WriteAllBytes($pathDestination, [Convert]::FromBase64String($content));
            }

            DependsOn = "[File]conversion.b64"
        }
    }
}