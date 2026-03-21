# GH Archive — 2025 Second Tuesdays

GitHub event data from [GH Archive](https://www.gharchive.org/) for the second Tuesday of each month in 2025.

## Dates covered

- 2025-01-14, 2025-02-11, 2025-03-11, 2025-04-08, 2025-05-13, 2025-06-10
- 2025-07-08, 2025-08-12, 2025-09-09, 2025-10-14, 2025-11-11, 2025-12-09

## Setup

Raw data files are not stored in this repo. Run the scripts below to download and prepare them locally.

### 1. Download hourly files

```bash
bash download_data.sh
```

Downloads 24 hourly `.json.gz` files per date (~288 files total) from GH Archive.

### 2. Combine into daily files

```bash
bash combine_days.sh
```

Concatenates the 24 hourly files for each date into a single `YYYY-MM-DD.json.gz` file (~12 files, 1.8–2.9 GB each).

## Data format

Each file contains newline-delimited JSON. Each line is a GitHub event. See the [GH Archive schema](https://www.gharchive.org/#schema) for field descriptions.
