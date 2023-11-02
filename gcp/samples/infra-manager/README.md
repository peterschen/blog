# Deploy environment
```sh
terraform apply
```

# Demo

1. Find out in which regions InfraManager is currently available

```sh
project_id=`terraform output -raw project_id`
token=`gcloud auth print-access-token`

curl --silent --location "https://config.googleapis.com/v1/projects/$project_id/locations" \
    --header "Authorization: Bearer $token"
```

2. Submit deployment

```sh
project_id=`terraform output -raw project_id`
location="europe-west1"
sa_id=`terraform output -raw sa_id`

gcloud infra-manager deployments apply simple-vm \
    --project=$project_id \
    --location=$location \
    --service-account=$sa_id \
    --git-source-repo=https://github.com/peterschen/blog \
    --git-source-directory=gcp/samples/infra-manager/samples/simple-vm \
    --git-source-ref=master \
    --input-values=project_id=$project_id
```

3. Check what's happening in Cloud Build
    * [Builds][builds]

4. View deployments

```sh
project_id=`terraform output -raw project_id`
location="europe-west1"

gcloud infra-manager deployments list \
    --project=$project_id \
    --location=$location
```

5. Show deployment result
     * [VM instances][instances]

6. Delete deployment

```sh
gcloud infra-manager deployments delete simple-vm \
    --project=$project_id \
    --location=$location \
    --quiet
```

7. Check what's happening in Cloud Build
    * [Builds][builds]

[builds]: https://console.cloud.google.com/cloud-build/builds;region=europe-west1
[instances]: https://console.cloud.google.com/compute/instances