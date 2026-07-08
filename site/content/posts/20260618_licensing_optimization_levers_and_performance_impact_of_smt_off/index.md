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
| Custom visible cores         | 2, 4, 8, 16, 32   |
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

| Machine type  | Visible cores | Threads per core | vCPUs | Run | TPM       | NOPM      |
| ------------- | ------------- | ---------------- | ----- | --- | --------- | --------- |
| c4-highcpu-96 | 16            | 1                | 16    | 0   | 2,111,119 | 909,360   |
| c4-highcpu-96 | 16            | 1                | 16    | 1   | 2,168,381 | 933,275   |
| c4-highcpu-96 | 16            | 1                | 16    | 2   | 2,090,277 | 899,555   |
| c4-highcpu-96 | 16            | 1                | 16    | 3   | 2,172,448 | 934,396   |
| c4-highcpu-96 | 16            | 1                | 16    | 4   | 2,208,581 | 950,864   |
| c4-highcpu-96 | 16            | 1                | 16    | 5   | 2,188,570 | 943,380   |
| c4-highcpu-96 | 16            | 2                | 32    | 0   | 2,846,514 | 1,225,739 |
| c4-highcpu-96 | 16            | 2                | 32    | 1   | 2,743,198 | 1,180,725 |
| c4-highcpu-96 | 16            | 2                | 32    | 2   | 2,925,566 | 1,259,347 |
| c4-highcpu-96 | 16            | 2                | 32    | 3   | 2,901,705 | 1,249,088 |
| c4-highcpu-96 | 16            | 2                | 32    | 4   | 3,044,777 | 1,310,268 |
| c4-highcpu-96 | 16            | 2                | 32    | 5   | 3,139,450 | 1,351,805 |
| c4-highcpu-96 | 32            | 1                | 32    | 0   | 3,709,684 | 1,596,722 |
| c4-highcpu-96 | 32            | 1                | 32    | 1   | 3,661,909 | 1,576,963 |
| c4-highcpu-96 | 32            | 1                | 32    | 2   | 3,742,238 | 1,610,888 |
| c4-highcpu-96 | 32            | 1                | 32    | 3   | 3,771,601 | 1,623,869 |
| c4-highcpu-96 | 32            | 1                | 32    | 4   | 3,721,839 | 1,601,842 |
| c4-highcpu-96 | 32            | 1                | 32    | 5   | 3,690,345 | 1,588,337 |
| c4-highcpu-96 | 32            | 2                | 64    | 0   | 4,739,187 | 2,040,310 |
| c4-highcpu-96 | 32            | 2                | 64    | 1   | 4,865,799 | 2,095,042 |
| c4-highcpu-96 | 32            | 2                | 64    | 2   | 4,978,081 | 2,142,613 |
| c4-highcpu-96 | 32            | 2                | 64    | 3   | 4,845,775 | 2,085,709 |
| c4-highcpu-96 | 32            | 2                | 64    | 4   | 5,213,186 | 2,243,852 |
| c4-highcpu-96 | 32            | 2                | 64    | 5   | 5,188,773 | 2,233,186 |

To better understand the benchmark results, I've focused on the transactions per minute (TPM) metric and calculated both the arithmetric mean (average) and geometric mean (geomean) to provide addiional context regarding outliers. Additionally, I've calculated the standard deviation.

| Visible cores | Threads per core | vCPUs | TPM avg   | TPM geomean | TPM stddev |
| ------------- | ---------------- | ----- | --------- | ----------- | ---------- |
| 2             | 2                | 4     | 1,225,709 | 1,222,624   | 93,383     |
| 2             | 1                | 2     | 1,132,882 | 1,100,761   | 261,076    |
| 4             | 2                | 8     | 1,424,082 | 1,423,280   | 53,173     |
| 4             | 1                | 4     | 1,275,760 | 1,274,014   | 73,906     |
| 8             | 2                | 16    | 1,661,053 | 1,659,160   | 85,400     |
| 8             | 1                | 8     | 1,474,558 | 1,467,526   | 151,091    |
| 16            | 2                | 32    | 2,933,535 | 2,930,716   | 141,176    |
| 16            | 1                | 16    | 2,156,563 | 2,156,151   | 46,003     |
| 32            | 2                | 64    | 4,971,800 | 4,968,689   | 193,190    |
| 32            | 1                | 32    | 3,716,269 | 3,716,103   | 38,568     |

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