---
title: Management groups vanishing from Azure portal after rename
author: christoph
url: /management-groups-vanishing-from-azure-portal-afer-rename
date: 2019-06-28T18:58:05.000Z
tags: [azure, management-groups, bug]
cover: images/Screen-Shot-2019-06-28-at-20.57.05.png
---

If you use Management groups to manage Azure at scale you may get hit with a bug in the Azure portal, that I discovered today. If you rename the `Root Tenant Group` the portal stops showing any previously create management groups. Their assignment are still active and you can still manage them using PowerShell or CLI but the portal will start show the out-of-the-box experience.

To fix this, you can simply rename the management group back to the default name:

 `az account management-group update --name <GUID> --display-name "Root Tenant Group"`

The Azure portal team is working on a fix.
