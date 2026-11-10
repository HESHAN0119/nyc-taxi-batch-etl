-- SCD Type 2: bronze.stg_taxi_zone (today's full taxi_zone_lookup.csv) -> silver.dim_location
-- Same logic as scd2_dim_vendor.sql, but three attributes are compared (borough, zone, service_zone).

-- 1. expire: close current versions where any attribute changed
UPDATE silver.dim_location d
SET    valid_to = now(), is_current = FALSE
FROM   bronze.stg_taxi_zone s
WHERE  d.location_id = s.location_id
  AND  d.is_current
  AND  (d.borough, d.zone, d.service_zone) IS DISTINCT FROM (s.borough, s.zone, s.service_zone);

-- 2. insert: locations with no current version (brand new, or just expired in step 1)
INSERT INTO silver.dim_location (location_id, borough, zone, service_zone, valid_from)
SELECT s.location_id,
       s.borough,
       s.zone,
       s.service_zone,
       CASE WHEN EXISTS (SELECT 1 FROM silver.dim_location h WHERE h.location_id = s.location_id)
            THEN now()                      -- changed: new version starts now
            ELSE TIMESTAMP '1900-01-01'     -- new: first version covers all history
       END
FROM   bronze.stg_taxi_zone s
WHERE  NOT EXISTS (SELECT 1 FROM silver.dim_location d WHERE d.location_id = s.location_id AND d.is_current);
