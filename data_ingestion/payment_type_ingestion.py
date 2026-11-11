"""Payment types: CSV -> bronze.stg_payment_type -> silver.dim_payment_type (SCD1)."""

import logging

import pandas as pd

from data_ingestion.db import DATA_DIR, load_csv_to_staging, run_sql_file

log = logging.getLogger(__name__)

PAYMENT_TYPE_FILE = DATA_DIR / "reference" / "payment_type.csv"
STAGING_TABLE = "bronze.stg_payment_type"
DIM_SQL = "load_dim_payment_type.sql"


def ingest_payment_type_data() -> int:
    "CSV -> bronze"
    df = pd.read_csv(PAYMENT_TYPE_FILE)[["payment_type_id", "description"]]
    rows = load_csv_to_staging(df, STAGING_TABLE)
    log.info("Payment type bronze loaded: file=%s rows=%d", PAYMENT_TYPE_FILE.name, rows)
    return rows


def load_dim_payment_type() -> int:
    "bronze -> dimension (SCD1)"
    [changed] = run_sql_file(DIM_SQL)
    log.info("SCD1 dim_payment_type: inserted_or_updated=%d", changed)
    return changed
