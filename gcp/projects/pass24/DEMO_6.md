# Demo 6
High performance storage subsystem with up to 500,000 IOPS and 10 GiB/s throughput using Hyperdisk Extreme.

## Prep

* Run HammerDB for at least 60 minutes before the session to saturate log 

## Setting the scene

1. Show disks in Cloud Console
    * [Disks](https://console.cloud.google.com/compute/disks)
1. Show storage configuration on sql-0
    * Storage Pool configuration
    * Disk configuration
1. Show SQL Server configuration
    * Tuned to drive IOPS
1. Show HammerDB
1. Show performance dashboard in Cloud Console
    * [PASS - Disk Performance](https://console.cloud.google.com/monitoring/dashboards)

## Run

```powershell
$pathTools = "C:\tools";
$pathHammerdb = Join-Path -Path $pathTools -ChildPath "hammerdb\HammerDB-4.12";
Set-Location -Path $pathHammerdb;

# Start first run
.\hammerdbcli auto $pathTools/pass_run_1.tcl

# Start second run
.\hammerdbcli auto $pathTools/pass_run_2.tcl
```