extends Node

# Dev perf harness, activated by launching with `--bb-perf` (plus the usual
# `--mode=3v3` / `--bb-perf-frames=600`). Runs in the NORMAL main loop — the
# `--script` SceneTree mode idles awaited frames at ~1 Hz headless, so any
# probe built on it reads garbage; this is the trustworthy replacement.
# Boots straight into the Arena, warms up, measures wall time per frame,
# prints one summary line, quits.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const WARMUP_FRAMES := 5
const PerfStats := preload("res://scripts/game/perf_stats.gd")

var frames_to_measure := 600
var warmup_remaining := WARMUP_FRAMES
var measured := 0
var start_usec := 0
var previous_usec := 0
var worst_usec := 0
var booted := false

func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--bb-perf-frames="):
			frames_to_measure = maxi(1, int(argument.trim_prefix("--bb-perf-frames=")))
	PerfStats.enabled = true
	get_tree().change_scene_to_file.call_deferred(ARENA_SCENE)
	booted = true

func _process(_delta: float) -> void:
	if not booted or get_tree().current_scene == null:
		return
	if warmup_remaining > 0:
		var warmup_now := Time.get_ticks_usec()
		if previous_usec > 0:
			print("bb_perf_warmup frame=%d frame_ms=%.1f nodes=%d" % [
				WARMUP_FRAMES - warmup_remaining,
				float(warmup_now - previous_usec) / 1000.0,
				get_tree().get_node_count()
			])
		previous_usec = warmup_now
		warmup_remaining -= 1
		if warmup_remaining == 0:
			start_usec = Time.get_ticks_usec()
			previous_usec = start_usec
		return
	var now_usec := Time.get_ticks_usec()
	worst_usec = maxi(worst_usec, int(now_usec - previous_usec))
	var frame_ms := float(now_usec - previous_usec) / 1000.0
	previous_usec = now_usec
	measured += 1
	if measured % 10 == 0:
		var scene := get_tree().current_scene
		var live_entities := -1
		if scene != null and scene.get("entities") != null:
			live_entities = (scene.entities as Array).size()
		var buckets := PerfStats.drain()
		var bucket_text := ""
		for key in buckets:
			bucket_text += " %s=%.1fms" % [key, float(buckets[key]) / 1000.0]
		print("bb_perf_progress frame=%d frame_ms=%.1f entities=%d nodes=%d%s" % [
			measured,
			frame_ms,
			live_entities,
			get_tree().get_node_count(),
			bucket_text
		])
	if measured < frames_to_measure:
		return
	var total_usec := now_usec - start_usec
	var avg_ms := float(total_usec) / float(measured) / 1000.0
	var arena := get_tree().current_scene
	var entity_count := -1
	if arena != null and arena.get("entities") != null:
		entity_count = (arena.entities as Array).size()
	print("bb_perf mode=%s frames=%d entities=%d avg_mspf=%.3f worst_mspf=%.3f effective_fps=%.1f draw_calls=%d" % [
		GameConfig.selected_mode if get_node_or_null("/root/GameConfig") != null else "?",
		measured,
		entity_count,
		avg_ms,
		float(worst_usec) / 1000.0,
		1000.0 / maxf(avg_ms, 0.001),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	])
	get_tree().quit(0)
