-- Warehouse schema. Safe to run again.
--   bronze: loaded data   silver: star schema   gold: views for Superset

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================================================
-- BRONZE
-- ============================================================================

CREATE UNLOGGED TABLE IF NOT EXISTS bronze.stg_taxi_trips (
    vendor_id              SMALLINT,
    pickup_datetime        TIMESTAMP,
    dropoff_datetime       TIMESTAMP,
    passenger_count        SMALLINT,
    trip_distance          NUMERIC(10,2),
    rate_code_id           SMALLINT,
    store_and_fwd_flag     CHAR(1),
    pickup_location_id     SMALLINT,
    dropoff_location_id    SMALLINT,
    payment_type_id        SMALLINT,
    fare_amount            NUMERIC(10,2),
    extra                  NUMERIC(10,2),
    mta_tax                NUMERIC(10,2),
    tip_amount             NUMERIC(10,2),
    tolls_amount           NUMERIC(10,2),
    improvement_surcharge  NUMERIC(10,2),
    total_amount           NUMERIC(10,2),
    congestion_surcharge   NUMERIC(10,2),
    airport_fee            NUMERIC(10,2),
    source_file            TEXT,
    updated_at             TIMESTAMP NOT NULL DEFAULT now()
);
-- for tables created before updated_at was added
ALTER TABLE bronze.stg_taxi_trips ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT now();
-- for the delete by pickup date
CREATE INDEX IF NOT EXISTS ix_stg_taxi_trips_pickup ON bronze.stg_taxi_trips (pickup_datetime);

-- Reference tables (truncate + reload). The primary key blocks duplicate codes.
CREATE UNLOGGED TABLE IF NOT EXISTS bronze.stg_taxi_zone (
    location_id   SMALLINT PRIMARY KEY,
    borough       TEXT,
    zone          TEXT,
    service_zone  TEXT
);

CREATE UNLOGGED TABLE IF NOT EXISTS bronze.stg_payment_type (
    payment_type_id  SMALLINT PRIMARY KEY,
    description      TEXT NOT NULL
);

CREATE UNLOGGED TABLE IF NOT EXISTS bronze.stg_rate_code (
    rate_code_id  SMALLINT PRIMARY KEY,
    description   TEXT NOT NULL
);

CREATE UNLOGGED TABLE IF NOT EXISTS bronze.stg_vendor (
    vendor_id    SMALLINT PRIMARY KEY,
    vendor_name  TEXT NOT NULL
);

-- for tables created before the primary keys were added
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stg_taxi_zone_pkey') THEN
        ALTER TABLE bronze.stg_taxi_zone ADD PRIMARY KEY (location_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stg_payment_type_pkey') THEN
        ALTER TABLE bronze.stg_payment_type ADD PRIMARY KEY (payment_type_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stg_rate_code_pkey') THEN
        ALTER TABLE bronze.stg_rate_code ADD PRIMARY KEY (rate_code_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stg_vendor_pkey') THEN
        ALTER TABLE bronze.stg_vendor ADD PRIMARY KEY (vendor_id);
    END IF;
END $$;

-- ============================================================================
-- DIMENSIONS
--   *_sk = surrogate key (one per version), *_id = code from the source
-- ============================================================================

CREATE TABLE IF NOT EXISTS silver.dim_location (
    location_sk   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    location_id   SMALLINT  NOT NULL,
    borough       TEXT,
    zone          TEXT,
    service_zone  TEXT,
    valid_from    TIMESTAMP NOT NULL,
    valid_to      TIMESTAMP NOT NULL DEFAULT '9999-12-31',
    is_current    BOOLEAN   NOT NULL DEFAULT TRUE,
    UNIQUE (location_id, valid_from),
    CHECK (valid_from < valid_to)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_location_current ON silver.dim_location (location_id) WHERE is_current;

-- SCD1: one row per code, no history
CREATE TABLE IF NOT EXISTS silver.dim_payment_type (
    payment_type_id  SMALLINT  PRIMARY KEY,
    description      TEXT      NOT NULL,
    updated_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS silver.dim_rate_code (
    rate_code_sk  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rate_code_id  SMALLINT  NOT NULL,
    description   TEXT      NOT NULL,
    valid_from    TIMESTAMP NOT NULL,
    valid_to      TIMESTAMP NOT NULL DEFAULT '9999-12-31',
    is_current    BOOLEAN   NOT NULL DEFAULT TRUE,
    UNIQUE (rate_code_id, valid_from),
    CHECK (valid_from < valid_to)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_rate_code_current ON silver.dim_rate_code (rate_code_id) WHERE is_current;

CREATE TABLE IF NOT EXISTS silver.dim_vendor (
    vendor_sk    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id    SMALLINT  NOT NULL,
    vendor_name  TEXT      NOT NULL,
    valid_from   TIMESTAMP NOT NULL,
    valid_to     TIMESTAMP NOT NULL DEFAULT '9999-12-31',
    is_current   BOOLEAN   NOT NULL DEFAULT TRUE,
    UNIQUE (vendor_id, valid_from),
    CHECK (valid_from < valid_to)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_vendor_current ON silver.dim_vendor (vendor_id) WHERE is_current;

-- ============================================================================
-- DATETIME DIMENSION (one row per hour)
-- ============================================================================

CREATE TABLE IF NOT EXISTS silver.dim_datetime (
    datetime_key   INT PRIMARY KEY,          -- e.g. 2023011514
    datetime_hour  TIMESTAMP NOT NULL UNIQUE,
    date           DATE      NOT NULL,
    year           SMALLINT  NOT NULL,
    quarter        SMALLINT  NOT NULL,
    month          SMALLINT  NOT NULL,
    month_name     TEXT      NOT NULL,
    day            SMALLINT  NOT NULL,
    day_of_week    SMALLINT  NOT NULL,       -- 1 = Monday, 7 = Sunday
    day_name       TEXT      NOT NULL,
    hour           SMALLINT  NOT NULL,
    is_weekend     BOOLEAN   NOT NULL
);

-- ============================================================================
-- FACT (one row per trip)
-- ============================================================================

CREATE TABLE IF NOT EXISTS silver.fact_taxi_trips (
    trip_id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pickup_date            DATE NOT NULL,
    pickup_datetime_key    INT  NOT NULL REFERENCES silver.dim_datetime (datetime_key),
    dropoff_datetime_key   INT  NOT NULL REFERENCES silver.dim_datetime (datetime_key),
    pickup_location_sk     INT  NOT NULL REFERENCES silver.dim_location (location_sk),
    dropoff_location_sk    INT  NOT NULL REFERENCES silver.dim_location (location_sk),
    vendor_sk              INT  NOT NULL REFERENCES silver.dim_vendor (vendor_sk),
    payment_type_id        SMALLINT NOT NULL REFERENCES silver.dim_payment_type (payment_type_id),
    rate_code_sk           INT  NOT NULL REFERENCES silver.dim_rate_code (rate_code_sk),
    store_and_fwd_flag     CHAR(1),
    passenger_count        SMALLINT,
    trip_distance          NUMERIC(10,2) NOT NULL,
    trip_duration_min      NUMERIC(10,2) NOT NULL,
    fare_amount            NUMERIC(10,2) NOT NULL,
    extra                  NUMERIC(10,2),
    mta_tax                NUMERIC(10,2),
    tip_amount             NUMERIC(10,2),
    tolls_amount           NUMERIC(10,2),
    improvement_surcharge  NUMERIC(10,2),
    congestion_surcharge   NUMERIC(10,2),
    airport_fee            NUMERIC(10,2),
    total_amount           NUMERIC(10,2) NOT NULL,
    source_file            TEXT,
    loaded_at              TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_fact_pickup_date         ON silver.fact_taxi_trips (pickup_date);
CREATE INDEX IF NOT EXISTS ix_fact_pickup_datetime_key ON silver.fact_taxi_trips (pickup_datetime_key);
CREATE INDEX IF NOT EXISTS ix_fact_pickup_location_sk  ON silver.fact_taxi_trips (pickup_location_sk);
CREATE INDEX IF NOT EXISTS ix_fact_payment_type_id     ON silver.fact_taxi_trips (payment_type_id);

-- ============================================================================
-- GOLD VIEWS
-- ============================================================================

-- fare per mile = SUM(fare_amount) / SUM(miles)
CREATE OR REPLACE VIEW gold.fare_per_mile_daily AS
SELECT pickup_date,
       SUM(fare_amount)    AS fare_amount,
       SUM(trip_distance)  AS miles
FROM   silver.fact_taxi_trips
WHERE  trip_distance > 0
  AND  fare_amount > 0
GROUP  BY pickup_date
ORDER  BY pickup_date;

-- revenue per day and payment type
CREATE OR REPLACE VIEW gold.revenue_by_payment_type_daily AS
SELECT f.pickup_date,
       p.payment_type_id,
       p.description                                       AS payment_type,
       SUM(f.total_amount)                                 AS total_revenue
FROM   silver.fact_taxi_trips f
JOIN   silver.dim_payment_type p ON p.payment_type_id = f.payment_type_id
GROUP  BY f.pickup_date, p.payment_type_id, p.description
ORDER  BY f.pickup_date DESC;

-- trips per day and hour
CREATE OR REPLACE VIEW gold.trips_by_hour_daily AS
SELECT f.pickup_date,
       d.hour                                             AS pickup_hour,
       COUNT(*)                                           AS trips
FROM   silver.fact_taxi_trips f
JOIN   silver.dim_datetime d ON d.datetime_key = f.pickup_datetime_key
GROUP  BY f.pickup_date, d.hour
ORDER  BY f.pickup_date, trips DESC;
