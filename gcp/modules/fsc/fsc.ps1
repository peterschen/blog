configuration ConfigurationWorkload
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $ComputerName,

        [Parameter(Mandatory = $true)]
        [securestring] $Password,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        ComputerManagementDsc, ActiveDirectoryDsc, NetworkingDsc, 
        FailoverClusterDsc;

    $components = $Parameters.domainName.Split(".");
    $dc = "";
    foreach($component in $components)
    {
        if(-not [string]::IsNullOrEmpty($dc))
        {
            $dc += ",";
        }

        $dc += "dc=$component";
    }
    $ou = "ou=$($Parameters.domainName),$dc"

    $features = @(
        "Failover-clustering",
        "FS-FileServer",
        "Storage-Replica",
        "RSAT-Clustering-PowerShell",
        "RSAT-Storage-Replica",
        "RSAT-AD-PowerShell"
    );

    $rules = @(
        "FPS-NB_Datagram-In-UDP",
        "FPS-NB_Name-In-UDP",
        "FPS-NB_Session-In-TCP",
        "FPS-SMB-In-TCP",
        "RemoteFwAdmin-In-TCP",
        "RemoteFwAdmin-RPCSS-In-TCP",
        "RemoteEventLogSvc-In-TCP",
        "RemoteEventLogSvc-NP-In-TCP",
        "RemoteEventLogSvc-RPCSS-In-TCP",
        "RemoteSvcAdmin-In-TCP",
        "RemoteSvcAdmin-NP-In-TCP",
        "RemoteSvcAdmin-RPCSS-In-TCP",
        "WMI-RPCSS-In-TCP",
        "WMI-WINMGMT-In-TCP",
        "WMI-ASYNC-In-TCP",
        "RVM-RPCSS-In-TCP",
        "RVM-VDS-In-TCP",
        "RVM-VDSLDR-In-TCP"
    );

    $admins = @(
        "$($Parameters.domainName)\g-LocalAdmins"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$($Parameters.domainName)\Administrator", $Password);

    Node $ComputerName
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        foreach($rule in $rules)
        {
            Firewall "$rule"
            {
                Name = "$rule"
                Ensure = "Present"
                Enabled = "True"
            }
        }

        WaitForADDomain "WFAD"
        {
            DomainName  = $($Parameters.domainName)
            Credential = $domainCredential
            WaitTimeout = 600
            RestartCount = 2
        }

        Computer "JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $($Parameters.domainName)
            Credential = $domainCredential
            DependsOn = "[WaitForADDomain]WFAD"
        }

        Group "G-Administrators"
        {
            GroupName = "Administrators"
            Credential = $domainCredential
            MembersToInclude = $admins
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteDesktopUsers"
        {
            GroupName = "Remote Desktop Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteDesktopUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$($Parameters.domainName)\g-RemoteManagementUsers"
            DependsOn = "[Computer]JoinDomain"
        }

        Script "EnableRss"
        {
            GetScript = {
                $rssQueues = (Get-NetAdapterAdvancedProperty | Where-Object -Property DisplayName -EQ -Value "Maximum Number of RSS Queues").RegistryValue | Select-Object -First 1;;
                # One less than the number of cores as we are setting the base processor to #2
                $cores = ((Get-WmiObject -Class Win32_Processor).NumberOfCores | Measure-Object -Sum).Sum - 1;
                $smbConfig = Get-SmbClientConfiguration;
                $rssConfig = (Get-NetAdapter | Get-NetAdapterRss);
                $storageSpaceTimeout = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters" -Name "HwTimeout";

                if($smbConfig.EnableMultiChannel -eq $true -and 
                    $smbConfig.ConnectionCountPerRssNetworkInterface -eq $rssQueues -and
                    $rssConfig.BaseProcessorNumber -eq 2 -and
                    $rssConfig.MaxProcessors -eq $cores -and
                    $storageSpaceTimeout -eq 0x00007530)
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
                $rssQueues = (Get-NetAdapterAdvancedProperty | Where-Object -Property DisplayName -EQ -Value "Maximum Number of RSS Queues").RegistryValue | Select-Object -First 1;
                # One less than the number of cores as we are setting the base processor to #2
                $cores = ((Get-WmiObject -Class Win32_Processor).NumberOfCores | Measure-Object -Sum).Sum - 1;

                Set-SmbClientConfiguration -EnableMultiChannel $true -ConnectionCountPerRssNetworkInterface $rssQueues -Confirm:$false;
                Get-NetAdapter | Set-NetAdapterRss -BaseProcessorNumber 2 -MaxProcessors $cores;

                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters" -Name "HwTimeout" -Value 0x00007530;

                # Trigger reboot
                $global:DSCMachineStatus = 1;
            }

            PsDscRunAsCredential = $domainCredential
        }

        if($Parameters.enableCluster -ne $false)
        {
            Firewall "F-GceClusterHelper"
            {
                Name = "GceClusterHelper"
                DisplayName = "GCE Cluster helper"
                Ensure = "Present"
                Enabled = "True"
                Direction = "InBound"
                LocalPort = ("59998")
                Protocol = "TCP"
                Description = "Enables GCP Internal Load Balancer to check which node in the cluster is active to route traffic to the cluster IP."
            }

            $clusterDependency = "[Cluster]CreateCluster";
            if($Parameters.enableDistributedNodeName)
            {
                $clusterDependency = "[Script]CreateCluster";
            }

            if($Parameters.isFirst)
            {
                ADComputer "PrestageClusterResource"
                {
                    ComputerName = "$($Parameters.nodePrefix)-cl"
                    EnabledOnCreation = $false
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[Computer]JoinDomain"
                }

                ADGroup "AddClusterResourceToGroup"
                {
                    GroupName = "g-ClusterResources"
                    GroupScope = "Global"
                    Ensure = "Present"
                    Path = "ou=Groups,$ou"
                    MembersToInclude = "$($Parameters.nodePrefix)-cl`$"
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = "[ADComputer]PrestageClusterResource"
                }

                WaitForAll "Witness"
                {
                    ResourceName = "[SmbShare]Witness"
                    NodeName = $Parameters.witnessName
                    RetryIntervalSec = 5
                    RetryCount = 120
                    DependsOn = "[Computer]JoinDomain"
                }
                
                if($Parameters.enableDistributedNodeName)
                {
                    Script "CreateCluster"
                    {
                        GetScript = {
                            $cluster = Get-Cluster -Name "$($using:Parameters.nodePrefix)-cl" -ErrorAction SilentlyContinue;
                            if($null -ne $cluster)
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
                            New-Cluster -Name "$($using:Parameters.nodePrefix)-cl" -Node "localhost" `
                                -ManagementPointNetworkType Distributed -NoStorage;
                        }
                        
                        DependsOn = "[WindowsFeature]WF-Failover-clustering","[ADGroup]AddClusterResourceToGroup"
                        PsDscRunAsCredential = $domainCredential
                    }
                }
                else
                {
                    Cluster "CreateCluster"
                    {
                        Name = "$($Parameters.nodePrefix)-cl"
                        StaticIPAddress = $Parameters.ipCluster
                        PsDscRunAsCredential = $domainCredential
                        DependsOn = "[WindowsFeature]WF-Failover-clustering","[ADGroup]AddClusterResourceToGroup"
                    }
                }

                ClusterQuorum "Quorum"
                {
                    IsSingleInstance = "Yes"
                    Type = "NodeAndFileShareMajority"
                    Resource = "\\$($Parameters.witnessName)\witness"
                    PsDscRunAsCredential = $domainCredential
                    DependsOn = $clusterDependency
                }

                Script "IncreaseClusterTimeouts"
                {
                    GetScript = {
                        $cluster = Get-Cluster;
                        if($cluster.SameSubnetDelay -eq 2000 -and `
                            $cluster.SameSubnetThreshold -eq 15 -and `
                            $cluster.CrossSubnetDelay -eq 3000 -and `
                            $cluster.CrossSubnetThreshold -eq 15)
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
                        $cluster = Get-Cluster;
                        $cluster.SameSubnetDelay = 2000;
                        $cluster.SameSubnetThreshold = 15;
                        $cluster.CrossSubnetDelay = 3000;
                        $cluster.CrossSubnetThreshold = 15;
                    }
                    
                    DependsOn = $clusterDependency
                    PsDscRunAsCredential = $domainCredential
                }

                $nodes = @();
                for($i = 1; $i -lt $Parameters.nodeCount; $i++) {
                    $nodes += "$($Parameters.nodePrefix)-$i";
                };

                WaitForAll "ClusterJoin"
                {
                    ResourceName = "[Cluster]JoinNodeToCluster"
                    NodeName = $nodes
                    RetryIntervalSec = 5
                    RetryCount = 120
                    DependsOn = $clusterDependency
                    PsDscRunAsCredential = $domainCredential
                }

                if($Parameters.enableStorageSpaces -ne $false)
                {
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
                        }
                        
                        DependsOn = "[WaitForAll]ClusterJoin"
                        PsDscRunAsCredential = $domainCredential
                    }

                    Script "CreateVolume"
                    {
                        GetScript = {
                            if((Get-Volume -FriendlyName $($using:Parameters.nodePrefix) -ErrorAction Ignore) -ne $Null)
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
                            New-Volume -FriendlyName $($using:Parameters.nodePrefix) -StoragePoolFriendlyName $($using:Parameters.nodePrefix) `
                                -ResiliencySettingName "Mirror" -ProvisioningType "Fixed" -FileSystem CSVFS_ReFS -UseMaximumSize;
                        }
                        
                        DependsOn = "[Script]EnableStorageSpacesDirect"
                    }

                    Script "CreateFileServerRole"
                    {
                        GetScript = {
                            $resource = Get-ClusterResource -Name "File Server (\\$($using:Parameters.nodePrefix))" -ErrorAction Ignore;

                            if($resource -ne $Null)
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
                            # Move volume to available storage
                            Remove-ClusterSharedVolume -Name "Cluster Virtual Disk ($($using:Parameters.nodePrefix))";

                            # Create File Share role
                            Add-ClusterFileServerRole -Name $using:Parameters.nodePrefix -Storage "Cluster Virtual Disk ($($using:Parameters.nodePrefix))" -StaticAddress $using:Parameters.ipFsc;
                        }
                        
                        DependsOn = "[Script]CreateVolume"
                        PsDscRunAsCredential = $domainCredential
                    }
                }

                # Script CreateSofs
                # {
                #     GetScript = {
                #         if((Get-ClusterGroup -Name $using:Parameters.nodePrefix -ErrorAction Ignore | Where-Object { $_.GroupType -eq "ScaleoutFileServer" }) -ne $Null)
                #         {
                #             $result = "Present";
                #         }
                #         else
                #         {
                #             $result = "Absent";
                #         }

                #         return @{Ensure = $result};
                #     }
                #     TestScript = {
                #         $state = [scriptblock]::Create($GetScript).Invoke();
                #         return $state.Ensure -eq "Present";
                #     }
                #     SetScript = {
                #         Add-ClusterScaleOutFileServerRole -Name $using:Parameters.nodePrefix;
                #     }
                    
                #     PsDscRunAsCredential = $domainCredential
                #     DependsOn = "[Script]CreateVolume"
                # }

                # Script CreateShare
                # {
                #     GetScript = {
                #         if((Get-SmbShare -Name $using:Parameters.nodePrefix -ErrorAction Ignore) -ne $Null)
                #         {
                #             $result = "Present";
                #         }
                #         else
                #         {
                #             $result = "Absent";
                #         }

                #         return @{Ensure = $result};
                #     }
                #     TestScript = {
                #         $state = [scriptblock]::Create($GetScript).Invoke();
                #         return $state.Ensure -eq "Present";
                #     }
                #     SetScript = {
                #         New-SmbShare -Name $using:Parameters.nodePrefix -Path "C:\ClusterStorage\$($using:Parameters.nodePrefix)" -CachingMode None -FolderEnumerationMode Unrestricted -ContinuouslyAvailable $true -FullAccess "$($using:Parameters.domainName)\Domain Admins","$($using:Parameters.domainName)\johndoe";
                #     }
                    
                #     DependsOn = "[Script]CreateSofs"
                # }
            }
            else
            {
                WaitForAll "WaitForCluster"
                {
                    ResourceName = $clusterDependency
                    NodeName = "$($Parameters.nodePrefix)-0"
                    RetryIntervalSec = 10
                    RetryCount = 180
                    PsDscRunAsCredential = $domainCredential
                }

                Cluster "JoinNodeToCluster"
                {
                    Name = "$($Parameters.nodePrefix)-cl"
                    DependsOn = "[WaitForAll]WaitForCluster"
                    PsDscRunAsCredential = $domainCredential
                }
            }
        }
    }
}