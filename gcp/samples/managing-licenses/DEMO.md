```shell
gcloud compute disks create exchange \
    --project cbpetersen-sandbox \
    --zone europe-west4-a \
    --type hyperdisk-balanced \
    --size 50GB \
    --provisioned-iops 3000 \
    --provisioned-throughput 140 \
    --licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-byol

baseUri="https://compute.googleapis.com/compute/v1/projects"
token=`gcloud auth print-access-token`

project="ubuntu-os-cloud"
curl -s \
  "${baseUri}/${project}/global/licenses" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri

project="ubuntu-os-cloud"
filter=`echo "name=ubuntu-2204-lts" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri

project="ubuntu-os-pro-cloud"
filter=`echo "licenseCode=2592866803419978320 OR licenseCode=6383960536289251289 OR licenseCode=3242930272766215801 OR licenseCode=2176054482269786025" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri

project="windows-cloud"
filter=`echo "name = windows-server-2025*" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri

gcloud compute disks describe exchange \
    --project cbpetersen-sandbox \
    --zone europe-west4-a

gcloud compute disks update exchange \
    --project cbpetersen-sandbox \
    --zone europe-west4-a \
    --append-licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-dc

gcloud compute disks describe exchange \
    --project cbpetersen-sandbox \
    --zone europe-west4-a

gcloud compute disks update exchange \
    --project cbpetersen-sandbox \
    --zone europe-west4-a \
    --remove-licenses https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-dc
```