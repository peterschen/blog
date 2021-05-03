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
        ComputerManagementDsc, NetworkingDsc, StorageDsc, SqlServerDsc;

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

        Script "RemoveDefaultInstance"
        {
            GetScript = {
                $services = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue;
                
                if($services -ne $null)
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
                return $state.Ensure -eq "Absent";
            }

            SetScript = {
                $executable = "C:\sql_server_install\setup.exe"
                $arguments = @(
                    "/Action=Uninstall"
                    "/FEATURES=SQL,AS,IS,RS"
                    "/INSTANCENAME=MSSQLSERVER"
                    "/Q"
                );

                Start-Process -FilePath $executable -ArgumentList $arguments -Wait;
                $global:DSCMachineStatus = 1;
            }
        }

        WaitForDisk TargetDisk
        {
             DiskId = 1
             RetryIntervalSec = 60
             RetryCount = 60
        }

        Disk TargetDisk
        {
             DiskId = 1
             DriveLetter = 'T'
             DependsOn = '[WaitForDisk]TargetDisk'
        }

        SqlSetup "SqlServerSetup"
        {
            SourcePath = "C:\sql_server_install"
            Features = "SQLENGINE"
            InstanceName = "PERF"
            SQLSysAdminAccounts = "Administrator"
            InstanceDir = "T:\"
            InstallSQLDataDir = "T:\"
            DependsOn = "[Script]RemoveDefaultInstance","[Disk]TargetDisk"
        }

        SqlProtocol "SqlProtocol"
        {
            InstanceName = "PERF"
            ProtocolName = "TcpIp"
            Enabled = $true
            ListenOnAllIpAddresses = $true
            DependsOn = "[SqlSetup]SqlServerSetup"
        }

        SqlProtocolTcpIp "SqlProtocolTcpIp"
        {
            InstanceName = "PERF"
            IpAddressGroup = "IPAll"
            TcpPort = 1433
            DependsOn = "[SqlProtocol]SqlProtocol"
        }

        SqlWindowsFirewall "SqlServerFirewall"
        {
            SourcePath = "C:\sql_server_install"
            InstanceName = "PERF"
            Features = "SQLENGINE"
            DependsOn = "[SqlProtocolTcpIp]SqlProtocolTcpIp"
        }
    }
}