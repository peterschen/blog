# Deploy resources
```sh
terraform -chdir=terraform apply
```

# Cloud Build: Manually submit build

## cloud-sdk container

```sh
project_id=`terraform -chdir=terraform output -raw project_id`
region=`terraform -chdir=terraform output -raw region`
gcloud builds submit --project=$project_id --region=$region --config=build/cloud-sdk.yml
```

## App container
```sh
project_id=`terraform -chdir=terraform output -raw project_id`
region=`terraform -chdir=terraform output -raw region`
af_name=`terraform -chdir=terraform output -raw registry_name`
cluster=`terraform -chdir=terraform output -raw cluster`
gcloud builds submit --project=$project_id --region=$region --config=build/pr.yml --substitutions=_AF_REGION="$region",_AF_REPOSITORY="$af_name",_IMAGE_NAME="contosouniversity",_GKE_REGION="$region",_GKE_CLUSTER="$cluster",BRANCH_NAME="main"
```

# GKE: Retrieve credentials
```sh
project_id=`terraform -chdir=terraform output -raw project_id`
region=`terraform -chdir=terraform output -raw region`
cluster=`terraform -chdir=terraform output -raw cluster`
gcloud container clusters get-credentials $cluster --project=$project_id --location=$region
```

# GKE: Restart deployment
```sh
kubectl rollout restart deployment.apps/app --namespace=pass-standalone
```

# Standalone deployment

## Create resource
```sh
kubectl apply \
  -f data/standalone-00-namespace.yml \
  -f data/standalone-10-secret.yml \
  -f data/standalone-20-storageclass.yml \
  -f data/standalone-25-persistentvolumeclaim.yml \
  -f data/standalone-30-database.yml \
  -f data/standalone-40-app.yml
```

## Delete resources
```sh
kubectl delete \
  -f data/standalone-00-namespace.yml
```
