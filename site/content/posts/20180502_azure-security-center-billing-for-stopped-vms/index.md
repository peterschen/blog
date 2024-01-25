---
title: Azure Security Center cost for stopped VMs
author: Christoph Petersen
url: /azure-security-center-billing-for-stopped-vms
date: 2018-05-02T12:38:21.000Z
tags: [azure, security-center, pricing]
---

An interesting question came up in a conversation today: How are the costs for Azure Security Center Standard pricing tier calculated for nodes that are stopped?

It is pretty easy: Azure Security Center Standard pricing tier is prorated daily so that only the days where a particular VM was online are counted towards the monthly price.
