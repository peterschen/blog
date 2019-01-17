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

        xRemoteFile "dotnet-install.ps1"
        {
            Uri = "https://dot.net/v1/dotnet-install.ps1"
            DestinationPath = "c:\tools"
            DependsOn = "[File]tools"
        }

        ScheduledTask "dotnet"
        {
            TaskName = "dotnet"
            TaskPath = '\Application Insights for Service Fabric'
            ActionExecutable = "C:\tools\dotnet-install.ps1"
            ActionArguments = "-Channel LTS"
            ScheduleType = "Once"
        }
    }
}

# Login-AzureRmAccount;
# Publish-AzureRmVMDscConfiguration -ConfigurationPath .\Dsc.ps1 -ResourceGroupName "labassets" `
#     -StorageAccountName "labassets" -ContainerName "applicationinsights-for-servicefabric" -Force;