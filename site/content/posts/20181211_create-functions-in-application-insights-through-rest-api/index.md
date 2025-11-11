---
title: Create functions in Application Insights through REST API
url: /create-functions-in-application-insights-through-rest-api
date: 2018-12-11T12:03:53.000Z
tags: [azure, application-insights, querymagic]
---

I've learned about a "hidden feature" recently that enables some cool scenarios. Log Analytics or Azure Data Explorer aficionados will probably know all about functions already but for Application Insights this has not been documented yet and is not visible through the Azure portal.

## List all functions

```
GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Insights/components/{applicationName}/analyticsItems?api-version=2015-05-01&includeContent=true&scope=shared&type=function
```

## Create or update function

```
PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Insights/components/{applicationName}/analyticsItems/item?api-version=2015-05-01
```

### Request Body

| Name | Required | Type | Description |
| ---- | -------- | ---- | ----------- |
| scope | true | string | |
| type | true | string | |
| name | true | string | Name of the function. Function name must begin with a letter and contain only letters, numbers and underscores. | 
| content | true | string | Query that is executed when the function is calledpropertiestrueobjectFunction properties (e.g. alias) |

### Sample

Request

```
PUT https://management.azure.com/subscriptions/my-subscription-id/resourceGroups/my-resource-group/providers/Microsoft.Insights/components/my-application/analyticsItems/item?api-version=2015-05-01
```

Request body

```json
{
    "scope": "shared",
    "type": "function",
    "name": "myfunction",
    "content": "traces | count",
    "properties": {
        "functionAlias": "myfunction"
    }
}
```

## Delete function

```
DELETE https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Insights/components/{applicationName}/analyticsItems/item?api-version=2015-05-01&includeContent=true&scope=shared&type=function&name={functionName}
```

### Sample

Request

```
DELETE https://management.azure.com/subscriptions/my-subscription-id/resourceGroups/my-resource-group/providers/Microsoft.Insights/components/my-application/analyticsItems/item?api-version=2015-05-01&includeContent=true&scope=shared&type=function&name=myfunction
```
