"""Vendors: CSV -> bronze.stg_vendor -> silver.dim_vendor (SCD2)."""

import logging

import pandas as pd

from data_ingestion.db import DATA_DIR, load_csv_to_staging, run_sql_file

log = logging.getLogger(__name__)

VENDOR_FILE = DATA_DIR / "reference" / "vendor.csv"
STAGING_TABLE = "bronze.stg_vendor"
DIM_SQL = "scd2_dim_vendor.sql"


def ingest_vendor_data() -> int:
    "CSV -> bronze"
    df = pd.read_csv(VENDOR_FILE)[["vendor_id", "vendor_name"]]
    rows = load_csv_to_staging(df, STAGING_TABLE)
    log.info("Vendor bronze loaded: file=%s rows=%d", VENDOR_FILE.name, rows)
    return rows


def load_dim_vendor() -> dict:
    "bronze -> dimension (SCD2)"
    expired, inserted = run_sql_file(DIM_SQL)
    log.info("SCD2 dim_vendor: expired=%d inserted=%d", expired, inserted)
    return {"expired": expired, "inserted": inserted}
