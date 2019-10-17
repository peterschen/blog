$AppPath = "$PSScriptRoot\Ai4Sf";
$AppParameters = @{
    "spTenantId" = ""
    "spAppId" = ""
    "spPassword" = ""
    "aiKey" = ""
    "resourceId" = ""
    "resourceMetric" = ""
};

# Remove runtimes to save on package size
Get-ChildItem -Path $AppPath -Recurse -Filter "linux" | Remove-Item -Recurse;
Get-ChildItem -Path $AppPath -Recurse -Filter "unix" | Remove-Item -Recurse;

Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $AppPath -ApplicationPackagePathInImageStore Ai4Sf -ShowProgress;
Register-ServiceFabricApplicationType -ApplicationPathInImageStore Ai4Sf;
New-ServiceFabricApplication -ApplicationName fabric:/Ai4Sf -ApplicationTypeName Ai4Sf -ApplicationTypeVersion 1.0.0 -ApplicationParameter $AppParameters;