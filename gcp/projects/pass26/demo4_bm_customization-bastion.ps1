configuration Customization
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        xPSDesiredStateConfiguration;

    # Reference: https://github.com/GoogleCloudPlatform/PerfKitBenchmarker/blob/master/perfkitbenchmarker/data/hammerdbcli_tcl/hammerdb_sqlserver_tpc_c_run.tcl
    $i = 0;
    File "HammerdbConfiguration${i}"
    {
        DestinationPath = "C:\tools\pass_run_$i.tcl"
        Contents = @"
#!/bin/tclsh

proc wait_to_complete { seconds } {
set x 0
set timerstop 0
while {!`$timerstop} {
incr x
after 1000
if { ![ expr {`$x % 60} ] } {
set y [ expr `$x / 60 ]
puts "Timer: `$y minutes elapsed"
}
update
if {  [ vucomplete ] || `$x eq `$seconds } { set timerstop 1 }
}
return
}

puts "SETTING CONFIGURATION"

vudestroy
dbset db mssqls
diset connection mssqls_azure false
diset connection mssqls_server {sql-0}
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_checkpoint true
diset connection mssqls_authentication windows
diset connection mssqls_trust_server_cert true

diset tpcc mssqls_count_ware 3000
diset tpcc mssqls_num_vu 704
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_dbase demo4_${i}
diset tpcc mssqls_driver timed
diset tpcc mssqls_rampup 5
diset tpcc mssqls_duration 10

vuset logtotemp 1

puts "Loading script"
loadscript

puts "TEST SEQUENCE STARTED"
vudestroy
puts "704 VU TEST"
vuset vu 704
vucreate
vurun

wait_to_complete 1500
vudestroy

puts "TEST SEQUENCE COMPLETE"
"@
    }

    File "HammerdbRunner${i}"
    {
        DestinationPath = "C:\tools\pass_run_$i.ps1"
        Contents = @"
`$pathTools = "C:\tools";
`$pathHammerdb = Join-Path -Path `$pathTools -ChildPath "hammerdb\HammerDB-5.0";
Set-Location -Path `$pathHammerdb;

# Start run
.\hammerdbcli auto `$pathTools/pass_run_${i}.tcl
"@
    }
}
