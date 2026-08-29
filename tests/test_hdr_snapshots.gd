class_name TestHDRSnapshots
extends RefCounted

const AudioMixSnapshotClass = preload("res://addons/opendou/core/audio_mix_snapshot.gd")
const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Snapshot creation and default retrieval
	var snap = AudioMixSnapshotClass.new(&"CustomSnap", {
		&"Music": { "volume_db": -12.0, "lpf_hz": 800.0, "hpf_hz": 20.0, "mute": false }
	}, 0.5)
	
	var mus_setting = snap.get_bus_setting(&"Music")
	if not is_equal_approx(mus_setting["volume_db"], -12.0):
		failures.append("Test 1a Failed: Expected volume -12.0dB, got %f" % mus_setting["volume_db"])
	if not is_equal_approx(mus_setting["lpf_hz"], 800.0):
		failures.append("Test 1b Failed: Expected LPF 800Hz, got %f" % mus_setting["lpf_hz"])
		
	# Test 2: Snapshot Manager transitions
	var mgr = AudioMixSnapshotManagerClass.new()
	var default_state = mgr.get_bus_state(&"Music")
	if not is_equal_approx(default_state["volume_db"], 0.0):
		failures.append("Test 2a Failed: Default Music bus volume expected 0dB, got %f" % default_state["volume_db"])
		
	mgr.transition_to(&"Tinnitus_Explosion", 0.5)
	mgr.update(0.25) # Midpoint
	var mid_state = mgr.get_bus_state(&"Music")
	if mid_state["volume_db"] >= 0.0 or mid_state["volume_db"] <= -18.0:
		failures.append("Test 2b Failed: Expected interpolated volume between 0 and -18dB, got %f" % mid_state["volume_db"])
		
	mgr.update(0.30) # Completed transition
	var final_state = mgr.get_bus_state(&"Music")
	if not is_equal_approx(final_state["volume_db"], -18.0):
		failures.append("Test 2c Failed: Expected final volume -18dB, got %f" % final_state["volume_db"])
		
	# Test 3: Audio HDR Engine Window & Attenuation
	var hdr = AudioHDREngineClass.new(40.0, 35.0)
	# Push loud explosion (+12 dB HDR)
	hdr.push_event_loudness(12.0)
	hdr.update(0.1)
	
	var bounds = hdr.get_window_bounds()
	if bounds.x <= 0.0:
		failures.append("Test 3a Failed: HDR Window top should have risen above 0dB, got %f" % bounds.x)
		
	# Loud sound at window top should have near 1.0 linear gain
	var loud_gain = hdr.calculate_voice_gain(bounds.x)
	if not is_equal_approx(loud_gain, 1.0):
		failures.append("Test 3b Failed: Sound at window top should have gain 1.0, got %f" % loud_gain)
		
	# Quiet sound below window bottom should be 0.0 (ducked)
	var quiet_gain = hdr.calculate_voice_gain(bounds.y - 10.0)
	if not is_equal_approx(quiet_gain, 0.0):
		failures.append("Test 3c Failed: Sound below window bottom should have gain 0.0, got %f" % quiet_gain)
		
	# Test 4: Audio Ducking Matrix
	var duck = AudioDuckingMatrixClass.new()
	duck.set_bus_active(&"Voice", true)
	duck.update(0.1) # Voice active, ducking music
	var music_duck = duck.get_ducking_attenuation_db(&"Music")
	if music_duck >= 0.0:
		failures.append("Test 4a Failed: Expected negative ducking attenuation for Music, got %f" % music_duck)
		
	duck.set_bus_active(&"Voice", false)
	duck.update(1.0) # Released
	var music_released = duck.get_ducking_attenuation_db(&"Music")
	if not is_equal_approx(music_released, 0.0):
		failures.append("Test 4b Failed: Expected 0dB attenuation after release, got %f" % music_released)
		
	return failures
