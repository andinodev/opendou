@tool
class_name ProfilerSessionRecorder
extends RefCounted

## Records continuous telemetry frames into a ring buffer and provides time-travel scrubbing, export, and replay capabilities.

class TelemetryFrame:
	var timestamp_sec: float = 0.0
	var dsp_time_us: float = 0.0
	var physical_voices: int = 0
	var virtual_voices: int = 0
	var active_events: Array = []
	var rtpc_values: Dictionary = {}
	var api_calls_count: int = 0

var max_frames: int = 1800 # 30 seconds at 60 FPS
var frames: Array[TelemetryFrame] = []
var is_recording: bool = true

var session_start_time_msec: int = 0

func _init(p_max_frames: int = 1800) -> void:
	max_frames = p_max_frames
	session_start_time_msec = Time.get_ticks_msec()

## Pushes a new telemetry snapshot frame to the ring buffer.
func record_frame(dsp_us: float, phys_voices: int, virt_voices: int, events: Array = [], rtpcs: Dictionary = {}, api_calls: int = 0) -> void:
	if not is_recording:
		return
		
	var frame = TelemetryFrame.new()
	frame.timestamp_sec = float(Time.get_ticks_msec() - session_start_time_msec) / 1000.0
	frame.dsp_time_us = dsp_us
	frame.physical_voices = phys_voices
	frame.virtual_voices = virt_voices
	frame.active_events = events.duplicate()
	frame.rtpc_values = rtpcs.duplicate()
	frame.api_calls_count = api_calls
	
	frames.append(frame)
	if frames.size() > max_frames:
		frames.pop_front()

## Retrieves recorded frame by normalized index (0 = oldest, size-1 = newest).
func get_frame_at_index(idx: int) -> TelemetryFrame:
	if frames.is_empty():
		return null
	var clamped_idx = clampi(idx, 0, frames.size() - 1)
	return frames[clamped_idx]

## Retrieves recorded frame closest to a given timestamp.
func get_frame_at_time(time_sec: float) -> TelemetryFrame:
	if frames.is_empty():
		return null
	var closest: TelemetryFrame = frames[0]
	var min_diff = absf(closest.timestamp_sec - time_sec)
	
	for f in frames:
		var diff = absf(f.timestamp_sec - time_sec)
		if diff < min_diff:
			min_diff = diff
			closest = f
	return closest

## Exports the recorded telemetry buffer to JSON format.
func export_to_json() -> String:
	var list: Array[Dictionary] = []
	for f in frames:
		list.append({
			"t": f.timestamp_sec,
			"dsp": f.dsp_time_us,
			"phys": f.physical_voices,
			"virt": f.virtual_voices,
			"events": f.active_events,
			"rtpc": f.rtpc_values,
			"api": f.api_calls_count
		})
	return JSON.stringify(list)

## Imports telemetry data from JSON string.
func import_from_json(json_str: String) -> bool:
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Array):
		return false
		
	frames.clear()
	for d in parsed:
		if d is Dictionary:
			var f = TelemetryFrame.new()
			f.timestamp_sec = d.get("t", 0.0)
			f.dsp_time_us = d.get("dsp", 0.0)
			f.physical_voices = d.get("phys", 0)
			f.virtual_voices = d.get("virt", 0)
			f.active_events = d.get("events", [])
			f.rtpc_values = d.get("rtpc", {})
			f.api_calls_count = d.get("api", 0)
			frames.append(f)
	return true
