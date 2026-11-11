# Airflow + our Python packages
FROM apache/airflow:3.3.2

COPY requirements.txt /tmp/requirements.txt
# pin Airflow so pip does not change its version
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" -r /tmp/requirements.txt
