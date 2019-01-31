$Global:ClientId = $env:SCCMT_CLIENTID;
$Global:ClientSecret = $env:SCCMT_CLIENTSECRET;
$Global:TenantDomain = $env:SCCMT_TENANTDOMAIN;
$Global:TenantId = $env:SCCMT_TENANTID;
$Global:Entities = $env:PROCESSOR_ENTITIES | ConvertFrom-Json;