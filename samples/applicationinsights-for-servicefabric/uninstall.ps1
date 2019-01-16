
Remove-ServiceFabricApplication -Force fabric:/sfsample 
Unregister-ServiceFabricApplicationType -Force sfsampleType 1.0.0
Remove-ServiceFabricApplicationPackage sfsample