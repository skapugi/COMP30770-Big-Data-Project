#!/usr/bin/env python3

import glob
import gzip
import json
import time
import math
import re

from pyspark import SparkContext

def truncate_2_decimals(value):
    """Truncate to 2 decimal places (like bc with scale=2)"""
    return math.trunc(value * 100) / 100

# Data files
DATADIR = "data"
BOTFILE = "bots.txt"
DATES = ["2025-02-11", "2025-04-08", "2025-06-10", "2025-08-12", "2025-10-14", "2025-12-09"]


def main():
    time_start = time.time()

    # Initialize Spark Context with local mode
    sc = SparkContext(appName="GitHubEventAnalysis")
    sc.setLogLevel("ERROR")

    # Load bots.txt and broadcast
    with open(BOTFILE) as f:
        bots_set = set(line.strip() for line in f)
    bots_bc = sc.broadcast(bots_set)

    # Load JSON data - read all .json.gz files from data directory
    # Extract event_date from filename (e.g. data/2025-02-11.json.gz -> 2025-02-11)
    gz_files = glob.glob(f"{DATADIR}/*.json.gz")
    date_pattern = re.compile(r'/(\d{4}-\d{2}-\d{2})\.json\.gz$')
    events = []
    for f in gz_files:
        m = date_pattern.search(f)
        event_date = m.group(1) if m else None
        if event_date is None:
            continue
        with gzip.open(f, 'rt', encoding='utf-8') as fp:
            for line in fp:
                event = json.loads(line)
                event['_event_date'] = event_date
                events.append(event)
    events_rdd = sc.parallelize(events)

    print("")
    print("===== PER-DAY ANALYSIS =====")

    # Per-day analysis
    for date in DATES:
        date_events = events_rdd.filter(lambda e: e.get("_event_date") == date)
        total = date_events.count()
        push = date_events.filter(lambda e: e.get("type") == "PushEvent").count()
        pr = date_events.filter(lambda e: e.get("type") == "PullRequestEvent").count()
        other = total - push - pr

        if pr > 0:
            ratio = truncate_2_decimals(push / pr)
            ratio_str = f"{ratio:.2f}" if ratio >= 1 else f"{ratio:.2f}".lstrip("0")
        else:
            ratio_str = "N/A"

        print(f"{date}: PushEvent={push} | PullRequestEvent={pr} | Other={other} | Ratio={ratio_str}:1")

    print("")
    print("===== OVERALL ANALYSIS =====")

    # === Overall Event Type Analysis ===
    type_counts = events_rdd.map(lambda e: e.get("type")).countByValue()

    push_count = type_counts.get("PushEvent", 0)
    pr_count = type_counts.get("PullRequestEvent", 0)
    other_count = sum(v for k, v in type_counts.items()
                      if k not in ["PushEvent", "PullRequestEvent"])
    total_events = push_count + pr_count + other_count

    ratio = push_count / pr_count if pr_count > 0 else 0
    ratio = truncate_2_decimals(ratio)
    ratio_str = f"{ratio:.2f}" if ratio >= 1 else f"{ratio:.2f}".lstrip("0")

    print("=== Event Type Analysis ===")
    print(f"PushEvent: {push_count}")
    print(f"PullRequestEvent: {pr_count}")
    print(f"Other: {other_count}")
    print(f"Ratio (PushEvent:PullRequestEvent) = {ratio_str}:1")

    # === Bot vs Human Analysis ===
    def is_bot(event):
        login = event.get("actor", {}).get("login", "")
        return login in bots_bc.value or "[bot]" in login

    bot_count = events_rdd.filter(is_bot).count()
    human_count = total_events - bot_count

    bot_ratio = bot_count / human_count if human_count > 0 else 0
    bot_ratio = truncate_2_decimals(bot_ratio)
    bot_ratio_str = f"{bot_ratio:.2f}" if bot_ratio >= 1 else f"{bot_ratio:.2f}".lstrip("0")

    print("")
    print("=== Bot vs Human Analysis ===")
    print(f"Bot users: {bot_count}")
    print(f"Human users: {human_count}")
    print(f"Ratio (Bot:Human) = {bot_ratio_str}:1")

    # Timing
    time_end = time.time()
    time_elapsed_ms = int((time_end - time_start) * 1000)

    print("")
    print("=====")
    print(f"Total entries analysed: {total_events}")
    print(f"Total elapsed time: {time_elapsed_ms} ms")

    sc.stop()


if __name__ == "__main__":
    main()
