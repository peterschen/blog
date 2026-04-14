# Prep
```sh
tf_directory=~/dev/pass/terraform

# Apply Terraform
terraform -chdir=$tf_directory apply -auto-approve

# Retrieve Kubernetes credentials
project_id=`terraform -chdir=$tf_directory output -raw project_id`
location=`terraform -chdir=$tf_directory output -raw zone`
cluster=`terraform -chdir=$tf_directory output -raw cluster`

gcloud container clusters get-credentials $cluster --project=$project_id --location=$location
```

# Setting the scene
1. Deploy application

```sh
cd ~/dev/pass-demo

# Deploy
kubectl apply -f data/inline.yml
```

2. Explain yaml, highlight:
   * Secret (obviously should not be in plain text in the manifest)
   * Resource limits to properly set the memory for SQL Server (otherwise OOM-killer will come!)
   * Init container to wait for database ready before starting the app
2. Show cluster in Pantheon
   * [Workloads][https://console.cloud.google.com/kubernetes/workload/overview?project=pass-tomcat-9920]
   * [Services & Ingress][https://console.cloud.google.com/kubernetes/discovery?project=pass-tomcat-9920]
2. Open website
   * Mutate records (e.g instructors)
2. Show SSMS

# Scenario 1: Feature branch development

1. You have seen the landing site which is not very nice, so in this sprint we want to improve that

2. Let's stage a few changes
```sh 
cd ~/dev/pass-demo

# Create PR branch
git checkout -b pr-refactor-welcome

# Make changes
cp demo/01-Index.cshtml app/ContosoUniversity/Views/Home/Index.cshtml
```

3. With that out of the way, we can commit them and push to GitLab

```sh
# Commit changes
git add app/ContosoUniversity/Views/Home/Index.cshtml
git commit -m "Refactored welcome page"
git push --set-upstream origin pr-refactor-welcome
```

4. Show code change in GitLab
   * [Branches](https://gitlab.com/google-cloud-ce/googlers/cbpetersen/pass23/-/branches)
   * [Pipelines](https://gitlab.com/google-cloud-ce/googlers/cbpetersen/pass23/-/pipelines)
   * Show build configuration
   * [Build](https://console.cloud.google.com/cloud-build/builds?project=pass-tomcat-9920)
   * [Digests](https://console.cloud.google.com/artifacts/docker/pass-tomcat-9920/europe-west4/pass/contosouniversity)

5. Open page and show changes

```sh
ip=`kubectl get services/app --namespace pr-refactor-welcome -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
echo "http://$ip/"
```

6. Show that the database is actually different than the main branch
   * Show instructors