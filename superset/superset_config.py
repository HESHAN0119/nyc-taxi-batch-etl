# Superset settings, loaded via SUPERSET_CONFIG_PATH (see docker-compose.yml). Values come from .env.
import os

# Signs session cookies and encrypts saved database passwords. Superset refuses to start without it.
SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Superset's own metadata (users, charts, dashboards) lives in the superset-postgres container.
SQLALCHEMY_DATABASE_URI = os.environ["SUPERSET_METADATA_DB_URI"]
