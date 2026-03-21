#!/bin/bash

# Data files to sort through
DATAFILE="GitHubJanuary.json"
BOTFILE="bots.txt"
DB="analysis.db"
CSV="events.csv"

# Remove generated files
function cleanup() {
  rm -f "$DB"
  rm -f "$CSV"
}
cleanup

# Early exit
trap finish INT
function finish() {
  time_end=$(date +%s%N)
  time_elapsed_ms=$(((time_end-time_start)/1000000))
  echo ""
  echo "====="
  echo "Entries analysed: $count"
  echo "Elapsed time: $time_elapsed_ms ms"

  cleanup

  exit 0
}

# Initialise counting variables
time_start=$(date +%s%N)

# Create tables
sqlite3 "$DB" <<EOF
CREATE TABLE events (
    id TEXT,
    type TEXT,
    actor_login TEXT,
    repo_name TEXT
);

CREATE TABLE bots (
    login TEXT PRIMARY KEY
);
EOF

# Import bots from bots.txt - insert each line as a login
while IFS= read -r bot; do
    sqlite3 "$DB" "INSERT OR IGNORE INTO bots (login) VALUES ('$bot')"
done < "$BOTFILE"

# Import events from JSON - each line is a JSON object. Use jq to extract fields into CSV format for import
jq -r '[.id, .type, .actor.login, .repo.name] | @csv' "$DATAFILE" > $CSV
sqlite3 "$DB" <<EOF
.mode csv events
.import $CSV events
EOF

# Get specific counts for ratio calculation
push_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE type = 'PushEvent'")
pr_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE type = 'PullRequestEvent'")
other_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE type NOT IN ('PushEvent', 'PullRequestEvent')")
ratio=$(echo "scale=2; $push_count / $pr_count" | bc)

echo "=== Event Type Analysis ==="
echo "PushEvent: $push_count"
echo "PullRequestEvent: $pr_count"
echo "Other: $other_count"
echo "Ratio (PushEvent:PullRequestEvent) = $ratio:1"

# Get counts for ratio
total_events=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events")

# Count bots (from bots.txt + any with [bot] in login)
bot_count=$(sqlite3 "$DB" "
    WITH all_bots AS (
        SELECT login FROM bots
        UNION
        SELECT actor_login FROM events WHERE actor_login LIKE '%[bot]%'
    )
    SELECT COUNT(*) FROM events WHERE actor_login IN (SELECT login FROM all_bots)")
human_count=$((total_events - bot_count))
bot_ratio=$(echo "scale=2; $bot_count / $human_count" | bc)

echo ""
echo "=== Bot vs Human Analysis ==="
echo "Bot users: $bot_count"
echo "Human users: $human_count"
echo "Ratio (Bot:Human) = $bot_ratio:1"

finish