# Official Airflow image + the Python libraries our ETL code needs.
FROM apache/airflow:3.3.2

COPY requirements.txt /tmp/requirements.txt
# Re-pinning apache-airflow stops pip from upgrading/downgrading Airflow itself.
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" -r /tmp/requirements.txt
