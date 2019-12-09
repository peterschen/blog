# AD on GCP #

This sample demonstrates how Microsoft Windows deployments can be automated on Google Cloud Platform by example of a fully automated Active Directory setup. This sample uses Terraform to manage the required cloud infrastructure in GCP and PowerShell Desired State Configuration to manage the in-guest configuration.

## Prerequisites ##

You need to have a Project with billing enabled to deploy the required resources. Additionally Terraform needs to be setup locally or you can use Cloud Shell to deploy the templates.

## Deployment ##

Before you deploy, update `variables.tf` to match your project and preferences. You can also specify the unset variables on the Terraform commandline at deployment time. These variables need to be set in `variables.tf` or passed at deployment time:

![Variables to configure](variables.png?raw=true)

If you have setup the prerequisites and updates `variables.tf` you can deploy the sample:

```sh
terraform apply
```

If you opted to specify the variables at deployment time you will be asked to provide the missing variables or you can provide them when invoking Terraform:

```sh
terraform apply -var="project=cbp-samples" -var="name-domain=test.gcp" -var="password=Admin123Admin123"
```

The deployment will take a few minutes and create the following resources:

* VPC Network
* Cloud NAT (with Cloud Router)
* 4 Firewall rules (no internet ingress)
* 2 Compute Engine instances
* Cloud DNS private forward zone with forwarding
* Cloud DNS private reverse zone

Additionally the deployment will enable the neccessary APIs required to deploy the resources listed above:

* Cloud Resource Manager API
* Compute Engine API
* Google Cloud DNS API

## Using the environment ##

Once the deployment has completed it takes about 15 minutes for the configuration of Active Directory to complete. The deployment itself takes about 5 minutes where the majority of the time is spent waiting for the necessary APIs to be enabled.

To connect to the environment you can make use of [Identity Aware TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding) to establish a tunnel from your machine into the environment to connect to RDP. Firewall rules to allow IAP TCP forwarding ingress are automatically deployed as part of template.

Open the tunnel:

```sh
gcloud beta compute start-iap-tunnel jumpy 3389 --local-host-port=localhost:3389
```

Now you can point your favorite RDP tool to `localhost:3389` and connect to the jumpbox:

![Remote Desktop connection to the jumpbox](rdp.png?raw=true)

### Credentials ###

The `Administrator` windows account is enabled and the password is set to the password that you specificed during deployment.

Additionally a  `johndoe` user with administrative rights was created during deloyment and the password was set to the one specificed during deployment as well.

**Note:** PowerShell DSC runs on a repeating schedule and will reconfigure the system at least every 30 minutes. If you change the password for the default user this will be reset to the default after 30 minutes.

## Cleanup ##

In case you want to cleanup the environment you can delete all Terraform managed resources by running:

```sh
terraform destroy
```
