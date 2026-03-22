#!/bin/bash

# Imports GH Archive daily files into a persistent SQLite database
# Uses gunzip -c streaming + CSV bulk import (no full decompression to disk)

DATES="2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09"
BOTFILE="bots.txt"
DB="analysis.db"
CSV="events_tmp.csv"

if [ -f "$DB" ]; then
  echo "Database already exists at $DB. Delete it to re-import."
  exit 0
fi

time_start=$(date +%s%N)

# Create tables
sqlite3 "$DB" <<EOF
CREATE TABLE events (
    id TEXT,
    type TEXT,
    actor_login TEXT,
    repo_name TEXT,
    event_date TEXT
);

CREATE TABLE bots (
    login TEXT PRIMARY KEY
);
EOF

# Import bots list
while IFS= read -r bot; do
    sqlite3 "$DB" "INSERT OR IGNORE INTO bots (login) VALUES ('$bot')"
done < "$BOTFILE"

# Import each daily file via streaming CSV bulk import
for date in $DATES; do
  DATAFILE="${date}.json.gz"

  if [ ! -f "$DATAFILE" ]; then
    echo "File not found: $DATAFILE, skipping."
    continue
  fi

  echo "Importing $date..."
  gunzip -c "$DATAFILE" | jq -r '[.id, .type, .actor.login, .repo.name, .created_at] | @csv' > "$CSV"
  sqlite3 "$DB" <<EOF
.mode csv events
.import $CSV events
EOF
  rm -f "$CSV"
  echo "Done: $date"
done

# Add indexes for faster querying
echo "Creating indexes..."
sqlite3 "$DB" "CREATE INDEX idx_events_type ON events(type);"
sqlite3 "$DB" "CREATE INDEX idx_events_actor ON events(actor_login);"
sqlite3 "$DB" "CREATE INDEX idx_events_date ON events(event_date);"

time_end=$(date +%s%N)
time_elapsed_ms=$(((time_end-time_start)/1000000))
total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events")
echo ""
echo "===== IMPORT COMPLETE ====="
echo "Total events imported: $total"
echo "Elapsed time: $time_elapsed_ms ms"

# Save import timing for pipeline script
echo "$time_elapsed_ms" > import_time.txt
