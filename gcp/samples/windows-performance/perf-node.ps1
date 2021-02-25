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
            Destination = "c:\tools"
            Path = "C:\Windows\temp\iometer.zip"
            DependsOn = "[Script]DownloadIometer"
        }
    }
}