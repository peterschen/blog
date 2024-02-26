# Create VM with public IP

1. [Instance Templates](https://console.cloud.google.com/compute/instanceTemplates/list?project=ts24-springboard-20240228)

2. Deploy `vm-with-external-ip`

3. Try gcloud

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`
project="ts24-springboard-$PROJECT_SUFFIX"
region="europe-west4"
template="vm-with-external-ip"

gcloud compute instances create $template \
    --source-instance-template=projects/$project/regions/$region/instanceTemplates/$template
```

# Create VM without public IP

1. [Instance Templates](https://console.cloud.google.com/compute/instanceTemplates/list?project=ts24-springboard-20240228)

2. Deploy `vm-without-external-ip`
