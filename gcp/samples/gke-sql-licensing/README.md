# SLQ Server licensing when running on GKE

Thing to try

* What if one or more data disks attached to a VM have the SQL license string? Would this result in being charged exactly once for the license?
* What if we use the user-license to update the boot disk? Will that work with GKE upgrades and repairs? At what point will user-license be removed entirely?
* Could a daemon set be used, with a small disk that has the SQL license string, and is running exactly once on each node in a pool that will run SQL Servers?
* 

# Tests

## Multiple data disks with a SQL Server license attached to a VM

## Attach user-licese to a GKE node boot disk after creation

As per [Node VM modifications](https://cloud.google.com/kubernetes-engine/docs/concepts/node-images#modifications), modifications to node VM boot disks are not persistent across node re-creations.

## Daemon set with SQL Server license attached

```sh
project_id=`terraform output -raw project_id`
region=`terraform output -raw region`
location=`terraform output -raw zone`
cluster=`terraform output -raw cluster`

gcloud container clusters get-credentials $cluster --project=$project_id --location=$location
```

# Ops

## Delete node-group 

```sh
project_id=`terraform output -raw project_id`
region=`terraform output -raw region`
location=`terraform output -raw zone`
cluster=`terraform output -raw cluster`

gcloud container node-pools delete default-pool --project=$project_id --cluster=$cluster --location=$location --quiet

```