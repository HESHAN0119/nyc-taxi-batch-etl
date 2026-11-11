"""Location dimension (SCD2): taxi_zone_lookup.csv -> bronze.stg_taxi_zone -> silver.dim_location."""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.location_ingestion import ingest_location_data, load_dim_location


@dag(
    schedule="30 1 * * *",               # 01:30 every day
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "dimension", "scd2"],
)
def location_dim():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def ingest_location() -> int:
        return ingest_location_data()

    @task
    def load_dim() -> dict:
        return load_dim_location()

    create_tables() >> ingest_location() >> load_dim()


location_dim()
