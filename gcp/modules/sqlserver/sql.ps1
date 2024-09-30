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
        ComputerManagementDsc, ActiveDirectoryDsc, FailoverClusterDsc, 
        NetworkingDsc, SqlServerDsc, StorageDsc;

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

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Password);

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
            MembersToInclude = @("johndoe")
            Credential = $domainCredential
        }

        # Set basic dependencies for setup
        $setupDependency = @("[ADUser]ServiceSqlEngine", "[ADUser]ServiceSqlAgent", "[ADGroup]SqlAdministrators");

        if($Parameters.useDeveloperEdition)
        {
            Script "DownloadSqlServerBinary"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\Windows\temp" -ChildPath "sqlserver.exe";
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
                    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/p/?linkid=2215158" -Destination $path;
                }
            }

            Script "DownloadSqlServerMedia"
            {
                GetScript = {
                    $path  = Join-Path -Path "C:\sql_server_install\" -ChildPath "*.iso";
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

                    $pathIso = Join-Path -Path "C:\sql_server_install\" -ChildPath "*.iso";
                    $item = Get-Item -Path $pathIso;

                    $pathIso = Join-Path -Path "C:\sql_server_install\" -ChildPath "sqlserver.iso";
                    Move-Item -Path $item.FullName -Destination $pathIso;
                }

                DependsOn = "[Script]DownloadSqlServerBinary"
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

                ClusterQuorum "Quorum"
                {
                    Type = "NodeMajority"
                    IsSingleInstance = "Yes"
                    DependsOn = "[Cluster]CreateCluster"
                }

                Script IncreaseClusterTimeouts
                {
                    GetScript = {
                        $cluster = Get-Cluster;
                        if($cluster.SameSubnetDelay -eq 2000 -and `
                            $cluster.SameSubnetThreshold -eq 15 -and `
                            $cluster.CrossSubnetDelay -eq 3000 -and `
                            $cluster.CrossSubnetThreshold -eq 15)
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
                        $cluster = Get-Cluster;
                        $cluster.SameSubnetDelay = 2000;
                        $cluster.SameSubnetThreshold = 15;
                        $cluster.CrossSubnetDelay = 3000;
                        $cluster.CrossSubnetThreshold = 15;
                    }
                    
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

                # Add dependency for cluster creation
                $setupDependency += @("[WaitForAll]ClusterJoin");

                SqlSetup "SqlServerSetup"
                {
                    SourcePath = "C:\sql_server_install"
                    Features = "SQLENGINE,FULLTEXT"
                    InstanceName = "MSSQLSERVER"
                    SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
                    SQLSvcAccount = $engineCredential
                    AgtSvcAccount = $agentCredential
                        
                    FailoverClusterNetworkName = "$($Parameters.nodePrefix)-cl"
                    FailoverClusterIPAddress = $Parameters.ipCluster
                    FailoverClusterGroupName = "$($Parameters.nodePrefix)-cl"

                    DependsOn = $setupDependency;
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
                    # PsDscRunAsCredential = $domainCredential
                }

                Cluster "JoinNodeToCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    StaticIPAddress = $Parameters.ipCluster
                    DomainAdministratorCredential = $domainCredential
                    DependsOn = "[WaitForAll]WaitForCluster"
                    PsDscRunAsCredential = $domainCredential
                }

                $setupDependency += @("[Cluster]JoinNodeToCluster");

                SqlSetup "SqlServerSetup"
                {
                    SourcePath = "C:\sql_server_install"
                    Features = "SQLENGINE,FULLTEXT"
                    InstanceName = "MSSQLSERVER"
                    SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
                    SQLSvcAccount = $engineCredential
                    AgtSvcAccount = $agentCredential

                    FailoverClusterNetworkName = "$($Parameters.nodePrefix)-cl"

                    DependsOn = $setupDependency
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
        }

        SqlWindowsFirewall "SqlServerFirewall"
        {
            SourcePath = "C:\sql_server_install"
            InstanceName = "MSSQLSERVER"
            Features = "SQLENGINE,FULLTEXT"
            DependsOn = "[SqlSetup]SqlServerSetup"
        }

        if($Parameters.enableCluster -and $Parameters.enableAlwaysOn)
        {
            SqlAlwaysOnService "EnableAlwaysOn"
            {
                Ensure = "Present"
                ServerName = "localhost"
                InstanceName = "MSSQLSERVER"
                RestartTimeout = 120
                DependsOn = "[SqlWindowsFirewall]SqlServerFirewall"
            }

            <#
                SqlAGListener "AvailabilityGroup"
                {
                    Ensure = "Present"
                    ServerName = "localhost"
                    InstanceName = "MSSQLSERVER"
                    AvailabilityGroup = $Parameters.nodePrefix
                    Name = "$($Parameters.nodePrefix)-ag"
                    DHCP = $true
                    DependsOn = "[SqlAlwaysOnService]EnableAlwaysOn"
                }
            #>
        }
    }
}
