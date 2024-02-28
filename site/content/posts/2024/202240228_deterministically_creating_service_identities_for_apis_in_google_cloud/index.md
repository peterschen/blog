---
author: christoph
title: Deterministically creating service identities for APIs in Google Cloud
url: /deterministically_creating_service_identities_for_apis_in_google_cloud
date: 2024-02-28 18:00:00+02:00
tags: 
- service-identity
- service-usage
- iam
- service-accounts
cover: images/image.png
---

Platform services in Google Cloud act in the context of a service account. While these default service identities are mostly generated automatically, it is not always deterministic *when* they are created. Some are created when the API is enabled, others will only be created on first use of the API. This makes it hard for managing IAM permissions for these identities - especially when employing infrastructure as code like Terraform.

## Service Usage API to the rescue

Luckily the [Service Usage API](https://cloud.google.com/service-usage/docs) now features a new method (`generateServiceIdentity`) in [v1beta1](https://cloud.google.com/service-usage/docs/reference/rest/v1beta1/services/generateServiceIdentity) that ensures the service identity is being created and will return its identifier (namely the email address of the service account).

The endpoint is already available in [gcloud beta](https://cloud.google.com/sdk/gcloud/reference/beta/services/identity/create) and the following snippit will create the service identity for Cloud Build:

```sh
project="<PROJECT ID>"
service="cloudbuild.googleapis.com"

gcloud beta services identity create \
    --project $project \
    --service $service
```

The [google-beta provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service_identity) for Terraform also makes a resource available for direct use in Terraform:

```terraform
resource "google_project_service_identity" "cloudbuild" {
  provider = google-beta
  project = "<PROJECT ID>"
  service = "cloudbuild.googleapis.com"
}
```
