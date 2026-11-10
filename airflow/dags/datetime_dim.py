"""
### Datetime dimension (SCD Type 0)

Generates one row per hour (START_DATE..END_DATE) into `silver.dim_datetime`. No CSV and no bronze:
a calendar can be calculated, and it never changes.

Logic: `data_ingestion/datetime_ingestion.py`, SQL: `sql/load_dim_datetime.sql`.
Runs once when unpaused; to extend the range, change END_DATE in the Python file and trigger again.
"""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.datetime_ingestion import load_dim_datetime
from data_ingestion.db import create_schema


@dag(
    schedule="@once",                    # a calendar only needs to be generated once
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
