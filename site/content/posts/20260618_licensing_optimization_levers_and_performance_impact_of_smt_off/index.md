---
title: Licensing optimization levers and performance impact of SMT-off
url: /licensing_optimization_levers_and_performance_impact_of_smt_off
date: 2026-06-18 14:00:00+02:00
tags: ["gcp", "gce", "windows", "licensing", "hyperthreading", "smt", "smt-off", "custom visble cores"]
draft: true
---

The total cost of ownership (TCO) plays a significant role for customers deploying their workloads to the cloud. The cost of licensing can have a significant impact on the TCO. To better understand *how much* impact licensing can have look at the following chart:

{{< figure 
    src="images/relative_cost_of_infrastructure_and_licensing.svg"
    alt="Relative cost of infrastructure and licensing"
    caption="Graph showing relative cost of infrastructure and Windows Server licensing for N4 and C4 VMs priced with 3 years Commited Use Discounts in europe-west4" >}}

For long running workloads, licensing amounts to more than 2/3 of the total cost of ownership of a single VM. The chart only shows Windows Server licensing cost and in reality the imbalance can be even greater when running additional licensed workloads such as SQL Server.

The rest of this article is focused on using technical means to reduce the imbalance between infrastructure and licensing cost and showing the performance impact of turning off Hyperthreading.

## Optimization levers

Google Cloud offers two optmization levers that can help optmize the licensing requirements:

* Customize the number of visible CPU cores ("Custom visible cores") and
* Set the number of threads per core ("SMT-off")

Both these features can be applied at the VM-level. Most machine families support these levers except for machine families that are powered by an Arm CPU or have Hyperthreading disabled.

Both of these features will reduce the number of visible and *thus licensable cores/vCPUs* in the guest while retaining the original hardware configuration (memory, storage and networking limits) for the selected instance type. From a cost perspective the originally selected instance type will be charged.

### Custom visible cores

Using custom visible cores the number of pyhsical cores used to schedule the VM can be reduced. The step size is dependent on the number of vNUMA nodes for the machine type but generally a product of 2. There are a few interesting scenarios for which this feature can be used:

* Exposing only a defined set of cores for licensing requirements
* Creating instance with *very high* memory to vCPU ratios

The latter can also help to prevent scenarios that would generally require extended memory which is not eligible for resource-based CUDs helping to provide a cheaper infrastructure option.

Custom visible cores reduces the physical cores to which the instance is scheduled. This has performance impact as less physical cores are available for the instance. It can be combined with SMT-off.

### SMT-off

SMT-off disables Hyperthreading for the VM resulting in the instance only being scheduled on physical cores (the number of which can be controlled with custom visible cores discussed previously). 

While public data [claims that Hyperthreading can provide up to 30% additional performance](https://en.wikipedia.org/wiki/Hyper-threading#Performance_claims) it is highly dependent on the workload. To provide better context I've performed benchmarking that is covered in the remainder of this article. 

## Performance

Performance is the key aspect. While reducing the visible cores reduces the licensing cost, will it also affect the workload performance? Most will say: "Of course, you're removing vCPUs!". To better understand the actual performance impact of reducing visible vCPUs, specifically turning off Hyperthreading ("SMT-off"), I ran a suite of tests using HammerDB against a SQL Server configured with and without SMT-off.

### Benchmarking setup

A lot of factors can influence benchmarking results. To isolate the effect of configuring the threads per core on the performance, I have opted to use the same machine type and only reduce the visible cores. This retains the same memory configuration and same performance characteristics for storage and networking. Hyperdisk Extreme configured at the maximum for the selected instance type was used to ensure storage (IO/throughput) is not the limiting factor.

In summary the following configuration was used:

|                              |                   |
| ---------------------------- | ----------------- |
| Instance type                | c4-highcpu-96     |
| Custom visible cores         | 4                 |
| Block storage                | Hyperdisk Extreme |
| Block storage: IOPS          | 350,000           |
| Block storage: Throughput    | 5,000 MiB/s       |
| SQL Server: Memory           | 150 GiB           |
| SQL Server: MAXDOP           | 8                 |
| HammerDB: Warehouses         | 3,000             |
| HammerDB: Virtual users      | 704               |
| HammerDB: Use all warehouses | true              |
| HammerDB: Warmup time        | 3 minutes         |
| HammerDB: Run time           | 10 minutes        |

### Results

For both configurations (Threads per core set to 1 and set to 2) HammerDB was run five times to record standard deviation yielding these results:

| Machine type  | Visible cores | Threads per core | vCPUs | Run | TPM       | NOPM    |
| ------------- | ------------- | ---------------- | ----- | --- | --------- | ------- |
| c4-highcpu-96 | 4             | 2                | 8     | 1   | 1,269,679 | 472,694 |
| c4-highcpu-96 | 4             | 2                | 8     | 2   | 1,379,353 | 611,472 |
| c4-highcpu-96 | 4             | 2                | 8     | 3   | 1,313,991 | 578,086 |
| c4-highcpu-96 | 4             | 2                | 8     | 4   | 1,323,344 | 577,071 |
| c4-highcpu-96 | 4             | 2                | 8     | 5   | 1,176,724 | 518,341 |
| c4-highcpu-96 | 4             | 1                | 4     | 1   | 1,211,578 | 492,306 |
| c4-highcpu-96 | 4             | 1                | 4     | 2   | 1,232,441 | 520,195 |
| c4-highcpu-96 | 4             | 1                | 4     | 3   | 1,323,252 | 570,840 |
| c4-highcpu-96 | 4             | 1                | 4     | 4   | 1,276,258 | 568,622 |
| c4-highcpu-96 | 4             | 1                | 4     | 5   | 1,322,779 | 511,448 |

To better understand the benchmark results, I've focused on the transactions per minute (TPM) metric and calculated both the arithmetric mean (average) and geometric mean (geomean) to provide addiional context regarding outliers. Additionally, I've calculated the standard deviation.

| Visible cores | Threads per core | vCPUs | TPM avg   | TPM geomean | TPM stddev |
| ------------- | ---------------- | ----- | --------- | ----------- | ---------- |
| 4             | 2                | 8     | 1,292,618 | 1,290,809   | 75,633     |
| 4             | 1                | 4     | 1,273,262 | 1,272,440   | 51,067     |

Based on these results I have plotted the absolute performance in TPM and the relative performance difference between the VM with Hyperthreading enabled and disabled:

{{< figure 
    src="images/tpm_and_performance_delta.svg"
    alt="TPM and performance delta (SMT-on/SMT-off)"
    caption="Graph showing the absolute transactions per minute (TPM) for HammerDB and the relative performance delta" >}}

## Summary and recommendation

The results are indicative that there is almost no measureable performance impact for SQL Server workloads. SQL Server is a highly optimized workloads employing its own scheduling techniques and the milage may vary for other workloads. Yet the data shows that for a neglible performance impact the licensing cost was reduced by 50% (comparing 4 vCPUs to 8 vCPUs).

These are my recommendations based on these results:

* Start with SMT-off for workloads with vCPU-bound licensing
* Benchmark performance for your workload