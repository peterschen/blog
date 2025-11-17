# Demo 5

Using Async PD to replicate data and log volumes consistently across regions.

## Prep

## Fix deployment

In some cases the disk status is not properly set when starting the replication. These commands will import the resource so the project can be deleted successfully.

```sh
project=`terraform output -raw project_id_demo3`
zone=`terraform output -raw zone_demo3`

terraform import google_compute_disk_async_replication.demo3_data[0] projects/$project/zones/$zone/disks/data
terraform import google_compute_disk_async_replication.demo3_log[0] projects/$project/zones/$zone/disks/log
```

## Reconfigure Load Balancer

1. Explain failover and use the time to go through the UI to explain the async replication configuration

```sh
project=`terraform output -raw project_id_demo3`
zone=`terraform output -raw zone_demo3`
zone_secondary=`terraform output -raw zone_secondary_demo3`

gcloud compute backend-services update-backend sql \
    --project $project \
    --global \
    --network-endpoint-group sql \
    --network-endpoint-group-zone $zone_secondary \
    --capacity-scaler 1

gcloud compute backend-services update-backend sql \
    --project $project \
    --global \
    --network-endpoint-group sql \
    --network-endpoint-group-zone $zone \
    --capacity-scaler 0
```

## Setting the scene

1. Show UI with data streaming in
    * Highlight SQL Server connection and server name
1. Show disks in Cloud Console
    * [Disks](https://console.cloud.google.com/compute/disks)
1. Show Asynchronous replication configuration
    * [Asynchronous replication](https://console.cloud.google.com/compute/asynchronousReplication)
1. Write order consistency ensured through consistency groups
1. Show storage configuration on sql-0
    * Disk configuration
    * Explain two separate drives for data and log and impact on consistency

## Show replication metrics

1. Open dashboard and show replication metrics

## Clone replicated disks

1. Create clone from secondary disk and attach it to a VM in that region

```sh
project=`terraform output -raw project_id_demo3`
zone=`terraform output -raw zone_demo3`
zone_secondary=`terraform output -raw zone_secondary_demo3`
group=`gcloud compute resource-policies list --project $project --filter "region=europe-west3" --format "value(self_link)"`

gcloud compute disks bulk create \
    --source-consistency-group-policy=$group \
    --project $project \
    --zone $zone_secondary

# Attach disks
disks=`gcloud compute disks list --project $project --filter "name~data- OR name~log-" --format "value(name)" | sort`
for disk in $disks; do
    gcloud compute instances attach-disk sql-recovery-0 \
        --disk $disk \
        --device-name $disk \
        --project $project \
        --zone $zone_secondary
    sleep 5
done
```

2. Show disks in Cloud Console

## Attach database

1. Attach database
```sql
CREATE DATABASE [pass]
ON 
	(FILENAME = N'D:\pass.mdf'),
	(FILENAME = N'E:\pass.ldf')
FOR ATTACH
GO
```
2. Show UI with streaming data
