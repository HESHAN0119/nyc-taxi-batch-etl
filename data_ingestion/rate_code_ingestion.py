"""Rate codes: CSV -> bronze.stg_rate_code -> silver.dim_rate_code (SCD2)."""

import logging

import pandas as pd

from data_ingestion.db import DATA_DIR, load_csv_to_staging, run_sql_file

log = logging.getLogger(__name__)

RATE_CODE_FILE = DATA_DIR / "reference" / "rate_code.csv"
STAGING_TABLE = "bronze.stg_rate_code"
DIM_SQL = "scd2_dim_rate_code.sql"


def ingest_rate_code_data() -> int:
    "CSV -> bronze"
    df = pd.read_csv(RATE_CODE_FILE)[["rate_code_id", "description"]]
    rows = load_csv_to_staging(df, STAGING_TABLE)
    log.info("Rate code bronze loaded: file=%s rows=%d", RATE_CODE_FILE.name, rows)
    return rows


def load_dim_rate_code() -> dict:
    "bronze -> dimension (SCD2)"
    expired, inserted = run_sql_file(DIM_SQL)
    log.info("SCD2 dim_rate_code: expired=%d inserted=%d", expired, inserted)
    return {"expired": expired, "inserted": inserted}
