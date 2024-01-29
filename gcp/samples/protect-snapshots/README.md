# Protect snapshots #

* Act on snapshot creation
* Release lock after X days

```bash
project_id=`terraform output -raw project_id`
zone=`terraform output -raw zone`

```