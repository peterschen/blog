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
        xPSDesiredStateConfiguration, ComputerManagementDsc, ActiveDirectoryDsc,
        FailoverClusterDsc, NetworkingDsc, SqlServerDsc, StorageDsc, xCredSSP;

    $components = $Parameters.domainName.Split(".");
    $dc = "";
    foreach($component in $components)
    {
        if(-not [string]::IsNullOrEmpty($dc))
        {
            $dc += ",";
        }

        $dc += "dc=$component";
    }
    $ou = "ou=$($Parameters.domainName),$dc"

    $features = @(
        "Failover-clustering",
        "RSAT-AD-PowerShell",
        "RSAT-Clustering-PowerShell"
    );

    $rules = @(
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP"
    );

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $engineUser = "s-SqlEngine";

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\$engineUser", $Password);

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

        xCredSSP Server
        {
            Ensure = "Present"
            Role = "Server"
        }

        WaitForADDomain "WFAD"
        {
            DomainName  = $Parameters.domainName
            Credential = $domainCredential
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $Parameters.domainName
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
            MembersToInclude = "$($Parameters.domainName)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        ADUser "ServiceSqlEngine"
        {
            DomainName = $Parameters.domainName
            UserPrincipalName = "s-SqlEngine@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-SqlEngine"
            Password = $domainCredential
            PasswordNeverExpires = $true
            Ensure = "Present"
            Path = "ou=Services,ou=Accounts,$ou"
        }

        ADUser "ServiceSqlAgent"
        {
            DomainName = $Parameters.domainName
            UserPrincipalName = "s-SqlAgent@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-SqlAgent"
            Password = $domainCredential
            PasswordNeverExpires = $true
            Ensure = "Present"
            Path = "ou=Services,ou=Accounts,$ou"
        }

        ADGroup "SqlAdministrators"
        {
            GroupName = "g-SqlAdministrators"
            GroupScope = "Global"
            Ensure = "Present"
            Path = "ou=Groups,$ou"
            MembersToInclude = @("johndoe", "Administrator")
            Credential = $domainCredential
        }

        # Set basic dependencies for setup
        $setupDependency = @("[ADUser]ServiceSqlEngine", "[ADUser]ServiceSqlAgent", "[ADGroup]SqlAdministrators");

        File "Data"
        {
            DestinationPath = "C:\data"
            Type = "Directory"
        }

        Script "SetPermissions"
        {
            GetScript = {
                $acl = Get-Acl -Path "C:\data";
                if($acl.Owner.Contains($engineUser))
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
                $acl = Get-Acl -Path "C:\data";
                $owner = New-Object System.Security.Principal.NTAccount($Using:engineUser);
                $acl.SetOwner($owner);
                Set-Acl -Path "C:\data" -AclObject $acl | Out-Null;
            }

            DependsOn = "[ADUser]ServiceSqlEngine", "[File]Data"
            PsDscRunAsCredential = $domainCredential
        }

        ADServicePrincipalName "SetSpnHostname"
        {
            ServicePrincipalName = "MSSQLSvc/$($Node.NodeName):1433"
            Account = $engineCredential.UserName.Split("\")[1]
            PsDscRunAsCredential = $domainCredential
        }

        ADServicePrincipalName "SetSpnFqdn"
        {
            ServicePrincipalName = "MSSQLSvc/$($Node.NodeName).$($Parameters.domainName):1433"
            Account = $engineCredential.UserName.Split("\")[1]
            PsDscRunAsCredential = $domainCredential
        }

        if($Parameters.useDeveloperEdition)
        {
            xRemoteFile "DownloadSqlServerBinary"
            {
                Uri = "https://go.microsoft.com/fwlink/p/?linkid=2215158"
                DestinationPath = "C:\Windows\temp\sqlserver.exe"
            }

            Script "DownloadSqlServerMedia"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\sql_server_install" -ChildPath "*.iso";
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
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "sqlserver.exe";
                    Start-Process -FilePath $path -ArgumentList @("/ENU", "/Quiet", "/Action=Download", "/MEDIAPATH=C:\sql_server_install", "/MEDIATYPE=iso") -Wait;

                    $pathIso = Join-Path -Path "C:\sql_server_install" -ChildPath "*.iso";
                    $item = Get-Item -Path $pathIso;

                    $pathIso = Join-Path -Path "C:\sql_server_install" -ChildPath "sqlserver.iso";
                    Move-Item -Path $item.FullName -Destination $pathIso;
                }

                DependsOn = "[xRemoteFile]DownloadSqlServerBinary"
            }

            MountImage "MountSqlMedia"
            {
                ImagePath = "c:\sql_server_install\sqlserver.iso"
                DriveLetter = "s"
                DependsOn = "[Script]DownloadSqlServerMedia"
            }

            WaitForVolume "WaitForSqlMedia"
            {
                DriveLetter = "s"
                RetryIntervalSec = 5
                RetryCount = 10
                DependsOn = "[MountImage]MountSqlMedia"
            }

            File "CopySqlMedia"
            {
                SourcePath = "s:\"
                DestinationPath = "c:\sql_server_install\"
                Recurse = $true
                DependsOn = "[WaitForVolume]WaitForSqlMedia"
            }

            # Add dependency for media download
            $setupDependency += @("[File]CopySqlMedia");
        }

        if($Parameters.enableCluster -ne $false)
        {
            Firewall "F-GceClusterHelper"
            {
                Name = "GceClusterHelper"
                DisplayName = "GCE Cluster helper"
                Ensure = "Present"
                Enabled = "True"
                Direction = "InBound"
                LocalPort = ("59998")
                Protocol = "TCP"
                Description = "Enables GCP Internal Load Balancer to check which node in the cluster is active to route traffic to the cluster IP."
            }

            Firewall SqlServerIngress
            {
                Name = "SqlServerIngress"
                DisplayName = "SQL Server TCP Ingress"
                Ensure = "Present"
                Enabled = "True"
                Direction = "InBound"
                LocalPort = ("1433")
                Protocol = "TCP"
            }

            Firewall SqlServerHadr
            {
                Name = "SqlServerHadr"
                DisplayName = "SQL Server HADR Endpoint"
                Ensure = "Present"
                Enabled = "True"
                Direction = "InBound"
                LocalPort = ("5022")
                Protocol = "TCP"
            }

            if($Parameters.isFirst)
            {
                ADComputer "PrestageClusterResource"
                {
                    ComputerName = "$($Parameters.nodePrefix)-cl"
                    EnabledOnCreation = $false
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[Computer]JoinDomain"
                }

                ADGroup "AddClusterResourceToGroup"
                {
                    GroupName = "g-ClusterResources"
                    GroupScope = "Global"
                    Ensure = "Present"
                    Path = "ou=Groups,$ou"
                    MembersToInclude = "$($Parameters.nodePrefix)-cl`$"
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[ADComputer]PrestageClusterResource"
                }

                Cluster "CreateCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    StaticIPAddress = $Parameters.ipCluster
                    DomainAdministratorCredential = $domainCredential
                    DependsOn = "[WindowsFeature]WF-Failover-clustering","[ADGroup]AddClusterResourceToGroup"
                    PsDscRunAsCredential = $domainCredential
                }

                Script "SetClusterPermissions"
                {
                    GetScript = {
                        $access = Get-ClusterAccess -User $using:engineUser -ErrorAction SilentlyContinue;
                        if($access -ne $Null)
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
                        Grant-ClusterAccess -User $using:engineUser -Full;
                    }

                    DependsOn = "[Cluster]CreateCluster"
                    PsDscRunAsCredential = $domainCredential
                }

                ClusterQuorum "Quorum"
                {
                    Type = "NodeMajority"
                    IsSingleInstance = "Yes"
                    DependsOn = "[Cluster]CreateCluster"
                }

                # Reference: https://learn.microsoft.com/en-us/azure/azure-sql/virtual-machines/windows/hadr-cluster-best-practices?view=azuresql&tabs=windows2012#heartbeat-and-threshold
                ClusterProperty ClusterTimeouts
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    SameSubnetDelay = 1000
                    SameSubnetThreshold = 40
                    CrossSubnetDelay = 1000
                    CrossSubnetThreshold = 40

                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[Cluster]CreateCluster"
                }

                $nodes = @();
                for($i = 1; $i -lt $Parameters.nodeCount; $i++) {
                    $nodes += "$($Parameters.nodePrefix)-$i";
                };

                WaitForAll "ClusterJoin"
                {
                    ResourceName = "[Cluster]JoinNodeToCluster"
                    NodeName = $nodes
                    RetryIntervalSec = 5
                    RetryCount = 120
                    DependsOn = "[Cluster]CreateCluster"
                }
            }
            else
            {
                WaitForAll "WaitForCluster"
                {
                    ResourceName = "[Cluster]CreateCluster"
                    NodeName = "$($Parameters.nodePrefix)-0"
                    RetryIntervalSec = 5
                    RetryCount = 120
                }

                Cluster "JoinNodeToCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    StaticIPAddress = $Parameters.ipCluster
                    DomainAdministratorCredential = $domainCredential
                    DependsOn = "[WaitForAll]WaitForCluster"
                    PsDscRunAsCredential = $domainCredential
                }
            }
        }
        else
        {
            SqlSetup "SqlServerSetup"
            {
                SourcePath = "C:\sql_server_install"
                Features = "SQLENGINE,FULLTEXT"
                InstanceName = "MSSQLSERVER"
                SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
                SQLSvcAccount = $engineCredential
                AgtSvcAccount = $agentCredential
                DependsOn = $setupDependency
            }

            SqlScriptQuery "SetServerName"
            {
                Id = "SetServerName"
                ServerName = $Node.NodeName
                InstanceName = "MSSQLSERVER"

                TestQuery = @"
IF (SELECT @@SERVERNAME) != $($Node.NodeName)
BEGIN
    RAISERROR ('Server name is not set correctly', 16, 1)
END
ELSE
BEGIN
    PRINT 'Server name is set correctly'
END
"@
                GetQuery = "SELECT @@SERVERNAME"
                SetQuery = @"
sp_dropserver @@SERVERNAME;
GO

sp_addserver '$($Node.NodeName)', local;
GO
"@;
                Variable = @("FilePath=C:\windows\temp\SetServerMame")
                
                DependsOn = "[SqlSetup]SqlServerSetup"
                PsDscRunAsCredential = $domainCredential
            }

            SqlProtocol "SqlEnableTcp"
            {
                InstanceName = "MSSQLSERVER"
                ProtocolName = "TcpIp"
                Enabled = $true
                ListenOnAllIpAddresses = $true
                PsDscRunAsCredential  = $domainCredential
            }

            SqlWindowsFirewall "SqlServerFirewall"
            {
                SourcePath = "C:\sql_server_install"
                InstanceName = "MSSQLSERVER"
                Features = "SQLENGINE,FULLTEXT"
                DependsOn = "[SqlSetup]SqlServerSetup"
            }

            SqlServiceAccount "EngineAccount"
            {
                ServerName = $Node.NodeName
                InstanceName = "MSSQLSERVER"
                ServiceType = "DatabaseEngine"
                ServiceAccount = $engineCredential
                RestartService = $false

                DependsOn = "[ADUser]ServiceSqlEngine", "[ADServicePrincipalName]SetSpnHostname", "[ADServicePrincipalName]SetSpnFqdn"
                PsDscRunAsCredential = $domainCredential
            }

            SqlServiceAccount "AgentAccount"
            {
                ServerName = $Node.NodeName
                InstanceName = "MSSQLSERVER"
                ServiceType = "SQLServerAgent"
                ServiceAccount = $agentCredential
                RestartService = $true

                DependsOn = "[ADUser]ServiceSqlAgent", "[ADServicePrincipalName]SetSpnHostname", "[ADServicePrincipalName]SetSpnFqdn"
                PsDscRunAsCredential = $domainCredential
            }

            SqlAlwaysOnService "EnableAlwaysOn"
            {
                Ensure = "Present"
                ServerName = $Node.NodeName
                InstanceName = "MSSQLSERVER"

                DependsOn = "[SqlScriptQuery]SetServerName", "[SqlSetup]SqlServerSetup"
                PsDscRunAsCredential = $domainCredential
            }

            SqlLogin "EngineAccount"
            {
                ServerName = $Node.NodeName
                InstanceName = "MSSQLSERVER"
                Name = "$($Parameters.domainName.Split(".")[0])\$($engineCredential.UserName.Split("\")[1])"
                LoginType = "WindowsUser"
                PsDscRunAsCredential = $domainCredential
            }
        }

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
