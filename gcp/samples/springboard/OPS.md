# Operations

## Export state file

```sh
tfdir=../infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"

uri=`gcloud infra-manager deployments export-statefile springboard \
    --project=$project_id \
    --location=$location \
    --format="value(signedUri)"`

curl -o terraform.tfstate "$uri"
```

## Import state file

```sh
tfdir=../infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"

lock_id=`gcloud infra-manager deployments lock springboard \
    --project=$project_id \
    --location=$location \
    --format="value(lockId)"`

uri=`gcloud infra-manager deployments import-statefile springboard \
    --project=$project_id \
    --location=$location \
    --lock-id=$lock_id \
    --format="value(signedUri)"`

curl -X PUT -T terraform.tfstate "$uri"

gcloud infra-manager deployments unlock springboard \
    --project=$project_id \
    --location=$location \
    --lock-id=$lock_id
```