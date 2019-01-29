configuration Config
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="8.0.0.0"},
        @{ModuleName="ComputerManagementDsc";ModuleVersion="6.0.0.0"};

    node localhost
    {
        File "tools"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools"
        }

        xRemoteFile "dotnet-hosting.exe"
        {
            Uri = "https://download.visualstudio.microsoft.com/download/pr/5ee633f2-bf6d-49bd-8fb6-80c861c36d54/caa93641707e1fd5b8273ada22009246/dotnet-hosting-2.2.1-win.exe"
            DestinationPath = "c:\tools"
            DependsOn = "[File]tools"
        }

        Package "dotnet"
        {
            Ensure = "Present"
            Name = "Microsoft .NET Core Runtime - 2.2.1 (x64)"
            ProductId = "588AB6F9-94E8-4909-B84B-0D69DFC1216C"
            Arguments = "/quiet"
            Path = "C:\tools\dotnet-hosting-2.2.1-win.exe"
            DependsOn = "[xRemoteFile]dotnet-hosting.exe"
        }
    }
}

# Login-AzureRmAccount;
# Publish-AzureRmVMDscConfiguration -ConfigurationPath .\Dsc.ps1 -ResourceGroupName "labassets" `
#     -StorageAccountName "labassets" -ContainerName "applicationinsights-for-servicefabric" -Force;