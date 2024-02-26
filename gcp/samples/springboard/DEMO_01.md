# Prep

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

tfdir=../../samples/springboard-host
input_file="/tmp/ts24-host-$PROJECT_SUFFIX.tfvars"

envsubst < ../../samples/springboard-host/ts24.template.tfvars > $input_file

terraform -chdir=$tfdir apply \
    -var enable_peering=false \
    -var-file=$input_file \
    -auto-approve -refresh=false
```

# Setting the scene

1. Kick off deployment

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

tfdir=../../samples/infra-manager
project_id=`terraform -chdir=$tfdir output -raw project_id`
sa_id=`terraform -chdir=$tfdir output -raw sa_id`
location="europe-west1"
tier="tier1"
input_file="/tmp/ts24-springboard-$PROJECT_SUFFIX.tfvars"

envsubst < ts24.template.tfvars > $input_file

gcloud infra-manager deployments apply springboard-$tier \
    --project=$project_id \
    --location=$location \
    --service-account=$sa_id \
    --git-source-repo=https://github.com/peterschen/blog \
    --git-source-directory=gcp/projects/springboard/terraform/springboard_$tier \
    --git-source-ref=master \
    --inputs-file=$input_file
```
2. Show host project
    * [VPC network](https://console.cloud.google.com/networking/networks/list?project=ts24-host-20240228)

# Deploy Springboard

1. Show springboard code hosted on [GitHub](https://github.com/peterschen/blog/tree/master/gcp/projects/springboard)
2. Explain Infrastructure Manager execution project
    * What does it have?
        * Service account
        * Required APIs (Infra Manager, Cloud Build, Resource Manager, Billing)
        * Nothing else
    * Any project correctly prepped can be used with Infra Manager
3. Review [Cloud Build execution](https://console.cloud.google.com/cloud-build/builds;region=europe-west1?project=cbpetersen-inframanager)

# Get to know Springboard

1. Explore [project](https://console.cloud.google.com/home/dashboard?project=ts24-springboard-20240221)
    * Infra Manager stood up a new project
    * Billing Account [attached](https://console.cloud.google.com/billing/linkedaccount?project=ts24-springboard-20240228)
    * Review [org policies](https://console.cloud.google.com/iam-admin/orgpolicies/list?project=ts24-springboard-20240228&pageState=(%22OrgPoliciesTable%22:(%22f%22:%22%255B%257B_22k_22_3A_22Inheritance_22_2C_22t_22_3A10_2C_22v_22_3A_22_5C_22Custom_~*Custom_5C_22_22_2C_22s_22_3Atrue_2C_22i_22_3A_22policyDetails.inheritance_22%257D%255D%22)))
    * Review [OS polcies](https://console.cloud.google.com/compute/config/assignments?project=ts24-springboard-20240228)
    * Review [VPC](https://console.cloud.google.com/networking/networks/list?project=ts24-springboard-20240228)
    * Review [peering](https://console.cloud.google.com/networking/peering/list?project=ts24-springboard-20240228)
    * Review network [firewall policies](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list?project=ts24-springboard-20240228)
    * Review secure network tag based [IAP ingress policy](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/networkPolicies/details/iap-ingress?project=ts24-springboard-20240228)

# Connect to the outside world

1. While we wait for Springboard to be fully deployed, let's set up connectivity

```sh
export PROJECT_SUFFIX=`date +"%Y%m%d"`

tfdir=../../samples/springboard-host
input_file="/tmp/ts24-host-$PROJECT_SUFFIX.tfvars"

envsubst < ../../samples/springboard-host/ts24.template.tfvars > $input_file

terraform -chdir=$tfdir apply \
    -var enable_peering=true \
    -var-file=$input_file \
    -auto-approve -refresh=false
```

2. Review VPC peering in [host project](https://console.cloud.google.com/networking/peering/list?project=ts24-host-20240228)