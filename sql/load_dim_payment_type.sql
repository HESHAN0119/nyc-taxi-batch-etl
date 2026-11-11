-- SCD1: insert new codes, overwrite changed descriptions (no history)

INSERT INTO silver.dim_payment_type (payment_type_id, description)
SELECT payment_type_id, description
FROM   bronze.stg_payment_type
ON CONFLICT (payment_type_id) DO UPDATE
SET    description = EXCLUDED.description,
       updated_at  = now()
WHERE  silver.dim_payment_type.description IS DISTINCT FROM EXCLUDED.description;
