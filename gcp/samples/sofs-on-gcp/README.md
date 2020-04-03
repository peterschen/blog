# SOFS on GCP #
This sample deploys a Scale-out File Server on Google Cloud. It relies on the `ad-on-gcp` sample. This sample is very opinionated and only leaves a few parameters to configure. It is meant for rapid deployment for development environments to validate capabilities or test things out.

## Configure environment ##
These instructions work for Linux, macOS and Cloud Shell. For Windows you may need to adapt these instructions.

```
export PROJECT=$GOOGLE_CLOUD_PROJECT # Set to proper project name if not using Cloud Shell
export SA_KEY_FILE=~configs/sa/terraform@cbp-sofs.json # Set to the Service Account file
export PASSWORD="Admin123Admin123" # Set to the desired password
export DOMAIN="sofs.lab" # Set to the desired domain name

export GOOGLE_APPLICATION_CREDENTIALS=$SA_KEY_FILE
gcloud auth activate-service-account --key-file=$SA_KEY_FILE
gcloud config set project $PROJECT

terraform init
terraform get -update
```

## Deploy resource ##
```
terraform apply -var="project=$PROJECT" -var="name-domain=$DOMAIN" -var="password=$PASSWORD"
```

## Destroy resources ##
```
terraform destroy -var="project=$PROJECT" -var="name-domain=$DOMAIN" -var="password=$PASSWORD"
```
## Redeploy ##
If you need to redeploy the VM instances you need to taint them first. You may need to do this if you have changed the DSC configuration which does not invalidate the Terraform state.

```
terraform taint module.ad-on-gcp.google_compute_instance.jumpy
terraform taint module.ad-on-gcp.google_compute_instance.dc\[0\]
terraform taint module.ad-on-gcp.google_compute_instance.dc\[1\]
terraform taint google_compute_instance.sofs\[0\]
terraform taint google_compute_instance.sofs\[1\]
terraform taint google_compute_instance.sofs\[2\]

terraform apply -var="project=$PROJECT" -var="name-domain=$DOMAIN" -var="password=$PASSWORD"
```