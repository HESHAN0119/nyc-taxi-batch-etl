#!/usr/bin/env bash
# Set up the project: Python venv, Airflow, warehouse database, taxi data, Superset.
#
#   bash setup.sh
#
# Safe to run again: each step skips what is already done. Stops at the first error.

set -e

cd "$(dirname "$0")"

# Find a Python 3.10+ ("py -3" is the Windows launcher; plain "python" may be an older version).
find_python() {
    for candidate in "py -3" python3 python; do
        if $candidate -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" > /dev/null 2>&1; then
            echo "$candidate"
            return
        fi
    done
}

echo "===== 1/5  Python virtual environment ====="
if [ -d .venv ]; then
    echo ".venv already exists."
else
    PYTHON="$(find_python)"
    if [ -z "$PYTHON" ]; then
        echo "Python 3.10 or newer is required. Install it and run setup.sh again."
        exit 1
    fi
    echo "Creating .venv with: $PYTHON ($($PYTHON --version))"
    $PYTHON -m venv .venv
fi

# The venv keeps python in Scripts/ on Windows and in bin/ on Linux/macOS.
if [ -f .venv/Scripts/python.exe ]; then
    VENV_PYTHON=".venv/Scripts/python.exe"
else
    VENV_PYTHON=".venv/bin/python"
fi
echo "Installing requirements.txt..."
"$VENV_PYTHON" -m pip install --quiet --upgrade pip
"$VENV_PYTHON" -m pip install --quiet -r requirements.txt

echo
echo "===== 2/5  Airflow ====="
bash scripts/start_airflow.sh

echo
echo "===== 3/5  Warehouse database (Postgres) ====="
bash scripts/start_postgres.sh

echo
echo "===== 4/5  Taxi data: download (curl) + split into daily files ====="
bash scripts/split_monthly_to_daily.sh

echo
echo "===== 5/5  Superset ====="
bash scripts/start_superset.sh

echo
echo "Setup finished."
echo "  Airflow:   http://localhost:8888"
echo "  Superset:  http://localhost:8088"
echo "  Warehouse: localhost:5433"
