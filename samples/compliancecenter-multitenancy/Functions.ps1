function Get-O365AuthenticationHeaders
{
    param
    (
        [string] $TenantDomain,
        [string] $ClientId,
        [string] $ClientSecret
    );

    $body = @{
        grant_type = "client_credentials";
        resource = "https://manage.office.com";
        client_id = $ClientId;
        client_secret = $ClientSecret
    };
    
    # Authenticate and retrieve Bearer token
    $oauth = Invoke-RestMethod -Method Post -Uri "https://login.windows.net/$TenantDomain/oauth2/token?api-version=1.0" -Body $body;
    return @{
        "Authorization" = "$($oauth.token_type) $($oauth.access_token)"
    };
}

function Get-Queue
{
    param
    (
        [string] $Name,
        [string] $NameAccount,
        [string] $KeyAccount
    );

    $authContext = New-AzureStorageContext $NameAccount -StorageAccountKey $KeyAccount;
    return Get-AzureStorageQueue -Name $Name -Context $authContext;
}