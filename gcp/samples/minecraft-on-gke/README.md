# Minecraft on GKE #
This sample shows how to provision GKE through Terraform and run a simple container on it. Minecraft might not be the perfect example as it does not support hotizontal scaling or shared state but it is fun nonetheless.

## Enable Kubernetes Engine API ##
If you haven't used the Kubernetes Engine API in the project you are working in yet, you need to enable it before the template will work.

In the burger menu select _APIs & Services > Library_. Search for _Kubernetes Engine API_ select it from the list and click _Enable API_.

## Run Terraform ##
The Terraform template will deploy a single-node GKE cluster and deploy a replication controller based Minecraft server that is accessible through a load balancer. Data is persisted to a Persistent Disk through a persistent volume claim managed by Kubernetes.

To get started issue the following commands:
```
terraform validate
terraform apply
```