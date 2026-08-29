class_name TestInteractiveMusic
extends RefCounted

const MusicClockClass = preload("res://addons/opendou/core/music/music_clock.gd")
const MusicTrackClass = preload("res://addons/opendou/core/music/music_track.gd")
const MusicSegmentClass = preload("res://addons/opendou/core/music/music_segment.gd")
const MusicTransitionMatrixClass = preload("res://addons/opendou/core/music/music_transition_matrix.gd")
const MusicStingerQueueClass = preload("res://addons/opendou/core/music/music_stinger_queue.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: MusicClock precision & calculations
	var clock = MusicClockClass.new(120.0, 4, 4) # 120 BPM = 0.5s per beat, 2.0s per bar
	if not is_equal_approx(clock.get_seconds_per_beat(), 0.5):
		failures.append("Test 1a Failed: Expected 0.5s per beat, got %f" % clock.get_seconds_per_beat())
	if not is_equal_approx(clock.get_seconds_per_bar(), 2.0):
		failures.append("Test 1b Failed: Expected 2.0s per bar, got %f" % clock.get_seconds_per_bar())
		
	clock.start()
	clock.update(1.25) # 2.5 beats in -> Bar 0, Beat 2
	if clock.current_bar != 0 or clock.current_beat != 2:
		failures.append("Test 1c Failed: At 1.25s expected Bar 0 Beat 2, got Bar %d Beat %d" % [clock.current_bar, clock.current_beat])
	if not is_equal_approx(clock.get_time_to_next_beat(), 0.25):
		failures.append("Test 1d Failed: Expected 0.25s to next beat, got %f" % clock.get_time_to_next_beat())
	if not is_equal_approx(clock.get_time_to_next_bar(), 0.75):
		failures.append("Test 1e Failed: Expected 0.75s to next bar, got %f" % clock.get_time_to_next_bar())
		
	# Test 2: MusicTrack & Layered Intensity Evaluation
	var drums = MusicTrackClass.new(&"Drums", null, 0.4, 1.0)
	var pads = MusicTrackClass.new(&"Pads", null, 0.0, 0.6)
	
	var seg = MusicSegmentClass.new(&"Combat_Theme", 8, true)
	seg.add_track(drums)
	seg.add_track(pads)
	
	var low_eval = seg.evaluate_tracks(0.1)
	if low_eval["Pads"] <= 0.0 or low_eval["Drums"] > 0.0:
		failures.append("Test 2a Failed: At low intensity (0.1) expected Pads audible, Drums silent")
		
	var high_eval = seg.evaluate_tracks(0.9)
	if high_eval["Drums"] <= 0.0 or high_eval["Pads"] > 0.0:
		failures.append("Test 2b Failed: At high intensity (0.9) expected Drums audible, Pads silent")
		
	# Test 3: Quantized Transition Matrix
	var seg_explore = MusicSegmentClass.new(&"Explore", 8, true)
	var seg_combat = MusicSegmentClass.new(&"Combat", 8, true)
	var matrix = MusicTransitionMatrixClass.new(seg_explore)
	
	matrix.request_transition(seg_combat, MusicTransitionMatrixClass.SyncMode.NEXT_BAR, 1.0)
	if not matrix.is_waiting_for_quantize:
		failures.append("Test 3a Failed: Matrix should wait for bar quantize")
		
	matrix.notify_bar()
	if not matrix.is_crossfading:
		failures.append("Test 3b Failed: Matrix should start crossfade after notify_bar")
		
	matrix.update(0.5) # Midpoint
	if matrix.current_segment_fade_gain >= 1.0 or matrix.target_segment_fade_gain <= 0.0:
		failures.append("Test 3c Failed: Expected crossfading gains, got current=%f, target=%f" % [matrix.current_segment_fade_gain, matrix.target_segment_fade_gain])
		
	matrix.update(0.6) # Completed
	if matrix.current_segment != seg_combat:
		failures.append("Test 3d Failed: Target segment should now be active after crossfade completion")
		
	# Test 4: Quantized Stinger Queue & Music Ducking
	var stinger_q = MusicStingerQueueClass.new()
	var dummy_stream = AudioStreamWAV.new()
	
	stinger_q.trigger_stinger(dummy_stream, MusicStingerQueueClass.StingerSync.NEXT_BEAT, -10.0, 1.0)
	if not stinger_q.queue.is_empty() and stinger_q.is_ducking:
		failures.append("Test 4a Failed: Stinger should be queued and not yet ducking before beat")
		
	stinger_q.notify_beat()
	stinger_q.update(0.1)
	var duck_val = stinger_q.get_music_ducking_db()
	if duck_val >= 0.0:
		failures.append("Test 4b Failed: Music should be ducked during stinger execution (got %f dB)" % duck_val)
		
	return failures
