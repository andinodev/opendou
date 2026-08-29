class_name TestMicroAcoustics
extends RefCounted

const OcclusionManagerClass = preload("res://addons/opendou/runtime/spatial/occlusion_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var occ_mgr = OcclusionManagerClass.new()
	
	# Test 1: Occlusion Evaluation (Unobstructed vs Partial vs Full)
	# 1a. Unobstructed
	var res_clear = occ_mgr.evaluate_occlusion(Vector3.ZERO, Vector3(10, 0, 0), [false, false])
	if not is_equal_approx(res_clear.target_lpf, 20000.0) or not is_equal_approx(res_clear.volume_attenuation_db, 0.0):
		failures.append("Test 1a Failed: Clear line of sight expected 20000Hz and 0dB, got %fHz, %fdB" % [res_clear.target_lpf, res_clear.volume_attenuation_db])
		
	# 1b. Fully Occluded
	var res_blocked = occ_mgr.evaluate_occlusion(Vector3.ZERO, Vector3(10, 0, 0), [true, true])
	if not is_equal_approx(res_blocked.target_lpf, 1500.0) or not is_equal_approx(res_blocked.volume_attenuation_db, -6.0):
		failures.append("Test 1b Failed: Fully blocked expected 1500Hz and -6dB, got %fHz, %fdB" % [res_blocked.target_lpf, res_blocked.volume_attenuation_db])
		
	# 1c. Partial Occlusion (50%)
	var res_half = occ_mgr.evaluate_occlusion(Vector3.ZERO, Vector3(10, 0, 0), [true, false])
	if not is_equal_approx(res_half.target_lpf, 10750.0) or not is_equal_approx(res_half.volume_attenuation_db, -3.0):
		failures.append("Test 1c Failed: 50%% blocked expected 10750Hz and -3dB, got %fHz, %fdB" % [res_half.target_lpf, res_half.volume_attenuation_db])
		
	# Test 2: EventInstance Temporal Slew-Rate Smoothing
	var event_def = AudioEventDefClass.new(&"Footstep_3D")
	var inst = EventInstanceClass.new(event_def)
	inst.play()
	
	# Initial state: 20000 Hz
	if not is_equal_approx(inst.current_spatial_lpf, 20000.0):
		failures.append("Test 2a Failed: Initial spatial LPF should be 20000Hz")
		
	# Set target to 1500 Hz (abrupt change)
	inst.set_target_lpf(1500.0, -6.0)
	
	# Step 1: Small frame (0.05s with speed 8.0 -> progress ~ 0.4)
	inst.update_parameters(0.05)
	if inst.current_spatial_lpf >= 20000.0 or inst.current_spatial_lpf <= 1500.0:
		failures.append("Test 2b Failed: Slew rate should smoothly glide between 20000Hz and 1500Hz, got %f" % inst.current_spatial_lpf)
		
	if not inst.calculated_properties.has(&"cutoff_hz"):
		failures.append("Test 2c Failed: calculated_properties missing 'cutoff_hz'")
		
	return failures
