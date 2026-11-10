-- Runs once, on the first start of an empty warehouse volume (as DW_DB_USER, in DW_DB_NAME).
-- bronze: cleaned trips land here first.   silver: the star schema.   gold: views Superset reads.
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;   -- reporting views for Superset
