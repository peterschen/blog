# Protect snapshots #

* Act on snapshot creation
* Release lock after X days

##  Remove explicit tags on snapshots

```bash
project_workload_id=`terraform output -raw project_workload_id`
tag_value_id_disabled=`terraform output -raw tag_value_id_disabled`

snapshots=$(gcloud compute snapshots list --project $project_workload_id --format="value(id)")
for snapshot in ${snapshots}; do
    gcloud resource-manager tags bindings delete --parent //compute.googleapis.com/projects/$project_workload_id/global/snapshots/$snapshot --tag-value $tag_value_id_disabled
done
```