"""
### NYC Taxi daily ingestion (trips)

1. `create_tables` - runs `sql/schema.sql` (creates tables if missing).
2. `ingest_raw_data` - one day of trips: `data/raw/daily/YYYY-MM/yellow_tripdata_<day>.parquet` -> `bronze.stg_taxi_trips`.
   The day is decided only in Python: `take_d_1_date()` in `data_ingestion/raw_data_ingestion.py`.
3. `load_fact` - incremental load of the same day: `bronze.stg_taxi_trips` -> `silver.fact_taxi_trips`
   (delete the day + insert it again). See `data_ingestion/fact_ingestion.py`.

Run the dimension DAGs first: the fact load needs their rows (an unknown code fails the load).

Dimensions have their own DAGs: datetime_dim, vendor_dim, payment_type_dim, rate_code_dim, location_dim.
"""

from datetime import datetime, timedelta

from airflow.sdk import dag, task

from data_ingestion.db import create_schema
from data_ingestion.fact_ingestion import load_fact_taxi_trips
from data_ingestion.raw_data_ingestion import ingest_data


@dag(
    schedule="0 2 * * *",                # 02:00 every day, after the previous day is complete
    start_date=datetime(2026, 1, 1),
    catchup=False,                       # no backfill: only today's run is scheduled
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
