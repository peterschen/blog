# Samples #

This directory contains a selection of samples that are referenced in articles.

## [Automation in Azure](automation-in-Azure/) ##

After running this template you need to add a Azure Automation run as account. Additionally you need to start the DSC configuration compilation.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Fautomation-in-azure%2Fazuredeploy.json)

### Configure Azure Automation run as account ###

Navigate to **Automation Accounts > *[your account]* > Run as accounts**:

![Configure Azure Automation run as account step 1](automation-in-azure/runas1.png?raw=true)

Select **Azure Run As Account**:

![Configure Azure Automation run as account step 2](automation-in-azure/runas2.png?raw=true)

Hit **Create**:

![Configure Azure Automation run as account step 3](automation-in-azure/runas3.png?raw=true)

### Compile DSC configuration ###

Navigate to **Automation Accounts > *[your account]* > State configurations (DSC)**:

![Compile DSC configuration step 1](automation-in-azure/dsc1.png?raw=true)

Select **Configurations** and select **Dsc**:

![Compile DSC configuration step 2](automation-in-azure/dsc2.png?raw=true)

Hit **Compile**:

![Compile DSC configuration step 3](automation-in-azure/dsc3.png?raw=true)

## [Automation with Ansibe](automation-with-ansible/) ##

## [Container monitoring demo](container-monitoring-demo/) ##

### Service Principal ###

When running this template you need to specify a service principal that AKS/Kubernetes later can use to interact with other Azure resources (e.g. create a load balancer or a managed disk). Pre-create a service principal by issuing the following command either locally or through [Azure Cloud Shell](https://shell.azure.com).

```Shell
az ad sp create-for-rbac -n "ContainerMonitoring" --skip-assignment
```

The output is similiar to the following. Take note of the `appId` and `password`. These values are required for running the template.

```JSON
{
  "appId": "7248f250-0000-0000-0000-dbdeb8400d85",
  "displayName": "azure-cli-2017-10-15-02-20-15",
  "name": "http://azure-cli-2017-10-15-02-20-15",
  "password": "77851d2c-0000-0000-0000-cb3ebc97975a",
  "tenant": "72f988bf-0000-0000-0000-2d7cd011db47"
}
```

## [Hunting Threats with Azure Security Center](hunting-threats-with-asc/) ##

See [https://blog.peterschen.de/hunting-threats-with-azure-security-center/](https://blog.peterschen.de/hunting-threats-with-azure-security-center/)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Fhunting-threats-with-asc%2Fazuredeploy.json)

## [Inventory VMs with PowerShell DSC and Log Analytics](inventory-with-dsc-and-la/azuredeploy.json) ##

See [https://blog.peterschen.de/inventory-vms-with-powershell-dsc-and-log-analytics/](https://blog.peterschen.de/inventory-vms-with-powershell-dsc-and-log-analytics/)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Finventory-with-dsc-and-la%2Fazuredeploy.json)

## [Linux VM encryption](linux-vm-encryption/azuredeploy.json) ##

### Service Principal ###

When running this template you need to specify a service principal that the VM later can use to interact with Key Vault. Pre-create a service principal by issuing the following command either locally or through [Azure Cloud Shell](https://shell.azure.com).

```Shell
az ad sp create-for-rbac -n "VmEncryption"
```

The output is similiar to the following. Take note of the `appId` and `password`. These values are required for running the template.

```JSON
{
  "appId": "7248f250-0000-0000-0000-dbdeb8400d85",
  "displayName": "azure-cli-2017-10-15-02-20-15",
  "name": "http://azure-cli-2017-10-15-02-20-15",
  "password": "77851d2c-0000-0000-0000-cb3ebc97975a",
  "tenant": "72f988bf-0000-0000-0000-2d7cd011db47"
}
```

## [Isolated network with proxy egress](proxy-egress/azuredeploy.json) ##

This template uses cloud-init to initialize the proxy VM. To ensure that the cloud-init script is running pass the contents of `cloud-init.yaml` to the `CloudInitData` parameter. The PowerShell example futher down shows how to do this from the command line.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Fproxy-egress%2Fazuredeploy.json)

### Deploy with PowerShell ###

```PowerShell
Login-AzureRmAccount
New-AzureRmResourceGroup proxy-egress
New-AzureRmResourceGroupDeployment `
  -Name "proxy-egress" `
  -ResourceGroupName "proxy-egress" `
  -TemplateFile .\azuredeploy.json `
  -AdminUsername "labadmin" `
  -AdminSshKey "<your ssh-key>"
  -CloudInitData (Get-Content -Raw -Path .\cloud-init.yaml) `
  -Verbose
```

### Configure proxy ###

When deploying the template a VM preinstalled with `tinyproxy`will be deployed. `tinyproxy` is configured with whitelisting so only endpoints that have previously been added to the whitelist can be accessed. The whitelist can be modified by editing `/etc/tinyproxy/filter`. The changes become active once the service has been reloaded or restarted: `service tinyproxy restart`.

To make use of the proxy point any machines in the `isolated` network to use the proxy. The address of the proxy is `10.0.0.4` and listens on port `8888`. The following screenshot shows how to set the proxy in Internet Explorer:

![Proxy settings in Internet Explorer](proxy-egress/proxy-settings.png?raw=true)

## [Publish to social with Logic Apps](publish-to-social-with-logic-apps/azuredeploy.json) ##

See [https://blog.peterschen.de/https://blog.peterschen.de/publish-to-social-with-logic-apps//](https://blog.peterschen.de/https://blog.peterschen.de/publish-to-social-with-logic-apps//)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Fpublish-to-social-with-logic-apps%2Fazuredeploy.json)