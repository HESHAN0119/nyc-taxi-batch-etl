"""Loads a range of days: daily parquet -> clean -> bronze -> fact table. Used by the load_custom_date DAG."""

import logging
from datetime import date, timedelta

import pandas as pd

from data_ingestion.db import run_sql_file
from data_ingestion.fact_ingestion import FACT_SQL
from data_ingestion.raw_data_ingestion import (
    INTEGER_COLUMNS,
    RENAME,
    STAGING_COLUMNS,
    clean_data,
    daily_file,
    insert_data_staging,
)

log = logging.getLogger(__name__)

# Days to load (both included)
START_DATE = "2023-01-01"
END_DATE = "2023-01-10"


def get_days() -> list[str]:
    "list of days from START_DATE to END_DATE"
    start = date.fromisoformat(START_DATE)
    end = date.fromisoformat(END_DATE)
    if start > end:
        raise ValueError(f"START_DATE {START_DATE} is after END_DATE {END_DATE}")
    return [str(start + timedelta(days=i)) for i in range((end - start).days + 1)]


def load_day(day: str) -> dict:
    "loads one day into bronze and the fact table"
    load_date = date.fromisoformat(day)
    source = daily_file(load_date)
    if not source.exists():
        raise FileNotFoundError(f"No raw file for {day}: {source}")

    df = pd.read_parquet(source).rename(columns=str.lower).rename(columns=RENAME)
    rows_read = len(df)

    df = clean_data(df, load_date)
    df[INTEGER_COLUMNS] = df[INTEGER_COLUMNS].astype("Int64")
    df["source_file"] = source.name
    rows_bronze = insert_data_staging(df[STAGING_COLUMNS])

    deleted, inserted = run_sql_file(FACT_SQL, {"load_date": load_date})

    log.info("Day loaded: date=%s rows_read=%d rows_bronze=%d fact_deleted=%d fact_inserted=%d",
             day, rows_read, rows_bronze, deleted, inserted)
    return {"date": day, "rows_read": rows_read, "rows_bronze": rows_bronze, "fact_inserted": inserted}
