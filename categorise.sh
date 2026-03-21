#!/bin/bash

# Data file to sort through
DATAFILE="GitHubJanuary.json"

# Run performed 2026-02-19 analysed 137019 entries, 2609799 ms elapsed time

# Ensure dependencies are present
function checkDependencies() {
  if ! command -v jq &> /dev/null; then
    echo "jq command is not present. Please install command or run in Colab"
    exit 1
  fi
}
checkDependencies

# Early exit
trap finish INT
function finish() {
  time_end=$(date +%s%N)
  time_elapsed_ms=$(((time_end-time_start)/1000000))
  echo ""
  echo "====="
  echo "Entries analysed: $count"
  echo "Elapsed time: $time_elapsed_ms ms"
  exit 0
}

# Initialise counting variables
time_start=$(date +%s%N)

# Count event types in one pass using jq group_by (use -s for NDJSON)
counts=$(jq -rs 'group_by(.type) | map({type: .[0].type, count: length}) | .[] | "\(.type) \(.count)"' "$DATAFILE")

push_count=$(echo "$counts" | grep '^PushEvent ' | cut -d' ' -f2)
pr_count=$(echo "$counts" | grep '^PullRequestEvent ' | cut -d' ' -f2)
other_count=$(echo "$counts" | grep -v '^PushEvent ' | grep -v '^PullRequestEvent ' | awk '{sum+=$2} END {print sum}')

# Count bot vs human users
total_events=$(jq -rs 'length' "$DATAFILE")
bot_count=$(jq -rs '[.[] | select(.actor.login | contains("[bot]"))] | length' "$DATAFILE")
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

# Update count for finish output
count=$total_events

finish