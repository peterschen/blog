-- database: ../../../../hammer-c3-standard-88-lssd-t1.db

SELECT 
    main.jobid,
    timestamp,
    users,
    nopm,
    tpm
FROM
    JOBMAIN AS main
LEFT JOIN (
    SELECT
        jobid, substr(output, 0, instr(output, " ")) AS users
    FROM
        JOBOUTPUT
    WHERE
        output LIKE "%Active Virtual Users configured" 
) AS output_users
ON output_users.jobid = main.jobid
LEFT JOIN (
    SELECT
        jobid,
        replace(first, " NOPM from ", "") AS nopm,
        replace(second, " SQL Server TPM", "") AS tpm
    FROM (
        SELECT
            jobid,
            replace(first, second, "") AS first,
            replace(second, first, "") AS second
        FROM (
            SELECT
                jobid,
                substr(output, instr(output, "achieved ") + 9, length(output)) AS first,
                substr(output, instr(output, "from ") + 5, length(output)) AS second
            FROM
                JOBOUTPUT
            WHERE
                output LIKE "TEST RESULT : %"
        )
    )
) AS output_metrics
ON output_metrics.jobid = main.jobid
;