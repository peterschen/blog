Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";
$VerbosePreference = "SilentlyContinue";
$DebugPreference = "SilentlyContinue";

$config = Get-Content -Path "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml" -ErrorAction "Ignore";

if($config -ne $null -and $config -like "*mssql_v2")
{
    exit 100;
}
else
{
    exit 101;
}
