#!/bin/bash

# Concatenates 24 hourly files into a single daily file for each date
# Run this after download_data.sh

for date in 2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09
do
  echo "Combining $date..."
  cat ${date}-{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23}.json.gz > ${date}.json.gz
  echo "Done: ${date}.json.gz"
done
