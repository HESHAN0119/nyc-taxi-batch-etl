"""Reads one daily parquet file, cleans it and loads it into bronze.stg_taxi_trips."""

import io
import logging
import os
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import psycopg2
from airflow.exceptions import AirflowSkipException
from airflow.providers.postgres.hooks.postgres import PostgresHook

log = logging.getLogger(__name__)

DW_CONN_ID = "postgres_dw"
DATA_DIR = Path(os.getenv("DATA_DIR", "/opt/airflow/data"))
SQL_DIR = Path(os.getenv("SQL_DIR", "/opt/airflow/sql"))
QUARANTINE_DIR = DATA_DIR / "quarantine"
STAGING_TABLE = "bronze.stg_taxi_trips"

# parquet column -> table column
RENAME = {
    "vendorid": "vendor_id",
    "tpep_pickup_datetime": "pickup_datetime",
    "tpep_dropoff_datetime": "dropoff_datetime",
    "ratecodeid": "rate_code_id",
    "pulocationid": "pickup_location_id",
    "dolocationid": "dropoff_location_id",
    "payment_type": "payment_type_id",
}

STAGING_COLUMNS = [
    "vendor_id", "pickup_datetime", "dropoff_datetime", "passenger_count", "trip_distance",
    "rate_code_id", "store_and_fwd_flag", "pickup_location_id", "dropoff_location_id",
    "payment_type_id", "fare_amount", "extra", "mta_tax", "tip_amount", "tolls_amount",
    "improvement_surcharge", "total_amount", "congestion_surcharge", "airport_fee", "source_file",
]

# these come as floats (1.0) when they have nulls
INTEGER_COLUMNS = [
    "vendor_id", "passenger_count", "rate_code_id",
    "pickup_location_id", "dropoff_location_id", "payment_type_id",
]

# COPY is much faster than INSERT
data_insertion_sql = f"COPY {STAGING_TABLE} ({', '.join(STAGING_COLUMNS)}) FROM STDIN WITH (FORMAT csv)"

# delete one pickup date
delete_date_sql = f"DELETE FROM {STAGING_TABLE} WHERE pickup_datetime >= %s AND pickup_datetime < %s"


def take_d_1_date(custom_date: str | None =  None) -> date:
    "custom_date if given, else yesterday"
    if custom_date:
        return date.fromisoformat(custom_date)
    return date.today() - timedelta(days=1)


def daily_file(day: date) -> Path:
    "path of the daily parquet file"
    return DATA_DIR / "raw" / "daily" / f"{day:%Y-%m}" / f"yellow_tripdata_{day:%Y-%m-%d}.parquet"


def ingest_data() -> dict:
    "loads the day from take_d_1_date() into bronze"
    d_1_date = take_d_1_date()
    source = daily_file(d_1_date)
    log.info("Ingestion started: load_date=%s file=%s", d_1_date, source)

    if not source.exists():
        # no file yet -> skip the task (load_fact is skipped too)
        log.warning("No raw file for %s, skipping this day: %s", d_1_date, source)
        raise AirflowSkipException(f"No raw file for {d_1_date}")

    df = pd.read_parquet(source)
    df = df.rename(columns=str.lower).rename(columns=RENAME)
    rows_read = len(df)

    df = clean_data(df, d_1_date)
    df[INTEGER_COLUMNS] = df[INTEGER_COLUMNS].astype("Int64")
    df["source_file"] = source.name

    rows = insert_data_staging(df[STAGING_COLUMNS])
    log.info("Ingestion finished: load_date=%s rows_read=%d rows_rejected=%d rows_loaded=%d",
             d_1_date, rows_read, rows_read - rows, rows)
    return {"load_date": d_1_date.isoformat(), "file": source.name,
            "rows_read": rows_read, "rows_rejected": rows_read - rows, "rows_loaded": rows}


def clean_data(df: pd.DataFrame, day: date) -> pd.DataFrame:
    "removes bad trips (saved to data/quarantine) and fixes missing values"
    duration = df["dropoff_datetime"] - df["pickup_datetime"]

    # first failed rule = reject reason
    rules = {
        "pickup_not_on_load_date": df["pickup_datetime"].dt.date != day,
        "dropoff_not_after_pickup": duration <= pd.Timedelta(0),
        "duration_over_24h": duration > pd.Timedelta(hours=24),
        "negative_amount": (df["fare_amount"] < 0) | (df["total_amount"] < 0),
    }
    df["reject_reason"] = None
    for reason, failed in rules.items():
        df.loc[failed & df["reject_reason"].isna(), "reject_reason"] = reason

    rejected = df[df["reject_reason"].notna()]
    clean = df[df["reject_reason"].isna()].drop(columns="reject_reason")

    if len(rejected) > 0:
        QUARANTINE_DIR.mkdir(parents=True, exist_ok=True)
        rejected.to_parquet(QUARANTINE_DIR / f"rejected_{day}.parquet", index=False)
    log.info("Cleaning: kept=%d rejected=%d reasons=%s",
             len(clean), len(rejected), rejected["reject_reason"].value_counts().to_dict())

    clean["rate_code_id"] = clean["rate_code_id"].fillna(99)  # 99 = unknown
    clean.loc[clean["passenger_count"] == 0, "passenger_count"] = None  # 0 = not entered
    return clean


def delete_existing_data(cur, df: pd.DataFrame) -> int:
    "deletes the days we are about to load, so reloading does not duplicate"
    deleted = 0
    for day in sorted(df["pickup_datetime"].dt.date.unique()):
        cur.execute(delete_date_sql, (day, day + timedelta(days=1)))
        log.info("Deleted %d existing rows for pickup date %s", cur.rowcount, day)
        deleted += cur.rowcount
    return deleted


def insert_data_staging(df: pd.DataFrame) -> int:
    "delete + copy into bronze in one transaction"
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False)
    buffer.seek(0)

    c = PostgresHook.get_connection(DW_CONN_ID)
    conn = psycopg2.connect(host=c.host, port=c.port, dbname=c.schema, user=c.login, password=c.password)
    try:
        with conn, conn.cursor() as cur:
            delete_existing_data(cur, df)
            cur.copy_expert(data_insertion_sql, buffer)
            return cur.rowcount
    finally:
        conn.close()

