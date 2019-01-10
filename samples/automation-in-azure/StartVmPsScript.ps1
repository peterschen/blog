param
(
    [string] $Name,
    [string] $NameResourceGroup
)

# Authenticate with service principal / runas account
$connection = Get-AutomationConnection -Name AzureRunAsConnection;
Connect-AzureRmAccount -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint;

# Start VM
Start-AzureRmVM -Name $Name -ResourceGroupName $NameResourceGroup;