#!/bin/bash

# Downloads and combines GH Archive files for the second Tuesday
# of each even-numbered month in 2025 (sequential, no parallelism)

DATES="2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09"

for date in $DATES; do
  if [ -f "${date}.json.gz" ]; then
    echo "Skipping ${date}.json.gz (already exists)"
    continue
  fi

  # Download 24 hourly files sequentially
  echo "Downloading $date..."
  for hour in {0..23}; do
    FILE="${date}-${hour}.json.gz"
    [ -f "$FILE" ] || curl -s -o "$FILE" "https://data.gharchive.org/$FILE"
  done

  # Concatenate into single daily file (gzip supports multi-stream)
  echo "Combining $date..."
  cat ${date}-{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23}.json.gz > ${date}.json.gz
  rm ${date}-{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23}.json.gz
  echo "Done: ${date}.json.gz"
done

echo "All files ready."
