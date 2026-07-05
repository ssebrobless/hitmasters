extends RefCounted

# Lightweight tick-cost attribution, enabled only by the --bb-perf harness.
# Hot code calls PerfStats.add("bucket", usec) when enabled; the harness
# prints and resets buckets alongside its frame telemetry.

static var enabled := false
static var buckets: Dictionary = {}

static func add(bucket: String, usec: int) -> void:
	if not enabled:
		return
	buckets[bucket] = int(buckets.get(bucket, 0)) + usec

static func drain() -> Dictionary:
	var snapshot := buckets.duplicate()
	buckets.clear()
	return snapshot
