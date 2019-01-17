$AppPath = "$PSScriptRoot\Ai4Sf"
Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $AppPath -ApplicationPackagePathInImageStore Ai4Sf -ShowProgress
Register-ServiceFabricApplicationType Ai4Sf
New-ServiceFabricApplication fabric:/Ai4Sf Ai4Sf 1.0.0