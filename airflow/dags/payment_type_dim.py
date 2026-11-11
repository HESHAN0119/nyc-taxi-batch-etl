"""Payment type dimension (SCD1): payment_type.csv -> bronze.stg_payment_type -> silver.dim_payment_type."""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.payment_type_ingestion import ingest_payment_type_data, load_dim_payment_type


@dag(
    schedule="0 1 * * *",                # 01:00 every day
    start_date=datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "dimension", "scd1"],
)
def payment_type_dim():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def ingest_payment_type() -> int:
        return ingest_payment_type_data()

    @task
    def load_dim() -> int:
        return load_dim_payment_type()

    create_tables() >> ingest_payment_type() >> load_dim()


payment_type_dim()
