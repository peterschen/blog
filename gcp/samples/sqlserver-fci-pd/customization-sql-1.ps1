configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        ActiveDirectoryDsc, SqlServerDsc;

    $agentCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlAgent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\s-SqlEngine", $Credential.Password);

    WaitForAll "SqlServerSetup"
    {
        ResourceName = "[SqlSetup]SqlServerSetup::[Customization]Customization"
        NodeName = "$($Parameters.nodePrefix)-0"
        RetryIntervalSec = 5
        RetryCount = 120
    }

    SqlSetup "SqlServerSetup"
    {
        Action = "ADDNODE"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        FailoverClusterNetworkName = $Parameters.nodePrefix
        FailoverClusterIPAddress = $Parameters.ipSql

        SkipRule = "Cluster_VerifyForErrors"

        PsDscRunAsCredential = $Credential
        DependsOn = "[WaitForAll]SqlServerSetup"
    }

    SqlProtocol "SqlProtocol"
    {
        InstanceName = "MSSQLSERVER"
        ProtocolName = "TcpIp"
        Enabled = $true
        ListenOnAllIpAddresses = $true
        DependsOn = "[SqlSetup]SqlServerSetup"
    }

    SqlProtocolTcpIp "SqlProtocolTcpIp"
    {
        InstanceName = "MSSQLSERVER"
        IpAddressGroup = "IPAll"
        TcpPort = 1433
        DependsOn = "[SqlProtocol]SqlProtocol"
    }

    SqlServiceAccount "EngineAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "DatabaseEngine"
        ServiceAccount = $engineCredential
        RestartService = $true

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }

    SqlServiceAccount "AgentAccount"
    {
        ServerName = $Node.NodeName
        InstanceName = "MSSQLSERVER"
        ServiceType = "SQLServerAgent"
        ServiceAccount = $agentCredential
        RestartService = $true

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }
}