"""Location (taxi zone) reference data (SCD Type 2):
data/reference/taxi_zone_lookup.csv -> bronze.stg_taxi_zone (truncate + reload) -> silver.dim_location (keeps history).

Called from the Airflow DAG airflow/dags/location_dim.py:  ingest_location_data()  then  load_dim_location()
"""

import logging

import pandas as pd

from data_ingestion.db import DATA_DIR, load_csv_to_staging, run_sql_file

log = logging.getLogger(__name__)

ZONE_FILE = DATA_DIR / "reference" / "taxi_zone_lookup.csv"
STAGING_TABLE = "bronze.stg_taxi_zone"
DIM_SQL = "scd2_dim_location.sql"        # 1. expire changed rows  2. insert new versions

# The TLC file uses different header names than our tables.
RENAME = {"LocationID": "location_id", "Borough": "borough", "Zone": "zone"}


def ingest_location_data() -> int:
    "loads taxi_zone_lookup.csv into bronze.stg_taxi_zone"
    df = pd.read_csv(ZONE_FILE).rename(columns=RENAME)[["location_id", "borough", "zone", "service_zone"]]
    rows = load_csv_to_staging(df, STAGING_TABLE)
    log.info("Location bronze loaded: file=%s rows=%d", ZONE_FILE.name, rows)
    return rows


def load_dim_location() -> dict:
    "SCD Type 2: bronze.stg_taxi_zone -> silver.dim_location"
    expired, inserted = run_sql_file(DIM_SQL)
    log.info("SCD2 dim_location: expired=%d inserted=%d", expired, inserted)
    return {"expired": expired, "inserted": inserted}
