# Official Superset image + the PostgreSQL driver (the official "lean" image ships without DB drivers).
FROM apache/superset:6.1.0

USER root
# The image keeps its Python packages in a uv virtual env at /app/.venv.
RUN . /app/.venv/bin/activate && uv pip install --no-cache psycopg2-binary
USER superset
