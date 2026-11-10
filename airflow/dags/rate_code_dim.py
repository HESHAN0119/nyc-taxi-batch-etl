"""
### Rate code dimension (SCD Type 2)

`data/reference/rate_code.csv` -> `bronze.stg_rate_code` (truncate + reload)
-> `silver.dim_rate_code` (changed rate code: old row closed + new version inserted; history kept).

Logic: `data_ingestion/rate_code_ingestion.py`, SQL: `sql/scd2_dim_rate_code.sql`.
"""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.rate_code_ingestion import ingest_rate_code_data, load_dim_rate_code


@dag(
    schedule="20 1 * * *",               # 01:20 daily, before the trip load at 02:00
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "dimension", "scd2"],
)
def rate_code_dim():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def ingest_rate_code() -> int:
        return ingest_rate_code_data()

    @task
    def load_dim() -> dict:
        return load_dim_rate_code()

    create_tables() >> ingest_rate_code() >> load_dim()


rate_code_dim()
