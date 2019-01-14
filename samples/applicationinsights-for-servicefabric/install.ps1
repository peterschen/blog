$AppPath = "$PSScriptRoot\sfsample"
Copy-ServiceFabricApplicationPackage -ApplicationPackagePath $AppPath -ApplicationPackagePathInImageStore sfsample -ShowProgress
Register-ServiceFabricApplicationType sfsample
New-ServiceFabricApplication fabric:/sfsample sfsampleType 1.0.0