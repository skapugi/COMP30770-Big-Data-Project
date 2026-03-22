#!/bin/bash

# Downloads and combines GH Archive files for the 12 second Tuesdays of 2025

DIR_DATA=data
mkdir -p "$DIR_DATA"
cd "$DIR_DATA" || exit

DB="../analysis.db"

if [ -f "$DB" ]; then
  echo "Database already exists at $DB, skipping."
  exit 0
fi

total_start=$(date +%s%N)

for date in 2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09
do
  if [ -f "${date}.json" ]; then
    echo "Skipping ${date}.json (already exists)"
    continue
  fi

  # Download all 24 hours in parallel
  echo "Downloading ${date}..."
  printf '%s\n' {0..23} | xargs -P 8 -I {} curl -sO "https://data.gharchive.org/${date}-{}.json.gz"

  # Combine into single daily file
  echo "Combining $date..."
  cat ${date}-{0..23}.json.gz > ${date}.json.gz
  gunzip ${date}.json.gz
  rm ${date}-{0..23}.json.gz
  echo "Done: ${date}.json"
done

# Import JSON data directly into SQLite database
sqlite3 "$DB" "CREATE TABLE events (
    id TEXT,
    type TEXT,
    actor_login TEXT,
    repo_name TEXT,
    event_date TEXT
);"

# Import bots list
sqlite3 "$DB" <<EOF
CREATE TABLE bots (
    login TEXT PRIMARY KEY
);
.mode list
.import "../bots.txt" bots
EOF

for date in 2025-02-11 2025-04-08 2025-06-10 2025-08-12 2025-10-14 2025-12-09
do
  echo "Importing $date..."
  { echo "BEGIN;"; jq -r '"INSERT INTO events VALUES (" + ([.id, .type, .actor.login, .repo.name, .created_at] | map(@json) | join(",")) + ");"' ${date}.json; echo "COMMIT;"; } | sqlite3 "$DB"
done

sqlite3 "$DB" "CREATE INDEX idx_events_type ON events(type);"
sqlite3 "$DB" "CREATE INDEX idx_events_actor ON events(actor_login);"

echo "Database created at $DB"

total_end=$(date +%s%N)
total_elapsed_ms=$(((total_end-total_start)/1000000))
echo ""
echo "Total elapsed time: $total_elapsed_ms ms"