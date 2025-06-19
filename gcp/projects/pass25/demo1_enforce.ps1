Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";
$VerbosePreference = "SilentlyContinue";
$DebugPreference = "SilentlyContinue";

if(Test-Path -Path "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml") 
{
  Copy-Item -Path "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml" -Destination "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml.bak";
}

Add-Content -Path "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml" "
metrics:
  receivers:
    mssql_v2:
      type: mssql
      receiver_version: 2
  service:
    pipelines:
      mssql_v2:
        receivers:
        - mssql_v2
";

Stop-Service -Name "google-cloud-ops-agent" -Force -ErrorAction "SilentlyContinue";
Start-Service -Name "google-cloud-ops-agent";

exit 100;
