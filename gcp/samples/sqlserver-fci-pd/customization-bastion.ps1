
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
        xCredSSP;

    $nodes = @();
    for($i = 0; $i -lt 2; $i++) {
        $nodes += "sql-$i";
    };

    xCredSSP Client
    {
        Ensure = "Present"
        Role = "Client"
        DelegateComputers = $nodes
    }
}