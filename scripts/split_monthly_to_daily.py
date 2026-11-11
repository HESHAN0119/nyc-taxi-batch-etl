"""Downloads the taxi months (MONTHS) with curl and splits them into daily parquet files.
Monthly files and out-of-range trips go to data/quarantine, daily files to data/raw/daily."""

import subprocess
from pathlib import Path

import pandas as pd

MONTHS = ["2023-01", "2023-02"]

PROJECT_ROOT = Path(__file__).resolve().parents[1]
QUARANTINE_DIR = PROJECT_ROOT / "data" / "quarantine"
DAILY_DIR = PROJECT_ROOT / "data" / "raw" / "daily"
DOWNLOAD_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{month}.parquet"


def download_month(month: str) -> Path:
    "downloads the month with curl (skips if already downloaded)"
    QUARANTINE_DIR.mkdir(parents=True, exist_ok=True)
    monthly_file = QUARANTINE_DIR / f"yellow_tripdata_{month}.parquet"

    if monthly_file.exists():
        print(f"Already downloaded: {monthly_file.name}")
        return monthly_file

    url = DOWNLOAD_URL.format(month=month)
    print(f"Downloading {url}")
    subprocess.run(["curl", "-fL", "-o", str(monthly_file), url], check=True)
    return monthly_file


def split_into_days(monthly_file: Path, month: str) -> None:
    "writes one parquet file per pickup day"
    trips = pd.read_parquet(monthly_file)
    print(f"Read {len(trips):,} trips from {monthly_file.name}")

    # keep only trips of this month
    first_day = pd.Timestamp(f"{month}-01")
    next_month = first_day + pd.offsets.MonthBegin(1)
    pickup = trips["tpep_pickup_datetime"]
    in_month = (pickup >= first_day) & (pickup < next_month)

    out_of_range = trips[~in_month]
    if len(out_of_range) > 0:
        out_file = QUARANTINE_DIR / f"yellow_tripdata_{month}_out_of_range.parquet"
        out_of_range.to_parquet(out_file, index=False)
        print(f"{len(out_of_range):,} trips outside {month} saved to {out_file.name}")

    month_dir = DAILY_DIR / month
    month_dir.mkdir(parents=True, exist_ok=True)

    trips = trips[in_month]
    for day, day_trips in trips.groupby(trips["tpep_pickup_datetime"].dt.date):
        day_trips.to_parquet(month_dir / f"yellow_tripdata_{day}.parquet", index=False)

    days = trips["tpep_pickup_datetime"].dt.date.nunique()
    print(f"Wrote {days} daily files ({len(trips):,} trips) to {month_dir}")


if __name__ == "__main__":
    for month in MONTHS:
        monthly_file = download_month(month)
        split_into_days(monthly_file, month)
