configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        NetworkingDsc;
        
    Script "EnableStorageSpacesDirect"
    {
        GetScript = {
            $state = (Get-ClusterStorageSpacesDirect).State;
            $pool = Get-StoragePool -FriendlyName "$($using:Parameters.nodePrefix)" -ErrorAction SilentlyContinue;

            if($state -eq "Enabled" -and $Null -ne $pool)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }

            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }
        
        SetScript = {
            $cacheDeviceModel = "EphemeralDisk";
            if($using:Parameters.cacheDiskInterface -eq "NVME")
            {
                $cacheDeviceModel = "nvme_card";
            }

            Enable-ClusterStorageSpacesDirect -PoolFriendlyName "$($using:Parameters.nodePrefix)" `
                -CacheState Enabled -CacheDeviceModel $cacheDeviceModel -CollectPerformanceHistory $true `
                -SkipEligibilityChecks:$true -Confirm:$false -Verbose;
            
            # Disable auto-pooling of new disks
            Get-StorageSubSystem Cluster* | Set-StorageHealthSetting -Name "System.Storage.PhysicalDisk.AutoPool.Enabled" -Value False;

            # Disable auto-replacing failed disks
            Get-StorageSubSystem Cluster* | Set-StorageHealthSetting -name "System.Storage.PhysicalDisk.AutoReplace.Enabled" -value False;
        }

        PsDscRunAsCredential = $Credential
    }

    Script "CreateVolume"
    {
        GetScript = {
            if((Get-Volume -FriendlyName "mirror-2way" -ErrorAction Ignore) -ne $Null)
            {
                $result = "Present";
            }
            else
            {
                $result = "Absent";
            }

            return @{Ensure = $result};
        }

        TestScript = {
            $state = [scriptblock]::Create($GetScript).Invoke();
            return $state.Ensure -eq "Present";
        }

        SetScript = {
            New-Volume -FriendlyName "mirror-2way" -StoragePoolFriendlyName $($using:Parameters.nodePrefix) `
                -ResiliencySettingName "Mirror" -ProvisioningType "Fixed" -FileSystem CSVFS_ReFS -UseMaximumSize;
        }
        
        DependsOn = "[Script]EnableStorageSpacesDirect"
    }

    File "benchmark.ps1" 
    {
        DestinationPath = "c:\tools\benchmark.ps1"
        Type = "File"
        Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("${fileContentBenchmark}"))
    }

    File "benchmark_configurations.json" 
    {
        DestinationPath = "c:\tools\benchmark_configurations.json"
        Type = "File"
        Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("${fileContentBenchmarkConfigurations}"))
    }

    File "benchmark_scenarios.json" 
    {
        DestinationPath = "c:\tools\benchmark_scenarios.json"
        Type = "File"
        Contents = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String("${fileContentBenchmarkScenarios}"))
    }
}