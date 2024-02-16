# Deploy Springboard

```sh
tfdir=../samples/infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
sa_id=`terraform -chdir=$tfdir output -raw sa_id`
location="europe-west1"
tier="tier1"

gcloud infra-manager deployments apply springboard-$tier \
    --project=$project_id \
    --location=$location \
    --service-account=$sa_id \
    --git-source-repo=https://github.com/peterschen/blog \
    --git-source-directory=gcp/projects/springboard/terraform/springboard-$tier \
    --git-source-ref=master \
    --inputs-file=demo.auto.tfvars
```

# Tear down

```sh
tfdir=../samples/infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"
tier="tier1"

gcloud infra-manager deployments delete springboard-$tier \
    --project=$project_id \
    --location=$location \
    --quiet
```
    
# Operations

## Export state file

```sh
tfdir=../samples/infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"
tier="tier1"

uri=`gcloud infra-manager deployments export-statefile springboard-$tier \
    --project=$project_id \
    --location=$location \
    --format="value(signedUri)"`

curl -o default.tfstate "$uri"
```

## Import state file

```sh
tfdir=../samples/infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
location="europe-west1"
tier="tier1"

lock_id=`gcloud infra-manager deployments lock springboard-$tier \
    --project=$project_id \
    --location=$location \
    --format="value(lockId)"`

uri=`gcloud infra-manager deployments import-statefile springboard-$tier \
    --project=$project_id \
    --location=$location \
    --lock-id=$lock_id \
    --format="value(signedUri)"`

curl -X PUT -T default.tfstate "$uri"

gcloud infra-manager deployments unlock springboard-$tier \
    --project=$project_id \
    --location=$location \
    --lock-id=$lock_id
```