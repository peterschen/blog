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
        SqlServerDsc;

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
        Action = "INSTALL"
        SourcePath = "C:\sql_server_install"
        Features = "SQLENGINE,FULLTEXT"
        InstanceName = "MSSQLSERVER"
        SQLSvcAccount = $engineCredential
        AgtSvcAccount = $agentCredential

        SkipRule = "Cluster_VerifyForErrors"

        PsDscRunAsCredential = $Credential
        DependsOn = "[WaitForAll]SqlServerSetup"
    }

    SqlAlwaysOnService "EnableAlwaysOn"
    {
        Ensure = "Present"
        InstanceName = "MSSQLSERVER"
        ServerName = $Node.NodeName

        DependsOn = "[SqlSetup]SqlServerSetup"
        PsDscRunAsCredential = $Credential
    }
}