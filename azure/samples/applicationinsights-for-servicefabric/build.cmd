@echo off

dotnet build %~dp0/src/Ai4Sf/Common/Common.csproj -v m
dotnet build %~dp0/src/Ai4Sf/TelemetryApi/TelemetryApi.csproj -v m
dotnet build %~dp0/src/Ai4Sf/TelemetryCrawler/TelemetryCrawler.csproj -v m
dotnet build %~dp0/src/Ai4Sf/Frontend/Frontend.csproj -v m

for %%F in ("%~dp0/src/Ai4Sf/TelemetryApi/TelemetryApi.csproj") do cd %%~dpF
dotnet publish -o %~dp0/Ai4Sf/TelemetryApiPkg/Code
cd %~dp0/..

for %%F in ("%~dp0/src/Ai4Sf/TelemetryCrawler/TelemetryCrawler.csproj") do cd %%~dpF
dotnet publish -o %~dp0/Ai4Sf/TelemetryCrawlerPkg/Code
cd %~dp0/..

for %%F in ("%~dp0/src/Ai4Sf/Frontend/Frontend.csproj") do cd %%~dpF
dotnet publish -o %~dp0/Ai4Sf/FrontendPkg/Code
cd %~dp0/..