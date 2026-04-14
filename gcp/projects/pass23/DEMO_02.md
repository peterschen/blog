# Prep
```sh
# Retrieve Kubernetes credentials
tf_directory=~/dev/pass/terraform
project_id=`terraform -chdir=$tf_directory output -raw project_id`
location=`terraform -chdir=$tf_directory output -raw zone`
cluster=`terraform -chdir=$tf_directory output -raw cluster`

gcloud container clusters get-credentials $cluster --project=$project_id --location=$location
```

# Scenario 2: Restopr

1. Let's deploy a previous version of the app

```sh 
cd ~/dev/pass-demo

# Create PR branch
git checkout tags/v99 -b pr-v99

# Push new branch
git push --set-upstream origin pr-v99
```

2. While that is deploying, we were also give a backup of the database that we have to use

   * [Bucket](https://console.cloud.google.com/storage/browser/pass-tomcat-9920)
   * [Build](https://console.cloud.google.com/cloud-build/builds?project=pass-tomcat-9920)

3. Let's restore that backup directly from GCS

```sh
tf_directory=~/dev/pass/terraform
project_id=`terraform -chdir=$tf_directory output -raw project_id`

# This should live in Secret Manager instead of course!
sa_password=`kubectl get secret mssql --namespace pr-v99 -o jsonpath='{.data.MSSQL_SA_PASSWORD}' | base64 --decode`
bucket_secret=`gcloud secrets versions access latest --secret=pass-bucket-creds --project=$project_id`

# Construct creds and restore the database
read -r -d '' query <<- EOS
   CREATE CREDENTIAL [pass]
   WITH
      IDENTITY = 'S3 Access Key',
      SECRET = '$bucket_secret'
   ;

   ALTER DATABASE [ContosoUniversity] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   DROP DATABASE IF EXISTS [ContosoUniversity];

   RESTORE DATABASE [ContosoUniversity]
   FROM
      URL = 's3://storage.googleapis.com/$project_id/classof99.bak'
   WITH
      CREDENTIAL = 'pass'
EOS

kubectl exec database-0 --namespace pr-v99 -- /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "$sa_password" -q "$query"
```

5. Show the site with the new database

```sh
ip=`kubectl get services/app --namespace pr-v99 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
echo "http://$ip/"
```
