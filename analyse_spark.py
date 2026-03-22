import json
import time
from pyspark import SparkConf, SparkContext

start = time.time()

conf = SparkConf().setAppName("GitHub Analysis")
sc = SparkContext(conf=conf)
sc.setLogLevel("ERROR")

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

elapsed_ms = int((time.time() - start) * 1000)
print(f"\n===== TOTAL =====")
print(f"Total elapsed time: {elapsed_ms} ms")

sc.stop()
