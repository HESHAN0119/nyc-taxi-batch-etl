"""Datetime dimension: one row per hour from START_DATE to END_DATE (set in datetime_ingestion.py)."""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.datetime_ingestion import load_dim_datetime
from data_ingestion.db import create_schema


@dag(
    schedule="@once",                    # run once
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "dimension", "scd0"],
)
def datetime_dim():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def load_dim() -> int:
        return load_dim_datetime()

    create_tables() >> load_dim()


datetime_dim()
