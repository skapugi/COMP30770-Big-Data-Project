#!/bin/bash

BOTFILE="bots.txt"
DATES="2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09"
DB="analysis.db"
CSV="events.csv"

# Remove generated files
function cleanup() {
  rm -f "$DB"
  rm -f "$CSV"
}

total_start=$(date +%s%N)
total_events_all=0

for date in $DATES; do
  DATAFILE="${date}.json.gz"

  if [ ! -f "$DATAFILE" ]; then
    echo "File not found: $DATAFILE, skipping."
    continue
  fi

  echo "===== $date ====="
  cleanup
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
  gunzip -c "$DATAFILE" | jq -r '[.id, .type, .actor.login, .repo.name] | @csv' > $CSV
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

  time_end=$(date +%s%N)
  time_elapsed_ms=$(((time_end-time_start)/1000000))
  echo ""
  echo "Entries analysed: $total_events"
  echo "Elapsed time: $time_elapsed_ms ms"
  echo ""

  total_events_all=$((total_events_all + total_events))
  cleanup
done

total_end=$(date +%s%N)
total_elapsed_ms=$(((total_end-total_start)/1000000))
echo "===== TOTAL ====="
echo "Total entries analysed: $total_events_all"
echo "Total elapsed time: $total_elapsed_ms ms"
