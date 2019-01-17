Remove-Item -Recurse Ai4Sf\TodoApiPkg\Code
Remove-Item -Recurse Ai4Sf\FrontendPkg\Code
Remove-ServiceFabricApplication -Force fabric:/Ai4Sf 
Unregister-ServiceFabricApplicationType -Force Ai4Sf 1.0.0
Remove-ServiceFabricApplicationPackage Ai4Sf