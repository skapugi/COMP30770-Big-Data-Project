#!/bin/bash

BOTFILE="bots.txt"
DATES="2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09"

# Ensure dependencies are present
function checkDependencies() {
  if ! command -v jq &> /dev/null; then
    echo "jq command is not present. Please install command or run in Colab"
    exit 1
  fi
}
checkDependencies

total_start=$(date +%s%N)
total_events_all=0

for date in $DATES; do
  DATAFILE="${date}.json.gz"

  if [ ! -f "$DATAFILE" ]; then
    echo "File not found: $DATAFILE, skipping."
    continue
  fi

  echo "===== $date ====="
  time_start=$(date +%s%N)

  # Count event types in one pass using jq group_by (use -s for NDJSON)
  counts=$(gunzip -c "$DATAFILE" | jq -rs 'group_by(.type) | map({type: .[0].type, count: length}) | .[] | "\(.type) \(.count)"')

  push_count=$(echo "$counts" | grep '^PushEvent ' | cut -d' ' -f2)
  pr_count=$(echo "$counts" | grep '^PullRequestEvent ' | cut -d' ' -f2)
  other_count=$(echo "$counts" | grep -v '^PushEvent ' | grep -v '^PullRequestEvent ' | awk '{sum+=$2} END {print sum}')

  # Count bot vs human users
  total_events=$(gunzip -c "$DATAFILE" | jq -rs 'length')
  # Get all actor logins, find unique bot logins, then count their events
  all_logins=$(gunzip -c "$DATAFILE" | jq -rs '.[] | .actor.login')
  # Get unique bot logins (combining bots.txt and [bot] pattern) - sorted and deduplicated
  unique_bot_logins=$( (echo "$all_logins" | grep -F -f $BOTFILE; echo "$all_logins" | grep '\[bot\]') | sort -u | grep -v '^$' )
  # Count events from bot accounts using grep -F with all unique bot logins at once
  bot_count=$(echo "$all_logins" | grep -F -f <(echo "$unique_bot_logins") -c)
  human_count=$((total_events - bot_count))
  bot_ratio=$(awk "BEGIN {printf \"%.2f\", $bot_count / $human_count}")

  # Calculate ratio (as fraction)
  ratio=$(awk "BEGIN {printf \"%.2f\", $push_count / $pr_count}")

  # Output results
  echo "PushEvent: $push_count"
  echo "PullRequestEvent: $pr_count"
  echo "Other: $other_count"
  echo "Ratio (PushEvent:PullRequestEvent) = $ratio:1"
  echo "---"
  echo "Bot users: $bot_count"
  echo "Human users: $human_count"
  echo "Ratio (Bot:Human) = $bot_ratio:1"

  time_end=$(date +%s%N)
  time_elapsed_ms=$(((time_end-time_start)/1000000))
  echo "Entries analysed: $total_events"
  echo "Elapsed time: $time_elapsed_ms ms"
  echo ""

  total_events_all=$((total_events_all + total_events))
done

total_end=$(date +%s%N)
total_elapsed_ms=$(((total_end-total_start)/1000000))
echo "===== TOTAL ====="
echo "Total entries analysed: $total_events_all"
echo "Total elapsed time: $total_elapsed_ms ms"
