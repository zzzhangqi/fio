#!/bin/sh
# Exercise the musl binary outside its build container. No performance gate here.
set -eu

binary=$(realpath "${1:?usage: verify-linux-static.sh binary output.json}")
result=$(realpath -m "${2:?output JSON path is required}")
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$binary" --version
timeout --kill-after=5s 30s "$binary" \
    --name=sync-smoke --filename="$test_dir/data" \
    --ioengine=sync --rw=write --bs=4k --size=16m \
    --numjobs=1 --iodepth=1 --fdatasync=1 \
    --runtime=2 --time_based=1 --eta=never \
    --output-format=json --output="$result"

python3 - "$result" <<'PY'
import json
import math
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    report = json.load(stream)
jobs = report.get("jobs", [])
assert len(jobs) == 1, "Expected exactly one fio job"
job = jobs[0]
assert job["error"] == 0, "fio reported a job error"
assert job["write"]["io_bytes"] > 0, "No data was written"
# fio 3.42's sync.total_ios counts fsync, not fdatasync. The latency
# sample count covers both and is the relevant count for this workload.
sync_latency = job["sync"]["lat_ns"]
assert sync_latency["N"] > 0, "No sync latency samples recorded"
p99 = sync_latency["percentile"]["99.000000"]
assert math.isfinite(p99) and p99 > 0, "Missing or invalid sync P99 latency"
print(f"Sync JSON validated; P99 = {p99 / 1_000_000:.3f} ms (informational)")
PY
