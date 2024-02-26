# Delete deployment

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

tfdir=./host
input_file="/tmp/ts24-host-$PROJECT_SUFFIX.tfvars"

terraform -chdir=$tfdir destroy \
    -var enable_peering=false \
    -var-file=$input_file \
    -auto-approve -refresh=false
```

```sh
tfdir=../infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"

gcloud infra-manager deployments delete springboard \
    --project=$project_id \
    --location=$location \
    --quiet
```
