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
count=0

# Parse Json
while IFS= read -r line; do
    if [ -n "$line" ]; then
        # General Information
        event_id="$(jq -r '.id' <<<"$line")"
        event_type="$(jq -r '.type' <<<"$line")"
        event_timestamp="$(jq -r '.created_at' <<<"$line")"

        # Actor Information
        actor_id="$(jq -r '.actor.id' <<<"$line")"
        actor_name="$(jq -r '.actor.display_login' <<<"$line")"

        # Repository Information
        repo_id="$(jq -r '.repo.id' <<<"$line")"
        repo_name="$(jq -r '.repo.name' <<<"$line")"

        echo ""
        echo "Event ID: $event_id"
        echo "Event Type: $event_type"
        echo "Event Timestamp: $event_timestamp"
        echo "Actor ID: $actor_id"
        echo "Actor Name: $actor_name"
        echo "Repo ID: $repo_id"
        echo "Repo Name: $repo_name"

        ((count++))
    fi
done < "$DATAFILE"

finish