param
(
    [object] $triggerInput
);

# dot-load functions and globals
. .\Functions.ps1;
. .\Globals.ps1;

# Input from the Message queue on trigger
$requestJson = Get-Content $triggerInput;

# Authenticate against AAD
$headers = Get-O365AuthenticationHeaders -TenantDomain $Global:TenantDomain -ClientId $Global:ClientId -ClientSecret $Global:ClientSecret;

$request = $requestJson | ConvertFrom-Json;
foreach($content in $request)
{
    $uri = "$content?PublisherIdentifier=$tenantId";
    $record = Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $uri -PassThru;
    Process-Record -Record $record;
}

function Process-Record
{
    param
    (
        [string] $RecordString
    );

    $record = $RecordString | ConvertFrom-Json;
    $domain = $record.UserId.Split("@")[1];
    $dataRoute = Get-GetDataRoute -Domain $domain;

    Write-Host "Writing data for $($record.UserId) to $($dataRoute["target"])";
}

function Get-GetDataRoute
{
    param
    (
        [string] $Domain
    );

    $account = $Global:Entities."$Domain";
    if(-not [string]::IsNullOrEmpty($account))
    {
        return @{
            "target" = "storage"
            "account" = $account
        };
    }
    else
    {
        return @{
            "target" = "loganalytics"
            "account" = $Domain
        }
    }
}