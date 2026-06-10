SELECT 'ALTER DATABASE tempdb MODIFY FILE (NAME = [' + f.name + '],'
    + ' FILENAME = ''T:\TempDB\' + f.name
    + CASE WHEN f.type = 1 THEN '.ldf' ELSE '.mdf' END
    + ''');'
FROM sys.master_files f
WHERE f.database_id = DB_ID(N'tempdb');


ALTER DATABASE tempdb MODIFY FILE (NAME = [tempdev], FILENAME = 'T:\TempDB\tempdev.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [templog], FILENAME = 'T:\TempDB\templog.ldf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp2], FILENAME = 'T:\TempDB\temp2.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp3], FILENAME = 'T:\TempDB\temp3.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp4], FILENAME = 'T:\TempDB\temp4.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp5], FILENAME = 'T:\TempDB\temp5.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp6], FILENAME = 'T:\TempDB\temp6.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp7], FILENAME = 'T:\TempDB\temp7.mdf');
ALTER DATABASE tempdb MODIFY FILE (NAME = [temp8], FILENAME = 'T:\TempDB\temp8.mdf');

RESTORE DATABASE [demo_restore]
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
    MOVE 'demo4' TO 'T:\demo_restore.mdf',
    MOVE 'demo4_log' TO 'T:\demo_restore.ldf',
    STATS = 1,
	--MAXTRANSFERSIZE = 10485760,
	--MAXTRANSFERSIZE = 10485760,
	--MAXTRANSFERSIZE = 20971520,
	--MAXTRANSFERSIZE = 5242880,
	MAXTRANSFERSIZE = 1048576,
	--MAXTRANSFERSIZE = 524288,
	--MAXTRANSFERSIZE = 262144,
	--BUFFERCOUNT = 128,
	--BUFFERCOUNT = 512,  -- 1884.261 MB/sec @ MTS = 10 MiB
	--BUFFERCOUNT = 1024, -- 1921.324 MB/sec @ MTS = 10 MiB
	--BUFFERCOUNT = 1024, -- 1830.561 MB/sec @ MTS = 5 MiB
	--BUFFERCOUNT = 2048, -- 1861.942 MB/sec @ MTS = 5 MiB
	--BUFFERCOUNT = 2048, -- 2087.646 MB/sec @ MTS = 20 MiB
	--BUFFERCOUNT = 2048, -- 1970.125 MB/sec @ MTS = 1 MiB
	--BUFFERCOUNT = 4096, -- 2696.221 MB/sec @ MTS = 1 MiB
	--BUFFERCOUNT = 4096, -- 2762.078 MB/sec @ MTS = 512 KiB
	--BUFFERCOUNT = 4096, -- 2202.817 MB/sec @ MTS = 256 KiB
	--BUFFERCOUNT = 8192, -- 2955.528 MB/sec @ MTS = 512 KiB
	BUFFERCOUNT = 8192, -- 2484.239 MB/sec @ MTS = 1 MiB
    RECOVERY,
    REPLACE;
GO