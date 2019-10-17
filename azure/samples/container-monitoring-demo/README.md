# Container monitoring demo #

## Service Principal ##

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