# Azure Resource Manager Templates #
This directory contains a selection of ARM templates.

## [Publish to social with Logic Apps](publish-to-social-with-logic-apps/azuredeploy.json) ##
See [https://blog.peterschen.de/publish-to-social-with-logic-apps/](https://blog.peterschen.de/publish-to-social-with-logic-apps/)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fpeterschen%2Fblog%2Fblob%2Fmaster%2Ftemplates%2Fpublish-to-social-with-logic-apps%2Fazuredeploy.json)

## [Container monitoring demo](container-monitoring-demo/azuredeploy.json) ##
[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fpeterschen%2Fblog%2Fblob%2Fmaster%2Ftemplates%2Fcontainer-monitoring-demo%2Fazuredeploy.json)

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

## [Linux VM encryption](linux-vm-encryption/azuredeploy.json) ##
[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fpeterschen%2Fblog%2Fblob%2Fmaster%2Ftemplates%2Flinux-vm-encryption%2Fazuredeploy.json)

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

## [Automation with Ansible](automation-with-ansible/azuredeploy.json) ##
[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Fpeterschen%2Fblog%2Fblob%2Fmaster%2Ftemplates%2Fautomation-with-ansible%2Fazuredeploy.json)