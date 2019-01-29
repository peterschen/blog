```
resourceGroupLocation="westus"
resourceGroupName="mylinux"
vaultResourceGroupName="myvaultrg"
vaultName="myvault"
CertSubjectName="mylinux.westus.cloudapp.azure.com"
vmpassword="Password!1"
certpassword="Password!4321"
vmuser="myadmin"
vmOs="UbuntuServer1604"
certOutputFolder="c:\certificates"

az sf cluster create --resource-group $resourceGroupName --location $resourceGroupLocation  \
    --certificate-output-folder $certOutputFolder --certificate-password $certpassword  \
    --vault-name $vaultName --vault-resource-group $resourceGroupName  \
    --template-file $templateFilePath --parameter-file $parametersFilePath --vm-os $vmOs  \
    --vm-password $vmpassword --vm-user-name $vmuser
```