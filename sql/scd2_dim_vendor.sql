-- SCD2: close changed rows, then insert new versions

-- close current rows where the name changed
UPDATE silver.dim_vendor d
SET    valid_to = now(), is_current = FALSE
FROM   bronze.stg_vendor s
WHERE  d.vendor_id = s.vendor_id
  AND  d.is_current
  AND  d.vendor_name IS DISTINCT FROM s.vendor_name;

-- insert new vendors and new versions of changed ones
INSERT INTO silver.dim_vendor (vendor_id, vendor_name, valid_from)
SELECT s.vendor_id,
       s.vendor_name,
       CASE WHEN EXISTS (SELECT 1 FROM silver.dim_vendor h WHERE h.vendor_id = s.vendor_id)
            THEN now()                      -- changed: new version starts now
            ELSE TIMESTAMP '1900-01-01'     -- new: first version covers all history
       END
FROM   bronze.stg_vendor s
WHERE  NOT EXISTS (SELECT 1 FROM silver.dim_vendor d WHERE d.vendor_id = s.vendor_id AND d.is_current);
