---
title: Application Insights Connector deprecation
url: /application-insights-connector-deprecation
date: 2018-08-22T06:34:01.000Z
tags: [azure, application-insights, log-analytics]
---

In a time before [cross-resource queries were possible](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-cross-workspace-search) the Application Insights Connector would copy data from Application Insights to a Log Analytics workspace. With the emergence of [cross-resource queries](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-cross-workspace-search) the duplication of data is not required anymore as queries can be sent to both (or even more) entities at the same time in real time.

The connector will be disabled in November 2018 but will continue to function until then. You will not be able to link new Application Insights resources to a Log Analytics workspace going forward.

## More information

[Read the note on the Application Insights connector documentation site.](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-app-insights-connector)
