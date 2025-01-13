CREATE OR REPLACE VIEW smtoff.perfcounters_v
AS (
  SELECT
    run,
    sku,
    users,
    `timestamp`,
    path,
    value
  FROM (
    SELECT
      run,
      sku,
      users,
      MIN(`timestamp`) AS start,
      MAX(`timestamp`) AS finish
    FROM smtoff.jobs
    GROUP BY 1, 2, 3
  ) AS j
  INNER JOIN (
    SELECT
      PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %P', `timestamp`) AS `timestamp`,
      REGEXP_REPLACE(path, r'\([0-9]{1,2} ([a-z]{1}:)\)', r'(\1)') path,
      value
    FROM
      smtoff.perfcounters
  ) AS p
  ON (
    p.timestamp BETWEEN j.start AND j.finish
  )
  UNION ALL
  SELECT
    run,
    sku,
    users,
    `timestamp`,
    'tpm' AS path,
    counter AS value
  FROM smtoff.counters AS c
  INNER JOIN (
    SELECT
      jobid,
      users
    FROM
      smtoff.jobs
  ) AS j ON c.jobid = j.jobid
)
;

CREATE OR REPLACE TABLE smtoff.perfcounters_r
AS (
  SELECT
    run,
    users,
    sku,
    path,
    MIN(value) AS value_min,
    MAX(value) AS value_max,
    AVG(value) AS value_avg,
    APPROX_QUANTILES(value, 100)[OFFSET(90)] AS value_90
  FROM
    smtoff.perfcounters_v
  GROUP BY 1, 2, 3, 4    
)
;