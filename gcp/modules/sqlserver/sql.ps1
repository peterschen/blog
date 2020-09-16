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
        ComputerManagementDsc, ActiveDirectoryDsc, xFailoverCluster, 
        NetworkingDsc, SqlServerDsc;

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

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-sql-agent)", $Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-sql-engine)", $Password);

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
            UserPrincipalName = "s-sql-engine@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-sql-engine"
            Password = $domainCredential
            PasswordNeverExpires = $true
            Ensure = "Present"
            Path = "ou=Services,ou=Accounts,$ou"
        }

        ADUser "ServiceSqlAgent"
        {
            DomainName = $Parameters.domainName
            UserPrincipalName = "s-sql-agent@$($Parameters.domainName)"
            Credential = $domainCredential
            UserName = "s-sql-agent"
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

        SqlSetup "SqlServerSetup"
        {
            SourcePath = "C:\sql_server_install"
            Features = "SQLENGINE,FULLTEXT"
            InstanceName = "MSSQLSERVER"
            SQLSysAdminAccounts = "$($Parameters.domainName)\g-SqlAdministrators"
            SQLSvcAccount = $engineCredential
            AgtSvcAccount = $agentCredential
            DependsOn = "[ADUser]ServiceSqlEngine","[ADUser]ServiceSqlAgent","[ADGroup]SqlAdministrators"
        }

        SqlWindowsFirewall "SqlServerFirewall"
        {
            SourcePath = "C:\sql_server_install"
            InstanceName = "MSSQLSERVER"
            Features = "SQLENGINE,FULLTEXT"
            DependsOn = "[SqlSetup]SqlServerSetup"
        }

        if($Parameters.provisionCluster -ne $false)
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

                xCluster "CreateCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    DomainAdministratorCredential = $domainCredential
                    StaticIPAddress = $Parameters.ipCluster
                    DependsOn = "[WindowsFeature]WF-Failover-clustering","[ADGroup]AddClusterResourceToGroup"
                }

                xClusterQuorum "Quorum"
                {
                    Type = "NodeMajority"
                    IsSingleInstance = "Yes"
                    DependsOn = "[xCluster]CreateCluster"
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
                    
                    DependsOn = "[xCluster]CreateCluster"
                }

                SqlAlwaysOnService "EnableAlwaysOn"
                {
                    Ensure = "Present"
                    ServerName = "localhost"
                    InstanceName = "MSSQLSERVER"
                    RestartTimeout = 120
                    DependsOn = "[Script]IncreaseClusterTimeouts"
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
            else
            {
                WaitForAll "WaitForCluster"
                {
                    ResourceName = "[xCluster]CreateCluster"
                    NodeName = "$($Parameters.nodePrefix)-0"
                    RetryIntervalSec = 5
                    RetryCount = 120
                    PsDscRunAsCredential = $domainCredential
                }

                xCluster "JoinNodeToCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    DomainAdministratorCredential = $domainCredential
                    DependsOn = "[WaitForAll]WaitForCluster"
                }

                SqlAlwaysOnService "EnableAlwaysOn"
                {
                    Ensure = "Present"
                    ServerName = "localhost"
                    InstanceName = "MSSQLSERVER"
                    RestartTimeout = 120
                    DependsOn = "[xCluster]JoinNodeToCluster"
                }
            }
        }
    }
}
