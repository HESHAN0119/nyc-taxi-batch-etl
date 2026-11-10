"""Vendor reference data (SCD Type 2):
data/reference/vendor.csv -> bronze.stg_vendor (truncate + reload) -> silver.dim_vendor (keeps history).

Called from the Airflow DAG airflow/dags/vendor_dim.py:  ingest_vendor_data()  then  load_dim_vendor()
"""

import logging

import pandas as pd

from data_ingestion.db import DATA_DIR, load_csv_to_staging, run_sql_file

log = logging.getLogger(__name__)

VENDOR_FILE = DATA_DIR / "reference" / "vendor.csv"
STAGING_TABLE = "bronze.stg_vendor"
DIM_SQL = "scd2_dim_vendor.sql"          # 1. expire changed rows  2. insert new versions


def ingest_vendor_data() -> int:
    "loads vendor.csv into bronze.stg_vendor"
    df = pd.read_csv(VENDOR_FILE)[["vendor_id", "vendor_name"]]
    rows = load_csv_to_staging(df, STAGING_TABLE)
    log.info("Vendor bronze loaded: file=%s rows=%d", VENDOR_FILE.name, rows)
    return rows


def load_dim_vendor() -> dict:
    "SCD Type 2: bronze.stg_vendor -> silver.dim_vendor"
    expired, inserted = run_sql_file(DIM_SQL)
    log.info("SCD2 dim_vendor: expired=%d inserted=%d", expired, inserted)
    return {"expired": expired, "inserted": inserted}
