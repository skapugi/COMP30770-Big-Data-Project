import json
import time
from collections import defaultdict
from pyspark import SparkConf, SparkContext

start = time.time()

conf = SparkConf().setAppName("GitHub Analysis")
sc = SparkContext(conf=conf)
sc.setLogLevel("ERROR")

with open("bots.txt") as f:
    bot_set = set(line.strip() for line in f if line.strip())
bot_set_bc = sc.broadcast(bot_set)

lines = sc.textFile("data/*.json")

def parse_jsons(line):
    decoder = json.JSONDecoder()
    results = []
    s = line.strip()
    while s:
        try:
            obj, end = decoder.raw_decode(s)
            results.append(obj)
            s = s[end:].lstrip()
        except json.JSONDecodeError:
            break
    return results

# Map + Filter + Reduce: count PushEvent and PullRequestEvent per day
day_counts = lines \
    .flatMap(parse_jsons) \
    .filter(lambda obj: obj["type"] in ("PushEvent", "PullRequestEvent")) \
    .map(lambda obj: ((obj["created_at"][:10], obj["type"]), 1)) \
    .reduceByKey(lambda a, b: a + b)

result = day_counts.collect()
by_date = defaultdict(lambda: {"PushEvent": 0, "PullRequestEvent": 0})
for (date, event_type), count in result:
    by_date[date][event_type] = count

print(f"\n===== PER-DAY EVENT ANALYSIS =====")
for date in sorted(by_date):
    push = by_date[date]["PushEvent"]
    pr = by_date[date]["PullRequestEvent"]
    ratio = f"{push / pr:.2f}:1" if pr > 0 else "N/A"
    print(f"Date: {date} | PushEvent={push} | PullRequestEvent={pr} | Push:PR Ratio={ratio}")

print(f"\n===== OVERALL EVENT ANALYSIS =====")
total_push = sum(d["PushEvent"] for d in by_date.values())
total_pr = sum(d["PullRequestEvent"] for d in by_date.values())
total_ratio = f"{total_push / total_pr:.2f}:1" if total_pr > 0 else "N/A"
print(f"PushEvent: {total_push}")
print(f"PullRequestEvent: {total_pr}")
print(f"Push:PR Ratio: {total_ratio}")

# Map + Reduce: count bot vs human events per day
day_bot_counts = lines \
    .flatMap(parse_jsons) \
    .map(lambda obj: ((obj["created_at"][:10], "Bot" if "[bot]" in obj["actor"]["login"] or obj["actor"]["login"] in bot_set_bc.value else "Human"), 1)) \
    .reduceByKey(lambda a, b: a + b)

bot_result = day_bot_counts.collect()
bot_by_date = defaultdict(lambda: {"Bot": 0, "Human": 0})
for (date, category), count in bot_result:
    bot_by_date[date][category] = count

print(f"\n===== PER-DAY BOT VS HUMAN ANALYSIS =====")
for date in sorted(bot_by_date):
    bot = bot_by_date[date]["Bot"]
    human = bot_by_date[date]["Human"]
    ratio = f"{bot / human:.2f}:1" if human > 0 else "N/A"
    print(f"Date: {date} | Bot={bot} | Human={human} | Bot:Human Ratio={ratio}")

print(f"\n===== OVERALL BOT VS HUMAN ANALYSIS =====")
total_bot = sum(d["Bot"] for d in bot_by_date.values())
total_human = sum(d["Human"] for d in bot_by_date.values())
total_bot_ratio = f"{total_bot / total_human:.2f}:1" if total_human > 0 else "N/A"
print(f"Bot: {total_bot}")
print(f"Human: {total_human}")
print(f"Bot:Human Ratio: {total_bot_ratio}")

elapsed_ms = int((time.time() - start) * 1000)
print(f"\n===== TOTAL =====")
print(f"Total elapsed time: {elapsed_ms} ms")

sc.stop()
