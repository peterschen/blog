---
title: Cross Subscription Workspace Selection for Azure Security Center
author: christoph
url: /cross-subscription-workspace-selection-for-azure-security-center
date: 2018-04-26T07:53:47.000Z
tags: [azure, security-center, log-analytics]
---

Around Ignite 2017 Azure Security Center was migrated to use Log Analytics as its foundation both for collecting data through the same agent and storing most of its data.

Since then the option was added to select into which Log Analytics workspace the data would be save (no longer it had to be `DefaultWorkspace` !).

No Microsoft added the option to select workspaces that are located in different subscriptions:

![cross-subscription-workspace-access](images/cross-subscription-workspace-access.png)

If you want to store your data in a workspace that is not in the same subscription, make sure you have the global subscription filter set correctly (otherwise resources from other subscriptions simply won't show up):

![asc-select-subscriptions](images/asc-select-subscriptions.png)
