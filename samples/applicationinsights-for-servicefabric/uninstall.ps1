Remove-Item -Recurse Ai4Sf\TelemetryApiPkg\Code;
Remove-Item -Recurse Ai4Sf\TelemetryCrawlerPkg\Code;
Remove-Item -Recurse Ai4Sf\FrontendPkg\Code;

Remove-ServiceFabricApplication -Force -ApplicationName fabric:/Ai4Sf;
Unregister-ServiceFabricApplicationType -Force -ApplicationTypeName Ai4Sf -ApplicationTypeVersion 1.0.0;
Remove-ServiceFabricApplicationPackage -ApplicationPackagePathInImageStore Ai4Sf;