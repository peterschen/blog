# Isolated network with proxy egress #

This template uses cloud-init to initialize the proxy VM. To ensure that the cloud-init script is running pass the contents of `cloud-init.yaml` to the `CloudInitData` parameter. The PowerShell example futher down shows how to do this from the command line.

## Deploy with PowerShell ##

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

## Configure proxy ##

When deploying the template a VM preinstalled with `tinyproxy`will be deployed. `tinyproxy` is configured with whitelisting so only endpoints that have previously been added to the whitelist can be accessed. The whitelist can be modified by editing `/etc/tinyproxy/filter`. The changes become active once the service has been reloaded or restarted: `service tinyproxy restart`.

To make use of the proxy point any machines in the `isolated` network to use the proxy. The address of the proxy is `10.0.0.4` and listens on port `8888`. The following screenshot shows how to set the proxy in Internet Explorer:

![Proxy settings in Internet Explorer](proxy-settings.png?raw=true)