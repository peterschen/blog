# Zero to Cuttlefish Virtual Device in a day

## XXXXX

## Overview

In the hackathon that uses this lab, participants will work in groups to run Cuttlefish Virtual Devices natively on Axion-based bare-metal instances running in Google Cloud. This lab provides the environment to deploy the necessary resources.

### Objectives

In this lab, you will do the following:

* Deploy Axion-based bare-metal instances
* Install Cuttlefish software components
* Create and deploy Cuttlefish Virtual Devices

## Setup and requirements

![[/fragments/startqwiklab]]

![[/fragments/gcpconsole]]

![[/fragments/gcpcloudshell]]

## Part 1: Deploy the infrastructure

### Create VPC and subnet

1. Create a VPC network `cuttlefish`
2. Create a subnet `cuttlefish` in the `<ql-variable key="project_1.default_zone" placeHolder="<filled in at lab start>"></ql-variable>` zone

## Part 2: Deploy Axion-based bare-metal instances

1. List available Axion-based bare-metal instance types

<ql-infobox>
<strong>Hint:</strong> Use `gcloud compute instance-types list` to list available instance types in the `<ql-variable key="project_1.default_zone" placeHolder="<filled in at lab start>"></ql-variable>` zone
</ql-infobox>

2. Deploy a new instance called `cuttlefish-0` in the `<ql-variable key="project_1.default_zone" placeHolder="<filled in at lab start>"></ql-variable>` zone

<ql-infobox>
<strong>Note:</strong> Make sure to deploy a bare-metal machine type!
</ql-infobox>

## Congratulations!

Great job! You have successfully deployed Cuttlefish Virtual Devices on Google Cloud.

![[/fragments/endqwiklab]]

![[/fragments/copyright]]