"""
### Vendor dimension (SCD Type 2)

`data/reference/vendor.csv` -> `bronze.stg_vendor` (truncate + reload)
-> `silver.dim_vendor` (changed vendor: old row closed + new version inserted; history kept).

Logic: `data_ingestion/vendor_ingestion.py`, SQL: `sql/scd2_dim_vendor.sql`.
"""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.vendor_ingestion import ingest_vendor_data, load_dim_vendor


@dag(
    schedule="10 1 * * *",               # 01:10 daily, before the trip load at 02:00
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "dimension", "scd2"],
)
def vendor_dim():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def ingest_vendor() -> int:
        return ingest_vendor_data()

    @task
    def load_dim() -> dict:
        return load_dim_vendor()

    create_tables() >> ingest_vendor() >> load_dim()


vendor_dim()
