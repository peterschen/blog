# Auto AD Join #

## Prerequisites ##
You need to have a Project with billing enabled to deploy the required resources. Additionally Terraform needs to be setup locally or you can use Cloud Shell to deploy the templates.

## Build code
```
git clone https://github.com/GoogleCloudPlatform/gce-automated-ad-join.git
cd gce-automated-ad-join/ad-joining

cat cloudbuild.yaml | sed -e '23,28d;30,32d;49,70d' > cloudbuild.hydrated.yaml

gcloud builds submit . \
  --config cloudbuild.hydrated.yaml \
  --substitutions _IMAGE_TAG=$(git rev-parse --short HEAD)
```

## Configure environment ##
These instructions work for Linux, macOS and Cloud Shell. For Windows you may need to adapt these instructions.

```
export PROJECT=$GOOGLE_CLOUD_PROJECT # Set to proper project name if not using Cloud Shell
export SA_KEY_FILE=~/configs/sa/terraform@cbp-sandbox.json # Set to the Service Account file
export PASSWORD="Admin123Admin123" # Set to the desired password
export DOMAIN="sandbox.lab" # Set to the desired domain name

export GOOGLE_APPLICATION_CREDENTIALS=$SA_KEY_FILE
gcloud auth activate-service-account --key-file=$SA_KEY_FILE
gcloud config set project $PROJECT

terraform init
terraform get -update
```

## Deploy resource ##
```
terraform apply -var project=$PROJECT -var domain-name=$DOMAIN -var password=$PASSWORD
```

### Scale MIGs to one instance
```
migs=( windows-1809-core windows-1809-core-for-containers windows-1903-core windows-1903-core-for-containers windows-1909-core windows-1909-core-for-containers windows-2012-r2 windows-2012-r2-core windows-2016 windows-2016-core windows-2019-core-for-containers windows-2019 windows-2019-core windows-2019-for-containers windows-20h2-core windows-2022 windows-2022-core )

for mig in "${migs[@]}"; do
  gcloud compute instance-groups managed resize $mig --size=1
done
```

## Destroy resources ##
```
terraform destroy -var project=$PROJECT -var domain-name=$DOMAIN -var password=$PASSWORD
```

### Scale MIGs to zero instances
```
migs=( windows-1809-core windows-1809-core-for-containers windows-1903-core windows-1903-core-for-containers windows-1909-core windows-1909-core-for-containers windows-2012-r2 windows-2012-r2-core windows-2016 windows-2016-core windows-2019-core-for-containers windows-2019 windows-2019-core windows-2019-for-containers windows-20h2-core windows-2022 windows-2022-core )

for mig in "${migs[@]}"; do
  gcloud compute instance-groups managed resize $mig --size=0
done
```

## Redeploy ##
If you need to redeploy the VM instances you need to taint them first. You may need to do this if you have changed the DSC configuration which does not invalidate the Terraform state.

```
terraform taint module.activedirectory.google_compute_instance.dc\[0\]
terraform taint module.activedirectory.google_compute_instance.dc\[1\]

terraform apply -var project=$PROJECT -var name-domain=$DOMAIN -var password=$PASSWORD
```

### Replace MIG instances
```
migs=( windows-1809-core windows-1809-core-for-containers windows-1903-core windows-1903-core-for-containers windows-1909-core windows-1909-core-for-containers windows-2012-r2 windows-2012-r2-core windows-2016 windows-2016-core windows-2019-core-for-containers windows-2019 windows-2019-core windows-2019-for-containers windows-20h2-core windows-2022 windows-2022-core )

for mig in "${migs[@]}"; do
  gcloud compute instance-groups managed rolling-action replace $mig
done
```

## Using the environment ##

Once the deployment has completed it takes up to 15 minutes for the configuration of Active Directory to complete. 

To connect to the environment you can make use of [Identity Aware TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding) to establish a tunnel from your machine into the environment to connect to RDP. Firewall rules to allow IAP TCP forwarding ingress are automatically deployed as part of template.

Open the tunnel:

```sh
gcloud compute start-iap-tunnel bastion 3389 --local-host-port=localhost:3389
```

Now you can point your favorite RDP tool to `localhost:3389` and connect to the jumpbox.

### Credentials ###

The `Administrator` windows account is enabled and the password is set to the password that you specificed during deployment.

Additionally a  `$DOMAIN\johndoe` user with administrative rights was created during deloyment and the password was set to the one specificed during deployment as well.

**Note:** PowerShell DSC runs on a repeating schedule and will reconfigure the system at least every 30 minutes. If you change the password for the default user this will be reset to the default after 30 minutes.