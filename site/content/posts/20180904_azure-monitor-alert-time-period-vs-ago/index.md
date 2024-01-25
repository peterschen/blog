---
title: Azure Monitor alert time period vs. ago()
author: Christoph Petersen
url: /azure-monitor-alert-time-period-vs-ago
date: 2018-09-04T07:32:45.000Z
tags: [azure, alerts, monitor, log-analytics]
cover: 
  image: images/2018-09-04-09_31_39-.png
---

Every once in a while you might need to create an alert which runs a Log Analytics or Application Insights query. When designing the alert you need to define some attributes: the query, the time period, the frequency and the threshold.

This article focuses on a not well know fact that time ranges given in the query and the time period are not synonym and have strong implications on the alert logic and/or false-positives (or false-negatives).

## TL;DR

If you're in a hurry and don't care about the technical details, scroll down to the recommendation.

## Context

Before embarking on the technical details, some context. To understand the differences between the time period and limits in the query, one need to understand the ingestion of data into Log Analytics.

Ingestion is a process where the backend reads data from different sources (and through different means). Imagine multiple threads running in parallel and working on data. This means that ingestion is not guaranteed to be in order. Other reasons might be intermittent loss of connectivity or other issues with the data sources itself. Long story short a packet with the timestamp `2018-09-03T11:52:00` may arrive before a package `2018-09-03T11:47:00` .

## Query

Within a Log Analytics query (regardless of running it against Log Analytics or Application Insights) you can do among many other limit the time frame of which data to look at and specify this with the `ago()` function and one field of the data set.

Take a look at the following query:

```
Heartbeat
| where TimeGenerated >= ago(5m)
```

Which would give me *ingested* records that are not older than 5 minutes. Records that would fit that query but are not ingested yet are not matched and this might lead to a false-positive.

## Time period

When specifying an alert you need to also define the time period. This is a platform level instruction and defines which data is available for querying. So if time period is set for 15 minutes, your alert query would be executed with data available for the last 15 minutes only. This works along with `ago()` in the alert query; so for example – if the alert query uses `ago(1d)` and time period is set for 60 minutes. Then the query with `ago(1d)` is run by Azure alerts, as if data exists only for last 60 minutes and the rest of the 23 hours there was no data.

## Recommendation

To prevent false-positives and make the alert as robust as possible it is generally recommended to select a wider time period and use the `ago()` function to get the alert semantics you need (e.g. number of requests in the last 5 minutes). [More information can be found in the Azure documentation on Alerts.](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitor-alerts-unified-log#log-search-alert-rule---definition-and-types)
