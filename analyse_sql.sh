#!/bin/bash

# Runs analytical queries on the pre-built SQLite database
# Measures execution time and peak memory usage

DB="analysis.db"

if [ ! -f "$DB" ]; then
  echo "Database not found. Run import_data.sh first."
  exit 1
fi

total_start=$(date +%s%N)

echo ""
echo "===== PER-DAY ANALYSIS ====="

# Event type counts and push:PR ratio per date
sqlite3 "$DB" <<'EOF'
.headers off
.mode list
SELECT
  'Date: ' || SUBSTR(event_date, 1, 10) ||
  ' | PushEvent=' || SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) ||
  ' | PullRequestEvent=' || SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) ||
  ' | Other=' || SUM(CASE WHEN type NOT IN ('PushEvent','PullRequestEvent') THEN 1 ELSE 0 END) ||
  ' | Push:PR Ratio=' || CASE
    WHEN SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) > 0
    THEN printf('%.2f', 1.0 * SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) /
         SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END)) || ':1'
    ELSE 'N/A' END ||
  ' | Total=' || COUNT(*)
FROM events
GROUP BY SUBSTR(event_date, 1, 10);
EOF

echo ""
echo "===== PER-DAY BOT VS HUMAN ANALYSIS ====="

sqlite3 "$DB" <<'EOF'
.headers off
.mode list
WITH all_bots AS (
    SELECT login FROM bots
    UNION
    SELECT actor_login FROM events WHERE actor_login LIKE '%[bot]%'
)
SELECT
  'Date: ' || SUBSTR(event_date, 1, 10) ||
  ' | Bot=' || SUM(CASE WHEN actor_login IN (SELECT login FROM all_bots) THEN 1 ELSE 0 END) ||
  ' | Human=' || SUM(CASE WHEN actor_login NOT IN (SELECT login FROM all_bots) THEN 1 ELSE 0 END) ||
  ' | Bot:Human Ratio=' || printf('%.2f',
    1.0 * SUM(CASE WHEN actor_login IN (SELECT login FROM all_bots) THEN 1 ELSE 0 END) /
    SUM(CASE WHEN actor_login NOT IN (SELECT login FROM all_bots) THEN 1 ELSE 0 END)) || ':1'
FROM events
GROUP BY SUBSTR(event_date, 1, 10);
EOF

echo ""
echo "===== OVERALL EVENT TYPE ANALYSIS ====="

sqlite3 "$DB" <<'EOF'
.headers off
.mode list
SELECT 'Total: PushEvent=' || SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) ||
  ' | PullRequestEvent=' || SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) ||
  ' | Other=' || SUM(CASE WHEN type NOT IN ('PushEvent','PullRequestEvent') THEN 1 ELSE 0 END) ||
  ' | Push:PR Ratio=' || printf('%.2f',
    1.0 * SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) /
    SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END)) || ':1' ||
  ' | Total=' || COUNT(*) FROM events;
EOF

echo ""
echo "===== OVERALL BOT VS HUMAN ANALYSIS ====="

bot_count=$(sqlite3 "$DB" "
    WITH all_bots AS (
        SELECT login FROM bots
        UNION
        SELECT actor_login FROM events WHERE actor_login LIKE '%[bot]%'
    )
    SELECT COUNT(*) FROM events WHERE actor_login IN (SELECT login FROM all_bots);")

total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events")
human_count=$((total - bot_count))
bot_ratio=$(printf '%.2f' $(echo "scale=4; $bot_count / $human_count" | bc))

echo "Total: Bot=$bot_count | Human=$human_count | Bot:Human Ratio=$bot_ratio:1"

total_end=$(date +%s%N)
total_elapsed_ms=$(((total_end-total_start)/1000000))
echo ""
echo "===== TOTAL ====="
echo "Total entries analysed: $total"
echo "Elapsed time: $total_elapsed_ms ms"
