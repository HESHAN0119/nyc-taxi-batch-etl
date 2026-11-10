-- SCD Type 2: bronze.stg_vendor (today's full vendor.csv) -> silver.dim_vendor
-- Compares the snapshot in bronze with the CURRENT rows of the dimension:
--   new vendor      -> insert first version (valid from 1900-01-01, so it applies to all past trips)
--   changed vendor  -> close the current version, insert a new one valid from now()
--   unchanged       -> not touched (running this twice changes nothing)

-- 1. expire: close current versions whose name changed
UPDATE silver.dim_vendor d
SET    valid_to = now(), is_current = FALSE
FROM   bronze.stg_vendor s
WHERE  d.vendor_id = s.vendor_id
  AND  d.is_current
  AND  d.vendor_name IS DISTINCT FROM s.vendor_name;

-- 2. insert: vendors with no current version (brand new, or just expired in step 1)
INSERT INTO silver.dim_vendor (vendor_id, vendor_name, valid_from)
SELECT s.vendor_id,
       s.vendor_name,
       CASE WHEN EXISTS (SELECT 1 FROM silver.dim_vendor h WHERE h.vendor_id = s.vendor_id)
            THEN now()                      -- changed: new version starts now
            ELSE TIMESTAMP '1900-01-01'     -- new: first version covers all history
       END
FROM   bronze.stg_vendor s
WHERE  NOT EXISTS (SELECT 1 FROM silver.dim_vendor d WHERE d.vendor_id = s.vendor_id AND d.is_current);
