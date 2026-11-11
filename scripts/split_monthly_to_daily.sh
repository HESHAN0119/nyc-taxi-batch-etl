#!/usr/bin/env bash
# Downloads the months and splits them into daily files (uses .venv).

set -e

cd "$(dirname "$0")/.."

# Scripts/ on Windows, bin/ on Linux/macOS
if [ -f .venv/Scripts/python.exe ]; then
    VENV_PYTHON=".venv/Scripts/python.exe"
elif [ -f .venv/bin/python ]; then
    VENV_PYTHON=".venv/bin/python"
else
    echo "No virtual environment found. Run: bash setup.sh"
    exit 1
fi

"$VENV_PYTHON" scripts/split_monthly_to_daily.py
