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

# Count entries first
count=$(wc -l < "$DATAFILE")
jq -r '"Event ID: \(.id)\nEvent Type: \(.type)\nEvent Timestamp: \(.created_at)\nActor ID: \(.actor.id)\nActor Name: \(.actor.display_login)\nRepo ID: \(.repo.id)\nRepo Name: \(.repo.name)\n"' "$DATAFILE"

finish