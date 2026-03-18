export ORG_DOMAIN="cbpetersen.altostrat.com"
export PROJECT=cuddly-raven-8114

gcloud config set project $PROJECT
gcloud services enable cloudaicompanion.googleapis.com

gcloud identity groups create cbp-codeassist@${ORG_DOMAIN} \
    --organization="${ORG_DOMAIN}" \
    --group-type="security" \
    --display-name="cbp-codeassist" \
    --description="Principals with access Code Assist"

gcloud identity groups memberships add \
    --group-email="cbp-codeassist@${ORG_DOMAIN}" \
    --member-email="christoph@cbpetersen.altostrat.com"

gcloud projects add-iam-policy-binding $PROJECT \
    --member="group:cbp-codeassist@${ORG_DOMAIN}" \
    --role=roles/cloudaicompanion.user

gcloud projects add-iam-policy-binding $PROJECT \
    --member="group:cbp-codeassist@${ORG_DOMAIN}" \
    --role=roles/serviceusage.serviceUsageConsumer
