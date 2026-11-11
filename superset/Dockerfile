# Superset + PostgreSQL driver
FROM apache/superset:6.1.0

USER root
# packages live in /app/.venv
RUN . /app/.venv/bin/activate && uv pip install --no-cache psycopg2-binary
USER superset
