class_name TestProfilerRewind
extends RefCounted

const ProfilerSessionRecorderClass = preload("res://addons/opendou/core/telemetry/profiler_session_recorder.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Frame recording and capacity limiting
	var recorder = ProfilerSessionRecorderClass.new(10) # 10 frames capacity
	for i in range(15):
		recorder.record_frame(50.0 + float(i), i % 8, i, ["Event_%d" % i], { "RPM": 1000 + i * 100 }, i)
		
	if recorder.frames.size() != 10:
		failures.append("Test 1a Failed: Expected 10 frames ring buffer limit, got %d" % recorder.frames.size())
		
	var oldest = recorder.get_frame_at_index(0)
	if oldest.api_calls_count != 5:
		failures.append("Test 1b Failed: Expected oldest frame to have api_calls_count 5, got %d" % oldest.api_calls_count)
		
	var newest = recorder.get_frame_at_index(9)
	if newest.api_calls_count != 14:
		failures.append("Test 1c Failed: Expected newest frame to have api_calls_count 14, got %d" % newest.api_calls_count)
		
	# Test 2: JSON Export and Import
	var json_data = recorder.export_to_json()
	if json_data.is_empty():
		failures.append("Test 2a Failed: JSON export returned empty string")
		
	var new_recorder = ProfilerSessionRecorderClass.new(100)
	var ok = new_recorder.import_from_json(json_data)
	if not ok:
		failures.append("Test 2b Failed: JSON import failed")
	elif new_recorder.frames.size() != 10:
		failures.append("Test 2c Failed: Expected 10 imported frames, got %d" % new_recorder.frames.size())
	elif new_recorder.get_frame_at_index(9).api_calls_count != 14:
		failures.append("Test 2d Failed: Imported frame data mismatch")
		
	return failures
