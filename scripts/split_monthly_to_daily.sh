#!/usr/bin/env bash
# Download the taxi months (MONTHS in split_monthly_to_daily.py) and split them into daily files.
# Uses the project's virtual environment (.venv), created by setup.sh.

set -e

cd "$(dirname "$0")/.."

# The venv keeps python in Scripts/ on Windows and in bin/ on Linux/macOS.
if [ -f .venv/Scripts/python.exe ]; then
    VENV_PYTHON=".venv/Scripts/python.exe"
elif [ -f .venv/bin/python ]; then
    VENV_PYTHON=".venv/bin/python"
else
    echo "No virtual environment found. Run: bash setup.sh"
    exit 1
fi

"$VENV_PYTHON" scripts/split_monthly_to_daily.py
