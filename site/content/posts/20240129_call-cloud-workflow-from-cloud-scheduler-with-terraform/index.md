---
author: christoph
title: Call Cloud Workflow from Cloud Scheduler with Terraform
url: /call-cloud-workflow-from-cloud-scheduler-with-terraform
date: 2024-01-29 17:24:00+02:00
tags: 
  - cloud-scheduler
  - cloud-workflows
  - terraform
category: cloud-scheduler
---

[Cloud Workflows](https://cloud.google.com/workflows/docs) provide an easy way for platform automation and integration without the need to write any code. It also integrates seamlessly with Event Arc and other platform components.

Sometimes you may want to run a workflow on a schedule though and Cloud Scheduler can serve as the executiong trigger. When configured through the Cloud Console this is fairly straight forward and the necessary configuration steps required to call the workflow execution endpoint are abstracted away:

![Configuring a Cloud Scheduler job in Cloud Console](images/Screenshot%202024-01-29%2016.36.58.png)

If you want to configure the same through Terraform some of these configuration steps that are automatic in Cloud Console need to be added to the resource configuration.

## Workflow definition

First we need to define our workflow in Terraform. This can look something like this:

```terraform
resource "google_workflows_workflow" "blog" {
  region = "europe-west4"
  name = "workflow"
  service_account = "snapshot-automation@polite-flounder-5366.iam.gserviceaccount.com"
  source_contents = file("workflow.yaml")
}
```

## Constructing the `google_workflows_workflow` resource

This is what the resource will look like:

```terraform
resource "google_cloud_scheduler_job" "blog" {
  name = "trigger_workflow"
  schedule = "0 0,12 * * *"

  http_target {
    uri = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.snapshot_release.id}/executions"
    http_method = "POST"
    headers = {
      "Content-Type" = "application/octet-stream"
      "User-Agent" = "Google-Cloud-Scheduler"
    }
    body = base64encode(<<-EOM
        {
          "argument": "{}",
          "callLogLevel": "LOG_ALL_CALLS"
        }
      EOM
    )
    oauth_token {
      scope = "https://www.googleapis.com/auth/cloud-platform"
      service_account_email = service_account = "snapshot-automation@polite-flounder-5366.iam.gserviceaccount.com"
    }
  }
}
```
Let's take a closer look how to put these together.

### Uri

The workflow will be triggered through HTTP so we need to construct the right endpoint:

`https://workflowexecutions.googleapis.com/v1/<WORKFLOW RESOURCE ID>/executions`

For our example above this will look like this:

`https://workflowexecutions.googleapis.com/v1/projects/polite-flounder-5366/locations/europe-west4/workflows/snapshot-release/executions`

### HTTP method & body

The request should be submitted as `POST`. In the body we can pass data and configure how the execution of the workflow should be logged. The body needs to be base64 encoded:

```json
{
    "argument": "{}",
    "callLogLevel": "LOG_ALL_CALLS"
}
```

If you want to pass data to the workflow, these can be included in the `argument` attribute. 

> **Note:** The JSON needs to be escaped and enclosed with quotes as otherwise the call will fail with an `INVALID_ARGUMENT` exception.

The `callLogLevel` attribute can be omitted or take [one of these values](https://cloud.google.com/workflows/docs/reference/rest/v1/projects.locations.workflows#callloglevel):

* LOG_ALL_CALLS: Detailed logging of every step in the worklow
* LOG_ERRORS_ONLY: Error logging only
* LOG_NONE: No logging

### Headers & OAuth configuration

The headers listed in the configuration above are introduced when configuring the Cloud Scheduler job using Cloud Console. I haven't tested removing them. 

The OAuth Configuration is imporant. Workflows require an authentication call and this configuration is used to construct that call. The service account that is being used need to have the `roles/workflows.invoker` role assigned.
