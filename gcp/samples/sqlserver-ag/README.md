# SQL Server on GCP #
This sample deploys SQL Server (Cluster) on Google Cloud. It relies on the [`ad`](../../modules/ad/) and [`sqlserver`](../../modules/sqlserver/) modules. This sample is very opinionated and only leaves a few parameters to configure. It is meant for rapid deployment for development environments to validate capabilities or test things out.

* VPC Network
* Cloud NAT (with Cloud Router)
* 4 Firewall rules (no internet ingress)
* 2 Compute Engine instances for Active Directory
* 2 Compute Engine instances for SQL Server 2019 Enterprise
* Cloud DNS private forward zone with forwarding
* Cloud DNS private reverse zone
* 2 unmanaged instance groups
* Layer-4 ILB for Windows Server Failover Cluster

Additionally the deployment will enable the neccessary APIs required to deploy the resources listed above:

* Cloud Resource Manager API
* Compute Engine API
* Google Cloud DNS API

## Prerequisites ##
You need to have a Project with billing enabled to deploy the required resources. Additionally Terraform needs to be setup locally or you can use Cloud Shell to deploy the templates.

## Configure environment ##
These instructions work for Linux, macOS and Cloud Shell. For Windows you may need to adapt these instructions.

```
export PROJECT=$GOOGLE_CLOUD_PROJECT # Set to proper project name if not using Cloud Shell
export SA_KEY_FILE=~/configs/sa/terraform@cbp-common.json # Set to the Service Account file
export PASSWORD="Admin123Admin123" # Set to the desired password
export DOMAIN="sandbox.lab" # Set to the desired domain name

# By default Windows Server Failover Clustering (WSFC) will be provisioned automatically.
# You can disable automatic deployment which will enable WSFC, S2D and SOFS
export ENABLE_CLUSTER=false

export GOOGLE_APPLICATION_CREDENTIALS=$SA_KEY_FILE
gcloud auth activate-service-account --key-file=$SA_KEY_FILE
gcloud config set project $PROJECT

terraform init
terraform get -update
```

## Deploy resource ##
```
terraform apply -var project=$PROJECT -var name-domain=$DOMAIN -var password=$PASSWORD -var enable-cluster=$ENABLE_CLUSTER"
```

## Destroy resources ##
```
terraform destroy -var project=$PROJECT -var name-domain=$DOMAIN -var password=$PASSWORD
```

## Redeploy ##
If you need to redeploy the VM instances you need to taint them first. You may need to do this if you have changed the DSC configuration which does not invalidate the Terraform state.

```
terraform taint module.ad.google_compute_instance.dc\[0\]
terraform taint module.ad.google_compute_instance.dc\[1\]
terraform taint module.bastion.google_compute_instance.bastion
terraform taint module.sofs.google_compute_instance.sql\[0\]
terraform taint module.sofs.google_compute_instance.sql\[1\]

terraform apply -var project=$PROJECT -var name-domain=$DOMAIN -var password=$PASSWORD -var enable-cluster=$ENABLE_CLUSTER"
```

## Using the environment ##

Once the deployment has completed it takes up to 15 minutes for the configuration of Active Directory to complete. 

To connect to the environment you can make use of [Identity Aware TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding) to establish a tunnel from your machine into the environment to connect to RDP. Firewall rules to allow IAP TCP forwarding ingress are automatically deployed as part of template.

Open the tunnel:

```sh
gcloud compute start-iap-tunnel bastion 3389 --local-host-port=localhost:3389
```

Now you can point your favorite RDP tool to `localhost:3389` and connect to the jumpbox:

![Remote Desktop connection to the jumpbox](rdp.png?raw=true)

### Credentials ###

The `Administrator` windows account is enabled and the password is set to the password that you specificed during deployment.

Additionally a  `$DOMAIN\johndoe` user with administrative rights was created during deloyment and the password was set to the one specificed during deployment as well.

**Note:** PowerShell DSC runs on a repeating schedule and will reconfigure the system at least every 30 minutes. If you change the password for the default user this will be reset to the default after 30 minutes.