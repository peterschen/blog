# Demo 1

Fundamentals of running SQL Server on Google Cloud.

## Show deployment of VM with image

1. Open **Create an Instance** wizard
1. Explain process
    * Region & zone
    * Machine configuration
    * Boot disk
1. Change Boot disk
    * Show versions of SQL Server

## Basic Monitoring & Logging 

1. Open **VM Instances dashboard**
    * Switch to table view
    * Show that `sql-0` is monitored and `SQL Server` integration is active
1. Open **SQL Server Dashboards**
    * Show metrics
    * Show logs
1. Open **Integrations**
    * Configure alerts

## Backup & recovery / Cloning

1. Open **Disks**
2. Create Snapthot from `sql-0`
    * Type: `Instant snapshot`
    * Name: `pass-demo-1`
3. Open snapshot
4. Create disk from snapshot
    * Name: `clone-1`
5. Attach disk

```sh
project=`terraform output -raw project_id_demo1`
zone=`terraform output -raw zone_demo1`

gcloud compute instances attach-disk sql-0 \
        --disk clone-1 \
        --device-name clone-1 \
        --project $project \
        --zone $zone
```

6. Open **Disk Management**
7. Online disk