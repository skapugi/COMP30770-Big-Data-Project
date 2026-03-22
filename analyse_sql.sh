#!/bin/bash

DB="analysis.db"

total_start=$(date +%s%N)

echo ""
echo "===== PER-DAY ANALYSIS ====="

# Single query for all per-day stats using GROUP BY
sqlite3 "$DB" <<'EOF'
.headers off
.mode list
SELECT 'Date: ' || SUBSTR(event_date, 1, 10) || ' | PushEvent=' || SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) || ' | PullRequestEvent=' || SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) || ' | Other=' || SUM(CASE WHEN type NOT IN ('PushEvent','PullRequestEvent') THEN 1 ELSE 0 END) || ' | Ratio=' || CASE WHEN SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) > 0 THEN printf('%.2f', 1.0 * SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) / SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END)) || ':1' ELSE 'N/A' END
FROM events
GROUP BY SUBSTR(event_date, 1, 10);
EOF

echo ""
echo "===== OVERALL ANALYSIS ====="

# Overall event type analysis - single query
sqlite3 "$DB" <<'EOF'
.headers off
.mode list
SELECT '=== Event Type Analysis ===';
SELECT 'PushEvent: ' || SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) FROM events;
SELECT 'PullRequestEvent: ' || SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) FROM events;
SELECT 'Other: ' || SUM(CASE WHEN type NOT IN ('PushEvent','PullRequestEvent') THEN 1 ELSE 0 END) FROM events;
SELECT 'Ratio (PushEvent:PullRequestEvent) = ' || CASE WHEN SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END) > 0 THEN printf('%.2f', 1.0 * SUM(CASE WHEN type='PushEvent' THEN 1 ELSE 0 END) / SUM(CASE WHEN type='PullRequestEvent' THEN 1 ELSE 0 END)) || ':1' ELSE 'N/A' END FROM events;
EOF

# Build bot login list for efficient lookup
bot_logins=$(sqlite3 "$DB" "SELECT '''' || GROUP_CONCAT(login, ''',''') || '''' FROM (SELECT login FROM bots UNION SELECT actor_login FROM events WHERE actor_login LIKE '%[bot]%')")

# Overall bot vs human - optimized query
if [ -n "$bot_logins" ] && [ "$bot_logins" != "''" ]; then
    bot_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events WHERE actor_login IN ($bot_logins)")
    total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events")
    human_count=$((total - bot_count))
    if [ "$human_count" -gt 0 ]; then
        bot_ratio=$(echo "scale=2; $bot_count / $human_count" | bc)
    else
        bot_ratio="N/A"
    fi
else
    bot_count=0
    total=$(sqlite3 "$DB" "SELECT COUNT(*) FROM events")
    human_count=$total
    bot_ratio="N/A"
fi

echo ""
echo "=== Bot vs Human Analysis ==="
echo "Bot users: $bot_count"
echo "Human users: $human_count"
echo "Ratio (Bot:Human) = $bot_ratio:1"

total_end=$(date +%s%N)
total_elapsed_ms=$(((total_end-total_start)/1000000))
echo ""
echo "===== TOTAL ====="
echo "Total entries analysed: $total"
echo "Total elapsed time: $total_elapsed_ms ms"
