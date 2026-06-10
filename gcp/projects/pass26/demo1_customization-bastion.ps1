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
    $databases = 1
    for($i = 0; $i -lt $databases + 1; $i++)
    {
        File "SqlScripts${i}"
        {
            DestinationPath = "C:\tools\pass_demo1_${i}.sql"
            Contents = @"
RESTORE DATABASE [demo1_${i}]
FROM
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_01.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_02.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_03.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_04.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_05.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_06.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_07.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_08.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_09.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_10.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_11.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_12.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_13.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_14.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_15.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_16.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_17.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_18.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_19.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_20.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_21.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_22.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_23.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_24.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_25.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_26.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_27.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_28.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_29.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_30.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_31.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_32.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_33.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_34.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_35.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_36.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_37.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_38.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_39.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_40.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_41.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_42.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_43.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_44.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_45.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_46.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_47.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_48.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_49.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_50.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_51.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_52.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_53.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_54.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_55.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_56.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_57.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_58.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_59.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_60.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_61.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_62.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_63.bak',
    URL = 's3://storage.googleapis.com/cbpetersen-demos/pass25/demo4_3000_64.bak'
WITH
    CREDENTIAL = 'cbpetersen-demos',
    MOVE 'demo4' TO 'T:\demo1_${i}.mdf',
    MOVE 'demo4_log' TO 'T:\demo1_${i}.ldf',
    STATS = 1,
	MAXTRANSFERSIZE = 1048576,
	BUFFERCOUNT = 8192,
    RECOVERY,
    REPLACE;
GO
"@
        }
    }
}
