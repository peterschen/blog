# Create VM with public IP

1. [Instance Templates](https://console.cloud.google.com/compute/instanceTemplates/list?project=ts24-springboard-20240228)

2. Try gcloud

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

project="ts24-springboard-$PROJECT_SUFFIX"
region="europe-west4"
zone="$region-c"
template="vm-with-external-ip"

gcloud compute instances create $template \
    --project $project \
    --zone $zone \
    --source-instance-template=projects/$project/global/instanceTemplates/$template
```

# Create VM without public IP

1. [Instance Templates](https://console.cloud.google.com/compute/instanceTemplates/list?project=ts24-springboard-20240228)

2. Deploy `vm-without-external-ip`

# Create VM in a restricted region

1. Run gcloud

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

project="ts24-springboard-$PROJECT_SUFFIX"
region="europe-west1"
zone="$region-c"
template="vm-in-belgium"

gcloud compute instances create $template \
    --project $project \
    --zone $zone \
    --source-instance-template=projects/$project/global/instanceTemplates/$template
```

#  Add principal from another organization

1. [Cloud IAM](https://console.cloud.google.com/iam-admin/iam?project=ts24-springboard-20240228)
2. Add principal from another organization