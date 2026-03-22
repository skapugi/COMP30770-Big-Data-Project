# Big Data Repository

Development repository for UCD Big Data project.

# GH Archive — 2025 Second Tuesdays

GitHub event data from [GH Archive](https://www.gharchive.org/) for the second Tuesday of each month in 2025.

## Dates covered

Second Tuesday of each even-numbered month in 2025:

- 2025-02-11, 2025-04-08, 2025-06-10, 2025-08-12, 2025-10-14, 2025-12-09

## Setup

Raw data files are not stored in this repo. Run the scripts below to download and prepare them locally.

### 1. Download necessary data

```bash
bash getdata.sh
```

Downloads 6 * 24 hourly 'json.gz' files per date from GH Archive.
Data is then imported into a SQLite database, "analysis.db"

## Data format

Each file contains newline-delimited JSON. Each line is a GitHub event. See the [GH Archive schema](https://www.gharchive.org/#schema) for field descriptions.
