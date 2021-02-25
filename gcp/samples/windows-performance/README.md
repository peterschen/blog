# Windows Performance #
TBD

## Prerequisites ##
You need to have a Project with billing enabled to deploy the required resources. Additionally Terraform needs to be setup locally or you can use Cloud Shell to deploy the templates.

## Configure environment ##
These instructions work for Linux, macOS and Cloud Shell. For Windows you may need to adapt these instructions.

```
export PROJECT=$GOOGLE_CLOUD_PROJECT # Set to proper project name if not using Cloud Shell
export SA_KEY_FILE=~configs/sa/terraform@cbp-sandbox.json # Set to the Service Account file
export PASSWORD="Admin123Admin123" # Set to the desired password

export GOOGLE_APPLICATION_CREDENTIALS=$SA_KEY_FILE
gcloud auth activate-service-account --key-file=$SA_KEY_FILE
gcloud config set project $PROJECT

terraform init
terraform get -update
```

## Deploy resource ##
```
terraform apply -var project=$PROJECT -var password=$PASSWORD
```

## Destroy resources ##
```
terraform destroy -var project=$PROJECT -var domain-name=$DOMAIN -var password=$PASSWORD
```

## Redeploy ##
If you need to redeploy the VM instances you need to taint them first. You may need to do this if you have changed the DSC configuration which does not invalidate the Terraform state.

```
terraform taint module.bastion.google_compute_instance.bastion

terraform apply -var project=$PROJECT -var password=$PASSWORD
```