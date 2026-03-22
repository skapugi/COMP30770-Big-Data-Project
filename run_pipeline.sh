#!/bin/bash

# Master pipeline script
# Runs data acquisition, import, and analysis sequentially
# Measures total execution time and peak memory usage

DATES="2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09"
DB="analysis.db"
RESULTS="results.csv"

pipeline_start=$(date +%s%N)

# Step 1: Download and combine data if not already present
echo "===== STEP 1: Data Acquisition ====="
missing=0
for date in $DATES; do
  if [ ! -f "${date}.json.gz" ]; then
    missing=1
    break
  fi
done

download_start=$(date +%s%N)
if [ "$missing" -eq 1 ]; then
  bash getdata.sh
else
  echo "All data files already present, skipping download."
fi
download_end=$(date +%s%N)
download_time_ms=$(((download_end-download_start)/1000000))

# Step 2: Import into SQLite if DB not already built
echo ""
echo "===== STEP 2: Database Import ====="
if [ ! -f "$DB" ]; then
  /usr/bin/time -l bash import_data.sh 2> import_memory.txt
  import_peak_mem=$(grep "maximum resident set size" import_memory.txt | awk '{print $1}')
else
  echo "Database already exists, skipping import."
  import_peak_mem="N/A (skipped)"
fi

# Step 3: Run analysis
echo ""
echo "===== STEP 3: Analysis ====="
/usr/bin/time -l bash analyse_sql.sh 2> analyse_memory.txt | tee analysis_output.txt
analyse_peak_mem=$(grep "maximum resident set size" analyse_memory.txt | awk '{print $1}')

pipeline_end=$(date +%s%N)
pipeline_elapsed_ms=$(((pipeline_end-pipeline_start)/1000000))

echo ""
echo "===== PIPELINE COMPLETE ====="
echo "Total pipeline time: $pipeline_elapsed_ms ms"
echo "Import peak memory: $import_peak_mem bytes"
echo "Analysis peak memory: $analyse_peak_mem bytes"

# Get import time
if [ -f "import_time.txt" ]; then
  import_time_ms=$(cat import_time.txt)
else
  import_time_ms="N/A (skipped)"
fi

# Get analysis time from output
analyse_time_ms=$(grep "^Elapsed time:" analysis_output.txt | awk '{print $3}')

# Calculate processing time (import + analysis only, excludes download)
if [[ "$import_time_ms" =~ ^[0-9]+$ ]] && [[ "$analyse_time_ms" =~ ^[0-9]+$ ]]; then
  processing_time_ms=$((import_time_ms + analyse_time_ms))
else
  processing_time_ms="N/A"
fi

# Save performance summary
echo "metric,value" > "$RESULTS"
echo "download_time_ms,$download_time_ms" >> "$RESULTS"
echo "import_time_ms,$import_time_ms" >> "$RESULTS"
echo "import_peak_memory_bytes,$import_peak_mem" >> "$RESULTS"
echo "analysis_time_ms,$analyse_time_ms" >> "$RESULTS"
echo "analyse_peak_memory_bytes,$analyse_peak_mem" >> "$RESULTS"
echo "processing_time_ms,$processing_time_ms" >> "$RESULTS"
echo "total_pipeline_time_ms,$pipeline_elapsed_ms" >> "$RESULTS"

# Append per-date event type results with total row
echo "" >> "$RESULTS"
echo "date,push_events,pr_events,other_events,push_pr_ratio,total_events" >> "$RESULTS"
grep "^Date:" analysis_output.txt | grep "Push:PR" | while IFS='|' read -r date push pr other ratio total; do
  d=$(echo "$date" | sed 's/Date: //' | xargs)
  p=$(echo "$push" | sed 's/PushEvent=//' | xargs)
  pr_=$(echo "$pr" | sed 's/PullRequestEvent=//' | xargs)
  o=$(echo "$other" | sed 's/Other=//' | xargs)
  r=$(echo "$ratio" | sed 's/Push:PR Ratio=//' | xargs)
  t=$(echo "$total" | sed 's/Total=//' | xargs)
  echo "$d,$p,$pr_,$o,$r,$t" >> "$RESULTS"
done
# Total row from overall analysis line
total_line=$(grep "^Total:" analysis_output.txt | grep "Push:PR")
p=$(echo "$total_line" | grep -o 'PushEvent=[0-9]*' | cut -d= -f2)
pr_=$(echo "$total_line" | grep -o 'PullRequestEvent=[0-9]*' | cut -d= -f2)
o=$(echo "$total_line" | grep -o 'Other=[0-9]*' | cut -d= -f2)
r=$(echo "$total_line" | grep -o 'Push:PR Ratio=[0-9.]*:1' | sed 's/Push:PR Ratio=//')
t=$(echo "$total_line" | grep -o 'Total=[0-9]*' | cut -d= -f2)
echo "TOTAL,$p,$pr_,$o,$r,$t" >> "$RESULTS"

# Append per-date bot vs human results with total row
echo "" >> "$RESULTS"
echo "date,bot_events,human_events,bot_human_ratio" >> "$RESULTS"
grep "^Date:" analysis_output.txt | grep "Bot:Human" | while IFS='|' read -r date bot human ratio; do
  d=$(echo "$date" | sed 's/Date: //' | xargs)
  b=$(echo "$bot" | sed 's/Bot=//' | xargs)
  h=$(echo "$human" | sed 's/Human=//' | xargs)
  r=$(echo "$ratio" | sed 's/Bot:Human Ratio=//' | xargs)
  echo "$d,$b,$h,$r" >> "$RESULTS"
done
# Total row from overall bot line
bot_line=$(grep "^Total:" analysis_output.txt | grep "Bot:Human")
b=$(echo "$bot_line" | grep -o 'Bot=[0-9]*' | cut -d= -f2)
h=$(echo "$bot_line" | grep -o 'Human=[0-9]*' | cut -d= -f2)
r=$(echo "$bot_line" | grep -o 'Bot:Human Ratio=[0-9.]*:1' | sed 's/Bot:Human Ratio=//')
echo "TOTAL,$b,$h,$r" >> "$RESULTS"

echo ""
echo "Results saved to $RESULTS"
