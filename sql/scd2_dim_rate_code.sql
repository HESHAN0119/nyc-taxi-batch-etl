-- SCD Type 2: bronze.stg_rate_code (today's full rate_code.csv) -> silver.dim_rate_code
-- Same logic as scd2_dim_vendor.sql: new -> insert, changed -> expire + insert, unchanged -> untouched.

-- 1. expire: close current versions whose description changed
UPDATE silver.dim_rate_code d
SET    valid_to = now(), is_current = FALSE
FROM   bronze.stg_rate_code s
WHERE  d.rate_code_id = s.rate_code_id
  AND  d.is_current
  AND  d.description IS DISTINCT FROM s.description;

-- 2. insert: rate codes with no current version (brand new, or just expired in step 1)
INSERT INTO silver.dim_rate_code (rate_code_id, description, valid_from)
SELECT s.rate_code_id,
       s.description,
       CASE WHEN EXISTS (SELECT 1 FROM silver.dim_rate_code h WHERE h.rate_code_id = s.rate_code_id)
            THEN now()                      -- changed: new version starts now
            ELSE TIMESTAMP '1900-01-01'     -- new: first version covers all history
       END
FROM   bronze.stg_rate_code s
WHERE  NOT EXISTS (SELECT 1 FROM silver.dim_rate_code d WHERE d.rate_code_id = s.rate_code_id AND d.is_current);
