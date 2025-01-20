CREATE OR REPLACE VIEW smtoff.perfcounters_v
AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY run, sku, users, `timestamp`, `path` ORDER BY `timestamp` DESC) AS rnk
  FROM
  (
    SELECT
      j.run,
      j.sku,
      j.users,
      j.jobid,
      p.`timestamp`,
      `path`,
      `value`
    FROM (
      SELECT
        run,
        sku,
        users,
        `timestamp`,
        REGEXP_REPLACE(path, r'\([0-9]{1,2} ([a-z]{1}:)\)', r'(\1)') path,
        value
      FROM
        smtoff.perfcounters
    ) AS p
    LEFT JOIN (
      SELECT
        run,
        sku,
        users,
        jobid,
        `timestamp`
      FROM smtoff.jobs
    ) AS j
    ON (
      p.run = j.run
      AND p.sku = j.sku
      AND p.users = j.users
      -- Skip the first minute and only select one minute worth of data
      AND p.timestamp BETWEEN DATETIME_ADD(j.timestamp, INTERVAL 1 MINUTE) AND DATETIME_ADD(j.timestamp, INTERVAL 2 MINUTE)
    )
    UNION ALL
      SELECT
      run,
      sku,
      users,
      j.jobid,
      c.`timestamp`,
      path,
      value
      FROM (
        SELECT
          jobid,
          users,
          `timestamp`
        FROM
          smtoff.jobs
      ) AS j
    INNER JOIN (
      SELECT
        run,
        sku,
        jobid,
        `timestamp`,
        'tpm' AS path,
        counter AS value
      FROM
        smtoff.counters
    ) AS c ON (
      c.jobid = j.jobid
      -- Skip the first minute of each test as it is ramp up time
      AND c.timestamp >= DATETIME_ADD(j.timestamp, INTERVAL 1 MINUTE)
    )
  )
  WHERE users IS NOT NULL
)
;

CREATE OR REPLACE TABLE smtoff.perfcounters_r
AS (
  SELECT
    run,
    users,
    sku,
    jobid,
    path,
    MIN(value) AS value_min,
    MAX(value) AS value_max,
    AVG(value) AS value_avg,
    APPROX_QUANTILES(value, 100)[OFFSET(90)] AS value_90
  FROM
    smtoff.perfcounters_v
  WHERE rnk = 1
  GROUP BY 1, 2, 3, 4, 5
)
;