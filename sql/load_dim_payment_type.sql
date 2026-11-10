-- SCD Type 1: bronze.stg_payment_type (today's full payment_type.csv) -> silver.dim_payment_type
-- Upsert, no history:
--   new code          -> inserted
--   changed label     -> description overwritten (old value is gone)
--   unchanged         -> not touched (the WHERE skips it), so running this twice changes nothing

INSERT INTO silver.dim_payment_type (payment_type_id, description)
SELECT payment_type_id, description
FROM   bronze.stg_payment_type
ON CONFLICT (payment_type_id) DO UPDATE
SET    description = EXCLUDED.description,
       updated_at  = now()
WHERE  silver.dim_payment_type.description IS DISTINCT FROM EXCLUDED.description;
