import json
import time
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

# Map + Filter + Reduce: count PushEvent and PullRequestEvent
counts = lines \
    .flatMap(parse_jsons) \
    .filter(lambda obj: obj["type"] in ("PushEvent", "PullRequestEvent")) \
    .map(lambda obj: (obj["type"], 1)) \
    .reduceByKey(lambda a, b: a + b)

result = counts.collect()
print(f"\n===== EVENT COUNTS =====")
for event_type, count in sorted(result):
    print(f"{event_type}: {count}")

# Map + Reduce: count bot vs human events
bot_counts = lines \
    .flatMap(parse_jsons) \
    .map(lambda obj: ("Bot" if "[bot]" in obj["actor"]["login"] or obj["actor"]["login"] in bot_set_bc.value else "Human", 1)) \
    .reduceByKey(lambda a, b: a + b)

bot_result = bot_counts.collect()
print(f"\n===== BOT VS HUMAN =====")
for category, count in sorted(bot_result):
    print(f"{category}: {count}")

elapsed_ms = int((time.time() - start) * 1000)
print(f"\n===== TOTAL =====")
print(f"Total elapsed time: {elapsed_ms} ms")

sc.stop()
