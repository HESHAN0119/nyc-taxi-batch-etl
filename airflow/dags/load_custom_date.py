"""Loads all days from START_DATE to END_DATE (set in custom_date_load.py). One task per day.
Run the dimension DAGs first."""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.custom_date_load import get_days, load_day
from data_ingestion.db import create_schema


@dag(
    schedule=None,                       # manual only
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "ingestion", "backfill"],
)
def load_custom_date():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def list_days() -> list[str]:
        return get_days()

    @task(max_active_tis_per_dagrun=4)   # max 4 days in parallel
    def load_one_day(day: str) -> dict:
        return load_day(day)

    days = list_days()
    create_tables() >> days
    load_one_day.expand(day=days)       # one task per day


load_custom_date()
