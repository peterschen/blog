# SLQ Server licensing when running on GKE

Thing to try

* What if one or more data disks attached to a VM have the SQL license string? Would this result in being charged exactly once for the license?
* What if we use the user-license to update the boot disk? Will that work with GKE upgrades and repairs? At what point will user-license be removed entirely?
* Could a daemon set be used, with a small disk that has the SQL license string, and is running exactly once on each node in a pool that will run SQL Servers?

## Ops

```sh
project_id=`terraform output -raw project_id`
region=`terraform output -raw region`
location=`terraform output -raw zone`
cluster=`terraform output -raw cluster`

gcloud container node-pools delete default-pool --project=$project_id --cluster=$cluster --location=$location --quiet

```