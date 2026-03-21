#!/bin/bash

# Downloads hourly GH Archive files for the 12 second Tuesdays of 2025
# Files are saved in the current directory

for date in 2025-01-14 2025-02-11 2025-03-11 2025-04-08 2025-05-13 2025-06-10 2025-07-08 2025-08-12 2025-09-09 2025-10-14 2025-11-11 2025-12-09
do
  for hour in {0..23}
  do
    wget -nc https://data.gharchive.org/${date}-${hour}.json.gz
  done
done
