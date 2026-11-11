"""Daily trip load: daily parquet -> clean -> bronze.stg_taxi_trips -> silver.fact_taxi_trips.
The day comes from take_d_1_date(). Run the dimension DAGs first."""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.fact_ingestion import load_fact_taxi_trips
from data_ingestion.raw_data_ingestion import ingest_data


@dag(
    schedule="0 2 * * *",                # 02:00 every day
    start_date=datetime(2026, 1, 1),
    catchup=False,                       # no backfill
    max_active_runs=1,                   # one load at a time
    default_args={"retries": 1, "retry_delay": timedelta(minutes=5)},
    doc_md=__doc__,
    tags=["nyc-taxi", "ingestion"],
)
def taxi_daily_etl():

    @task
    def create_tables() -> None:
        create_schema()

    @task
    def ingest_raw_data() -> dict:
        return ingest_data()

    @task
    def load_fact() -> dict:
        return load_fact_taxi_trips()

    create_tables() >> ingest_raw_data() >> load_fact()


taxi_daily_etl()
