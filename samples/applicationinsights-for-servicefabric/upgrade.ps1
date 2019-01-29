Param(
  [Parameter(Mandatory=$true)]
  [string]$version
)

$AppPath = "$PSScriptRoot\sfsample"
Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $AppPath -ApplicationPackagePathInImageStore "sfsample\$version" -ShowProgress
Register-ServiceFabricApplicationType -ApplicationPathInImageStore "sfsample\$version"
Start-ServiceFabricApplicationUpgrade -ApplicationName fabric:/sfsample -ApplicationTypeVersion $version -FailureAction Rollback -Monitored