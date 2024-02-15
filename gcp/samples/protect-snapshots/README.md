#  Remove explicit tags on snapshots

```bash
project_workload_id=`terraform output -raw project_workload_id`
tag_value_id=`terraform output -raw tag_value_id`

snapshots=$(gcloud compute snapshots list --project $project_workload_id --format="value(id)")
for snapshot in ${snapshots}; do
    gcloud resource-manager tags bindings delete --parent //compute.googleapis.com/projects/$project_workload_id/global/snapshots/$snapshot --tag-value $tag_value_id
done
```
