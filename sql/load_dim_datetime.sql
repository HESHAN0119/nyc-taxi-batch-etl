-- dim_datetime (SCD Type 0: a calendar never changes) - one row per hour, generated (no CSV, no bronze).
-- Parameters: %(start_date)s and %(end_date)s (inclusive), set in data_ingestion/datetime_ingestion.py.
-- Hours that already exist are skipped, so this is safe to re-run or to run with a wider range later.

INSERT INTO silver.dim_datetime
       (datetime_key, datetime_hour, date, year, quarter, month, month_name,
        day, day_of_week, day_name, hour, is_weekend)
SELECT TO_CHAR(ts, 'YYYYMMDDHH24')::INT,      -- e.g. 2023011514
       ts,
       ts::date,
       EXTRACT(YEAR    FROM ts),
       EXTRACT(QUARTER FROM ts),
       EXTRACT(MONTH   FROM ts),
       TRIM(TO_CHAR(ts, 'Month')),
       EXTRACT(DAY     FROM ts),
       EXTRACT(ISODOW  FROM ts),               -- 1 = Monday ... 7 = Sunday
       TRIM(TO_CHAR(ts, 'Day')),
       EXTRACT(HOUR    FROM ts),
       EXTRACT(ISODOW  FROM ts) IN (6, 7)      -- Saturday / Sunday
FROM   generate_series(%(start_date)s::timestamp,
                       %(end_date)s::timestamp + INTERVAL '23 hours',
                       INTERVAL '1 hour') AS ts
ON CONFLICT (datetime_key) DO NOTHING;
