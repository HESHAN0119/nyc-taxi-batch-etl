-- One row per hour between start_date and end_date. Existing hours are skipped.

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
