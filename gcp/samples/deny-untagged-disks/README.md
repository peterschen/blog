# Deny untagged disks #

This sample uses resource tags and IAM deny policy to prevent untagged disks from being created. This technique can be used to control which disk sources can be used for VMs and manage compliance for certain use-cases like Microsoft licensing.

## Create tagged disk

While tag bindings for disks can be added upon resource creationg, Terraform does not currently support this. The following command will create a tagged disk manually.

```sh
project_id=`terraform output -raw project_id`
zone=`terraform output -raw zone`
tag_key_id=`terraform output -raw tag_key_id`
tag_value_id=`terraform output -raw tag_value_id`

# gcloud compute disks does not support tags on resource creation
# gcloud compute disks create disk-with-tag --project=$project --zone=$zone --resource-manager-tags=$tag_key_id=$tag_value_id

token=`gcloud auth print-access-token`
uri="https://compute.googleapis.com/compute/v1/projects/$project_id/zones/$zone/disks"
header="Authorization: Bearer $token"

read -r -d '' body << EOB 
{
  "name": "disk-with-tag",
  "sizeGb": "10",
  "sourceImage": "projects/debian-cloud/global/images/family/debian-12",
  "type": "projects/$project_id/zones/$zone/diskTypes/pd-balanced",
  "params": {
    "resourceManagerTags": {
      "$tag_key_id": "$tag_value_id"
    }
  }  
}
EOB

operation=`curl $uri \
    -X POST \
    -H "$header" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    --data-raw "$body" \
    --compressed`
```
