-- Incremental load of ONE day: bronze.stg_taxi_trips -> silver.fact_taxi_trips  (delete + insert by day)
-- Parameter: %(load_date)s, decided in Python (data_ingestion/fact_ingestion.py).
-- Both statements run in one transaction, so re-running a day replaces it and never duplicates.
--
-- Dimension lookups:
--   SCD2 (location, vendor, rate code): the version valid at the trip's pickup time
--   SCD1 (payment type): one row per code
-- LEFT JOIN + NOT NULL foreign keys: an unknown code makes the load FAIL loudly instead of
-- silently dropping trips (which an inner join would do).

-- 1. remove this day's previous load
DELETE FROM silver.fact_taxi_trips
WHERE  pickup_date = %(load_date)s;

-- 2. insert this day's trips (bronze keeps several days, so filter on the load day)
INSERT INTO silver.fact_taxi_trips
       (pickup_date, pickup_datetime_key, dropoff_datetime_key,
        pickup_location_sk, dropoff_location_sk, vendor_sk, payment_type_id, rate_code_sk,
        store_and_fwd_flag, passenger_count, trip_distance, trip_duration_min,
        fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
        congestion_surcharge, airport_fee, total_amount, source_file)
SELECT s.pickup_datetime::date,
       TO_CHAR(s.pickup_datetime,  'YYYYMMDDHH24')::INT,
       TO_CHAR(s.dropoff_datetime, 'YYYYMMDDHH24')::INT,
       pl.location_sk,
       dl.location_sk,
       v.vendor_sk,
       p.payment_type_id,
       r.rate_code_sk,
       s.store_and_fwd_flag,
       s.passenger_count,
       s.trip_distance,
       ROUND(EXTRACT(EPOCH FROM s.dropoff_datetime - s.pickup_datetime) / 60.0, 2),
       s.fare_amount,
       s.extra,
       s.mta_tax,
       s.tip_amount,
       s.tolls_amount,
       s.improvement_surcharge,
       s.congestion_surcharge,
       s.airport_fee,
       s.total_amount,
       s.source_file
FROM bronze.stg_taxi_trips s
LEFT JOIN silver.dim_location pl
       ON pl.location_id = s.pickup_location_id
      AND s.pickup_datetime >= pl.valid_from AND s.pickup_datetime < pl.valid_to
LEFT JOIN silver.dim_location dl
       ON dl.location_id = s.dropoff_location_id
      AND s.pickup_datetime >= dl.valid_from AND s.pickup_datetime < dl.valid_to
LEFT JOIN silver.dim_vendor v
       ON v.vendor_id = s.vendor_id
      AND s.pickup_datetime >= v.valid_from AND s.pickup_datetime < v.valid_to
LEFT JOIN silver.dim_payment_type p
       ON p.payment_type_id = s.payment_type_id
LEFT JOIN silver.dim_rate_code r
       ON r.rate_code_id = COALESCE(s.rate_code_id, 99)      -- missing rate code -> 99 = Unknown
      AND s.pickup_datetime >= r.valid_from AND s.pickup_datetime < r.valid_to
WHERE  s.pickup_datetime >= %(load_date)s::date
  AND  s.pickup_datetime <  %(load_date)s::date + 1;
