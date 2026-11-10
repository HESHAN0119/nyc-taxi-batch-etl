# NYC Taxi Batch ETL

Batch ETL pipeline for NYC Yellow Taxi trips (January and February 2023):

```
TLC parquet (curl) -> daily files -> clean (pandas) -> bronze -> silver (star schema) -> gold (views) -> Superset
```

| Layer | Schema | Contents |
|---|---|---|
| Bronze | `bronze` | Cleaned trips and reference data, as loaded (`stg_*` tables) |
| Silver | `silver` | Star schema: `fact_taxi_trips` + `dim_datetime`, `dim_location`, `dim_vendor`, `dim_payment_type`, `dim_rate_code` |
| Gold | `gold` | Reporting views used by the dashboard |

Stack: Docker, PostgreSQL 16, Apache Airflow 3, Apache Superset 6, Python 3.10+, Bash.

## Prerequisites

- Docker Desktop (running)
- Bash. On Windows use **Git Bash**. In PowerShell, plain `bash` starts WSL instead, so use
  `& "C:\Program Files\Git\bin\bash.exe" setup.sh`.
- Python 3.10 or newer (on Windows the `py` launcher is used if `python` is older)
- `curl`
- Free ports: 5433 (warehouse), 8888 (Airflow), 8088 (Superset). They can be changed in `.env`.

## Setup

### 1. Create the `.env` file

```bash
cp .env.example .env
```

Replace the three `<generate: ...>` values in `.env` with the output of these commands:

```bash
python -c "import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())"   # FERNET_KEY
python -c "import secrets;print(secrets.token_urlsafe(32))"                             # AIRFLOW_JWT_SECRET
python -c "import secrets;print(secrets.token_urlsafe(42))"                             # SUPERSET_SECRET_KEY
```

### 2. Run the setup script

```bash
bash setup.sh
```

It runs these steps in order and stops at the first error:

| Step | Script | What it does |
|---|---|---|
| 1 | `setup.sh` | Creates the Python virtual environment `.venv` and installs `requirements.txt` |
| 2 | `scripts/start_airflow.sh` | Builds the Airflow image if needed and starts Airflow (this also starts the warehouse database) |
| 3 | `scripts/start_postgres.sh` | Creates the database `taxi_dw` if missing and runs `sql/schema.sql` (schemas, tables, views) |
| 4 | `scripts/split_monthly_to_daily.sh` | Downloads 2023-01 and 2023-02 with curl and splits them into one file per day in `data/raw/daily/` |
| 5 | `scripts/start_superset.sh` | Builds the Superset image if needed and starts Superset |

The first run builds images and downloads data, so it takes several minutes. Running it again is safe:
running containers, existing images and downloaded files are reused, and no data is deleted.

### 3. Load the data (Airflow)

Open Airflow at http://localhost:8888. DAGs start paused: switch each one on before triggering it.

1. Load the dimensions by triggering each of these once:
   `datetime_dim`, `payment_type_dim`, `vendor_dim`, `rate_code_dim`, `location_dim`
2. Load the trips by setting the date range in `data_ingestion/custom_date_load.py`:
   ```python
   START_DATE = "2023-01-01"
   END_DATE = "2023-02-28"
   ```
   then trigger `load_custom_date`. Each day becomes its own task.

`taxi_daily_etl` is the scheduled daily load (02:00). It loads the day returned by `take_d_1_date()`
in `data_ingestion/raw_data_ingestion.py`.

### 4. Import the dataset and dashboard into Superset

Open Superset at http://localhost:8088.

1. **Datasets** -> import icon (top right) -> choose `superset/dashboard/dataset_export_20261110T170442.zip` -> **Import**.
2. **Dashboards** -> import icon (top right) -> choose `superset/dashboard/dashboard_export_20261110T160307.zip` -> **Import**.
3. When asked for the password of the **NYC Taxi DW** database, enter `DW_DB_PASSWORD` from `.env`.
4. Open **NYC Taxi - Trip Analytics**.
5. Set the date filter: the data is from 2023, and the charts default to the current month, so they show
   "No data" until a 2023 range is selected. In the **Filters** panel on the left:
   **Date** -> **Custom** -> start `2023-01-01`, end `2023-03-01` -> **Apply filters**.
   This covers January and February 2023 (the end date is not included).

If the import says the database already exists, delete the **NYC Taxi DW** connection under
**Settings -> Database Connections** and import again. The import recreates it.

## Users

Passwords are set in `.env`. The values below are the defaults from `.env.example`.

| Service | Where | Username | Password |
|---|---|---|---|
| Airflow UI | http://localhost:8888 | `admin` | `admin` (`AIRFLOW_ADMIN_PASSWORD`) |
| Superset UI | http://localhost:8088 | `admin` | `admin` (`SUPERSET_ADMIN_PASSWORD`) |
| Warehouse PostgreSQL | `localhost:5433`, database `taxi_dw` | `dw_user` | `dw_password` (`DW_DB_PASSWORD`) |
| Airflow metadata PostgreSQL | internal only (container `airflow-postgres`), database `airflow` | `airflow` | `airflow` (`AIRFLOW_DB_PASSWORD`) |
| Superset metadata PostgreSQL | internal only (container `superset-postgres`), database `superset` | `superset` | `superset` (`SUPERSET_DB_PASSWORD`) |

## Project structure

```
setup.sh                 one-command setup
docker-compose.yml       all services
requirements.txt         Python packages for the local scripts (.venv)
airflow/dags/            DAGs: one per dimension, taxi_daily_etl, load_custom_date
data_ingestion/          Python ETL code called by the DAGs
sql/                     schema.sql, dimension/fact load SQL, analytics_queries.sql
scripts/                 start scripts and the download/split script
superset/                Superset image, config and the exported dashboard (superset/dashboard/)
data/reference/          lookup CSVs (vendor, payment type, rate code, taxi zones)
```

## Design decisions and assumptions

- **Daily files:** TLC publishes monthly files only. They are split into daily files to simulate a daily feed.
  Trips with a pickup date outside their month are kept in `data/quarantine/`, not dropped.
- **Cleaning:** before loading into bronze, trips are rejected when the pickup is not on the load date,
  the dropoff is not after the pickup, the duration is over 24 h, or the fare or total amount is negative.
  Rejected rows are saved to `data/quarantine/rejected_<day>.parquet` with the reason.
- **No duplicates:** each load deletes the day it loads, then inserts it, in one transaction (bronze and silver).
  Re-running a day replaces it.
- **Slowly changing dimensions:** vendor, rate code and location are SCD Type 2 (history kept),
  payment type is SCD Type 1 (overwrite) and datetime is Type 0 (generated, never changes).
- **Reference data** is reloaded in full (truncate + load) and compared with the dimension to find new or changed rows.
- **Failures:** every DAG retries a failed task once after 5 minutes. Each load logs start/end, rows read, rejected and loaded.

## Stopping

```bash
docker compose down        # stop everything, data is kept
docker compose down -v     # stop and delete all data (databases, dashboards)
```
