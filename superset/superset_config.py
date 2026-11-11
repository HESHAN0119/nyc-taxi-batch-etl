# Superset settings (values from .env)
import os

# required by Superset
SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Superset metadata database
SQLALCHEMY_DATABASE_URI = os.environ["SUPERSET_METADATA_DB_URI"]
