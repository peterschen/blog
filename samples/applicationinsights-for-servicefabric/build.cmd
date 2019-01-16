dotnet restore %~dp0/src/sfsample/Sfsample/Sfsample.csproj -s https://api.nuget.org/v3/index.json
dotnet build %~dp0/src/sfsample/Sfsample/Sfsample.csproj -v normal

for %%F in ("%~dp0/src/sfsample/Sfsample/Sfsample.csproj") do cd %%~dpF
dotnet publish -o %~dp0/sfsample/SfsamplePkg/Code
cd %~dp0/..
