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

    for($i = 0; $i -lt 2; $i++)
    {
        File "HammerdbConfiguration${i}"
        {
            DestinationPath = "C:\tools\pass_run_$i.tcl"
            Contents = @"
#!/bin/tclsh

set tmpdir `$::env(TMP)
puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_azure false
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true
diset connection mssqls_authentication windows
diset connection mssqls_server {sql-0}

diset tpcc mssqls_dbase demo4_${i}
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 60
diset tpcc mssqls_checkpoint true
diset tpcc mssqls_timeprofile false
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu 400
vuset delay 100
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open `$tmpdir/demo4_${i} w ]
puts `$of `$jobid
close `$of
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
}
