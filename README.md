# Big Data Repository

Development repository for UCD Big Data project.

# GH Archive — 2025 Second Tuesdays

GitHub event data from [GH Archive](https://www.gharchive.org/) for the second Tuesday of each even-numbered month in 2025.

## Dates covered

- 2025-02-11, 2025-04-08, 2025-06-10, 2025-08-12, 2025-10-14, 2025-12-09

## Setup

Raw data files are not stored in this repo. Run the scripts below to download, import, and analyse the data.

### Option 1: Run the full pipeline (recommended)

```bash
bash run_pipeline.sh
```

Runs all steps sequentially: download, import, and analysis. Saves results to `results.csv`.

### Option 2: Run steps individually

#### 1. Download and combine hourly files
```bash
bash getdata.sh
```
Downloads 144 hourly `.json.gz` files sequentially and combines them into 6 daily files.

#### 2. Import into SQLite database
```bash
bash import_data.sh
```
Streams each daily file into a persistent SQLite database (`analysis.db`) using CSV bulk import. Adds indexes for fast querying.

#### 3. Run analysis
```bash
bash analyse_sql.sh
```
Runs SQL queries to analyse event type distribution (Push vs PR) and bot vs human activity per date and overall.

## Data format

Each file contains newline-delimited JSON. Each line is a GitHub event. See the [GH Archive schema](https://www.gharchive.org/#schema) for field descriptions.
