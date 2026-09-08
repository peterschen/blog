# Monitoring Hackathon

## Initial deployment
This hackathon uses subscription level deployment to roll out a set of resources that are used throughout the challenges. Kicking-off the initial deployment can be done with Azure CLI (or PowerShell). If not specified, the default values will be taken and you will be prompted for `AdminUsername` and `AdminUserPassword`. 

> **Note:** Make sure to select a short prefix for the parameter `NameResourceGroup`. This is the name of the resource group that is created as part of the deployment and also as name or prefix for many of the resources deployed.

```
az deployment create \
    --name azmh \
    --location westeurope \
    --template-file azuredeploy.json
```

## Challenge 1
Focus of the challenge is to understand how telemetry can be collected from VMs running on Azure. Azure monitor and the associated sink are leveraged to collect telemetry directly into Azure monitor for dashboarding and alerting purposes.

As of designing this hackathon the Azure monitor sink is not integrated into the Azure portal. The only way to enable this feature is to update existing VM definitions and add the sink. This requires that the VM is registeres to Azure Active Directory (managed identity) and the extension is configured accordingly.

The following snippet shows how to enable the managed identity for the VMs:
```
{
    "type": "Microsoft.Compute/virtualMachines",
    "name": "[concat(variables('nameVm'), copyIndex())]",
    "apiVersion": "2017-12-01",
    "location": "[variables('location')]",
    "identity": {
        "type": "SystemAssigned"
    },
    "properties": {},
    "copy": {
        "name": "copyVm",
        "count": "[variables('countVm')]"
    }
}
```

The following snippet shows how to enable the identity helper that is required for the diagnostics extension to write to Azure monitor with the identity assigned to the VM:
```
{
    "type": "Microsoft.Compute/virtualMachines/extensions",
    "name": "[concat(variables('nameVm'), copyIndex(), '/Microsoft.ManagedIdentity')]",
    "apiVersion": "2018-10-01",
    "location": "[resourceGroup().location]",
    "properties": {
        "publisher": "Microsoft.ManagedIdentity",
        "type": "ManagedIdentityExtensionForWindows",
        "typeHandlerVersion": "1.0",
        "autoUpgradeMinorVersion": true,
        "settings": {
            "port": 50342
        }
    },
    "copy": {
        "name": "copyVmExtensionManagedIdentity",
        "count": "[variables('countVm')]"
    },
    "dependsOn": [
        "[concat('Microsoft.Compute/virtualMachines/', variables('nameVm'), copyIndex())]"
    ]
}
```

Lastly the updated configuration of the diagnostics extension looks like the following snippet:
```
{
    "type": "Microsoft.Compute/virtualMachines/extensions",
    "name": "[concat(variables('nameVm'), copyIndex(), '/Microsoft.Azure.Diagnostics')]",
    "apiVersion": "2018-10-01",
    "location": "[resourceGroup().location]",
    "properties": {
        "publisher": "Microsoft.Azure.Diagnostics",
        "type": "IaaSDiagnostics",
        "typeHandlerVersion": "1.12",
        "autoUpgradeMinorVersion": true,
        "settings": {
            "WadCfg": {
                "DiagnosticMonitorConfiguration": {
                    "overallQuotaInMB": 4096,
                    "PerformanceCounters": {
                        "scheduledTransferPeriod": "PT1M",
                        "sinks": "AzureMonitorSink",
                        "PerformanceCounterConfiguration": [
                            {
                                "counterSpecifier": "\\LogicalDisk(C:)\\Avg. Disk Queue Length",
                                "sampleRate": "PT15S",
                                "unit": "Count"
                            },
                            {
                                "counterSpecifier": "\\LogicalDisk(C:)\\Disk Transfers/sec",
                                "sampleRate": "PT15S",
                                "unit": "Count"
                            },
                            {
                                "counterSpecifier": "\\Memory\\% Committed Bytes In Use",
                                "sampleRate": "PT15S",
                                "unit": "%"
                            },
                            {
                                "counterSpecifier": "\\Processor(_Total)\\% Processor Time",
                                "sampleRate": "PT15S",
                                "unit": "%"
                            }
                        ]
                    }
                },
                "SinksConfig": {
                    "Sink": [
                        {
                            "name": "AzureMonitorSink",
                            "AzureMonitor": {}
                        }
                    ]
                }
            },
            "StorageAccount": "[variables('nameStorage')]"
        },
        "protectedSettings": {
            "storageAccountName": "[variables('nameStorage')]",
            "storageAccountKey": "[listKeys(variables('idStorage'), '2015-06-15').key1]",
            "storageAccountEndPoint": "https://core.windows.net/"
        }
    },
    "copy": {
        "name": "copyVmExtensionDiagnostics",
        "count": "[variables('countVm')]"
    },
    "dependsOn": [
        "[concat('Microsoft.Compute/virtualMachines/', variables('nameVm'), copyIndex(), '/extensions/Microsoft.ManagedIdentity')]"
    ]
}
```

### Sample solution
A complete sample solution is defined in [challenge1.json](challenge1.json?raw=true) and can be deployed as follows:
```
az group deployment create \
    --name challenge1
    --resource-group mh \
    --template-file challenge1.json
```

Metrics sent to Azure monitor sink are added to the `azure.vm.windows.guest` namespace. Creating a widget is a matter of simply selecting the VM or VMs, the proper metrics and adding it to the dashboard. This is how that can look like:

![In-guest metrics pinned to the dashboard](challenge1.png?raw=true)

## Challenge 2
### Sample solution
A complete sample solution is defined in [challenge2.json](challenge2.json?raw=true) and can be deployed as follows:
```
az group deployment create \
    --name challenge2 \
    --resource-group mh \
    --template-file challenge2.json \
    --parameters '{"NameEmailreceiver": {"value": "John Smith"}, "Email": {"value": "johnsmith@contoso.com"}}'
```
## Challenge 3

Query to calculate the availability for VMs
```
Heartbeat
| where Computer in ('vm0', 'vm1', 'vm2')
| summarize HeartbeatsPerMinute = count() by bin_at(TimeGenerated, 1m, ago(1d)), Computer
| extend AvailablePerMinute = iff(HeartbeatsPerMinute > 0, true, false)
| summarize AvailableMinutes = countif(AvailablePerMinute == true) by Computer
| extend Bins = round((now() - ago(1d)) / 1m)
| extend Availability = AvailableMinutes * 100 / Bins
| order by Availability desc
```

Query to calculate the avg. CPU utilization across VMs
```
Perf
| where Computer in ('vm0', 'vm1', 'vm2')
| where ObjectName == 'Processor'
| where CounterName == '% Processor Time'
| where InstanceName == '_Total'
| summarize UtilizationCpu=avg(CounterValue) by Computer
```

Query to calculate the avg. memory utilization across VMs
```
Perf
| where Computer in ('vm0', 'vm1', 'vm2')
| where ObjectName == 'Memory'
| where CounterName == '% Committed Bytes In Use'
| summarize UtilizationMemory=avg(CounterValue) by Computer
```

Query to calculate the SLA across availability, cpu, and memory utilization:
```
// Presets
let thresholdAvailability = 90;
let thresholdCpu = 50;
let thresholdMemory = 90;
// Run SLA calculation
slaAvailability 
| join kind = inner (slaUtilizationCpu) on Computer
| join kind = fullouter (slaUtilizationMemory) on Computer
| summarize avg(Availability), statusAvailabilitySla = iif(avg(Availability) < thresholdAvailability, "Bad", "Good"),
            avg(UtilizationCpu), cpuSLA = iif(avg(UtilizationCpu) > thresholdCpu, "Bad", "Good"),
            avg(UtilizationMemory), memSLA = iif(avg(UtilizationMemory) > thresholdMemory, "Bad", "Good"),
            ComputerList = makeset(Computer),
            dcount(Computer)
```

### Sample solution
A complete sample solution is defined in [challenge3.json](challenge3.json?raw=true) and can be deployed as follows:
```
az group deployment create \
    --name challenge3 \
    --resource-group mh \
    --template-file challenge3.json
```
## Challenge 4