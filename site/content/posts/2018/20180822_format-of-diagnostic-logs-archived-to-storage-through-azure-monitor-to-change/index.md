---
title: Format of logs archived to storage through Azure Monitor to change
author: christoph
url: /format-of-diagnostic-logs-archived-to-storage-through-azure-monitor-to-change
date: 2018-08-22T06:20:21.000Z
tags: [azure, monitor, breaking-change, storage]
cover: images/azure-monitor.png
---

If you are archiving [diagnostic logs](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitoring-archive-diagnostic-logs) or [activity logs](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitoring-archive-activity-log) to a storage account through Azure Monitor be aware that on Nov 1, 2018 there will be a breaking change in the format.

The current format of the `PT1H.json` file in the storage account uses a JSON array or records. This looks something like:

```json
{
    "records": [
        {
            "time": "2016-01-05T01:32:01.2691226Z"
        },
        {
            "time": "2016-01-05T01:33:56.5264523Z"
        }
    ]
}
```

The blob format will be change to JSON lines. This means each record will be delimited by a newline, with no outer records array and no commas between JSON records:

```json
{"time": "2016-01-05T01:32:01.2691226Z"}
{"time": "2016-01-05T01:33:56.5264523Z"}
```

## More information

[Please review the documentation on how to find out if you are affected by this change and how to mitigate.](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitor-diagnostic-logs-append-blobs)
