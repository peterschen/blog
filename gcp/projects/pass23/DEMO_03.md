# Prep
```sh
# Retrieve Kubernetes credentials
tf_directory=~/dev/pass/terraform
project_id=`terraform -chdir=$tf_directory output -raw project_id`
location=`terraform -chdir=$tf_directory output -raw zone`
cluster=`terraform -chdir=$tf_directory output -raw cluster`

gcloud container clusters get-credentials $cluster --project=$project_id --location=$location
```

# Scenario 3: Scale to zero

1. Done debugging v99, lets remove it to make resources available for other environments
    * [Workloads][https://console.cloud.google.com/kubernetes/workload/overview?project=pass-tomcat-9920]

```sh
kubectl delete ns pr-v99
```

1. Review node-pools
    * [Nodes](https://console.cloud.google.com/kubernetes/clusters/details/europe-west4/redbird-8378/nodes?project=pass-tomcat-9920)

2. Update `default-pool` pool to 0 nodes

```sh 
tf_directory=~/dev/pass/terraform
project_id=`terraform -chdir=$tf_directory output -raw project_id`
location=`terraform -chdir=$tf_directory output -raw zone`
cluster=`terraform -chdir=$tf_directory output -raw cluster`
pool="default-pool"

gcloud container clusters resize $cluster --node-pool=$pool --project=$project_id --location=$location --num-nodes=0 --quiet
```

3. Using Terraform to destroy the entire cluster (including all workloads)

```sh 
tf_directory=~/dev/pass/terraform

terraform -chdir=$tf_directory destroy -target google_container_cluster.cluster
```
