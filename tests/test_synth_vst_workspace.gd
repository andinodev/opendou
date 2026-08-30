class_name TestSynthVstWorkspace
extends RefCounted

const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	if ModularSynthEngineClass == null:
		failures.append("TestSynthVstWorkspace: modular_synth_engine.gd failed to load")
		return failures

	# Test 1: Constant power stereo panning power preservation and interleaved buffer sizing
	var mono = PackedFloat32Array()
	mono.resize(100)
	for i in range(100):
		mono[i] = 1.0

	var stereo_center = ModularSynthEngineClass.apply_stereo_panning(mono, 0.0)
	if stereo_center.size() != 200:
		failures.append("Test 1 Failed: stereo panning size mismatch (got %d, expected 200)" % stereo_center.size())
	else:
		var l0 = stereo_center[0]
		var r0 = stereo_center[1]
		var power_center = l0 * l0 + r0 * r0
		if not is_equal_approx(power_center, 1.0):
			failures.append("Test 1 Failed: Center pan power is not 1.0 (got %f)" % power_center)
		if not is_equal_approx(l0, r0):
			failures.append("Test 1 Failed: Center pan L and R not equal (L: %f, R: %f)" % [l0, r0])

	var stereo_left = ModularSynthEngineClass.apply_stereo_panning(mono, -1.0)
	if not is_equal_approx(stereo_left[0], 1.0) or not is_equal_approx(stereo_left[1], 0.0):
		failures.append("Test 1 Failed: Hard left pan incorrect (L: %f, R: %f)" % [stereo_left[0], stereo_left[1]])

	var stereo_right = ModularSynthEngineClass.apply_stereo_panning(mono, 1.0)
	if not is_equal_approx(stereo_right[0], 0.0) or not is_equal_approx(stereo_right[1], 1.0):
		failures.append("Test 1 Failed: Hard right pan incorrect (L: %f, R: %f)" % [stereo_right[0], stereo_right[1]])

	var stereo_p05 = ModularSynthEngineClass.apply_stereo_panning(mono, 0.5)
	var power_p05 = stereo_p05[0] * stereo_p05[0] + stereo_p05[1] * stereo_p05[1]
	if absf(power_p05 - 1.0) > 0.001:
		failures.append("Test 1 Failed: Pan 0.5 power conservation failed (power: %f)" % power_p05)

	# Test 2: Ping-pong feedback delay reflections and wet/dry mix
	var num_delay_frames = 10000
	var impulse_stereo = PackedFloat32Array()
	impulse_stereo.resize(num_delay_frames * 2)
	impulse_stereo[0] = 1.0 # Left impulse at t=0
	impulse_stereo[1] = 0.0

	var d_ms = 50.0
	var sample_rate = 44100
	var expected_dl = clampi(int(round(d_ms * sample_rate / 1000.0)), 1, 88200) # 2205
	var expected_dr = clampi(int(round(float(expected_dl) * 1.333)), 1, 88200) # 2939

	var delay_out = ModularSynthEngineClass.apply_delay_fx(impulse_stereo, d_ms, 0.5, 0.0, 0.5, sample_rate)
	if delay_out.size() != impulse_stereo.size():
		failures.append("Test 2 Failed: Delay output size mismatch")
	else:
		# Initial dry component should be at t=0
		if not is_equal_approx(delay_out[0], 0.5):
			failures.append("Test 2 Failed: Dry mix at t=0 incorrect (got %f, expected 0.5)" % delay_out[0])
		# Wet reflection from L should appear at delay L
		var wet_l_val = delay_out[expected_dl * 2]
		if wet_l_val <= 0.01:
			failures.append("Test 2 Failed: Delay left wet reflection missing at frame %d (got %f)" % [expected_dl, wet_l_val])

	# Mix 0.0 dry check
	var dry_delay_out = ModularSynthEngineClass.apply_delay_fx(impulse_stereo, 50.0, 0.5, 0.0, 0.0, sample_rate)
	if not is_equal_approx(dry_delay_out[0], 1.0) or not is_equal_approx(dry_delay_out[expected_dl * 2], 0.0):
		failures.append("Test 2 Failed: Mix 0.0 should be pure dry signal")

	# Test 3: FDN Space Reverb impulse response tail and stereo decorrelation
	var num_reverb_frames = 22050 # 0.5 sec
	var rev_impulse = PackedFloat32Array()
	rev_impulse.resize(num_reverb_frames * 2)
	rev_impulse[0] = 1.0
	rev_impulse[1] = 1.0

	var rev_out = ModularSynthEngineClass.apply_reverb_fx(rev_impulse, 0.8, 0.2, 0.5, sample_rate)
	if rev_out.size() != rev_impulse.size():
		failures.append("Test 3 Failed: Reverb output size mismatch")
	else:
		# Measure tail energy from frame 5000 to 15000
		var tail_l_energy = 0.0
		var tail_r_energy = 0.0
		var decorrelated_diff = 0.0
		for f in range(5000, 15000):
			var l_val = rev_out[f * 2]
			var r_val = rev_out[f * 2 + 1]
			tail_l_energy += l_val * l_val
			tail_r_energy += r_val * r_val
			decorrelated_diff += absf(l_val - r_val)

		if tail_l_energy <= 0.001 or tail_r_energy <= 0.001:
			failures.append("Test 3 Failed: Reverb tail energy too low (L: %f, R: %f)" % [tail_l_energy, tail_r_energy])
		if decorrelated_diff <= 0.01:
			failures.append("Test 3 Failed: Reverb L and R channels lack stereo decorrelation")

	# Test 4: Pitch glide exponential calculation
	var g_start = 100.0
	var g_target = 400.0
	var g_time = 0.5

	var p0 = ModularSynthEngineClass.apply_glide_pitch(g_start, g_target, g_time, 0.0)
	if not is_equal_approx(p0, 100.0):
		failures.append("Test 4 Failed: Glide at t=0 should be start freq 100.0 (got %f)" % p0)

	var p_half = ModularSynthEngineClass.apply_glide_pitch(g_start, g_target, g_time, 0.25)
	# 100 * (400/100)^0.5 = 200.0
	if not is_equal_approx(p_half, 200.0):
		failures.append("Test 4 Failed: Exponential glide at t=0.25 should be 200.0 (got %f)" % p_half)

	var p_end = ModularSynthEngineClass.apply_glide_pitch(g_start, g_target, g_time, 0.5)
	if not is_equal_approx(p_end, 400.0):
		failures.append("Test 4 Failed: Glide at t=0.5 should be target freq 400.0 (got %f)" % p_end)

	var p_over = ModularSynthEngineClass.apply_glide_pitch(g_start, g_target, g_time, 1.0)
	if not is_equal_approx(p_over, 400.0):
		failures.append("Test 4 Failed: Glide beyond glide_time should be clamped to target freq (got %f)" % p_over)

	var p_instant = ModularSynthEngineClass.apply_glide_pitch(g_start, g_target, 0.0, 0.0)
	if not is_equal_approx(p_instant, 400.0):
		failures.append("Test 4 Failed: Glide with 0 glide_time should be target freq immediately (got %f)" % p_instant)

	# Test 5: synthesize_wav generates valid 16-bit stereo AudioStreamWAV when pan or FX are active
	var stereo_preset = {
		"type": "Single_Generator",
		"generator_type": "Basic_Wave",
		"wave_type": "Saw",
		"base_freq": 220.0,
		"duration": 0.2,
		"gain_db": -3.0,
		"pan": 0.3,
		"loop_mode": true,
		"fx": {
			"delay": {
				"enabled": true,
				"time_ms": 60.0,
				"feedback": 0.3,
				"damping": 0.2,
				"mix": 0.25
			},
			"reverb": {
				"enabled": true,
				"room_size": 0.6,
				"damping": 0.3,
				"mix": 0.2
			}
		}
	}

	var stereo_stream = ModularSynthEngineClass.synthesize_wav(stereo_preset, 99)
	if stereo_stream == null or not (stereo_stream is AudioStreamWAV):
		failures.append("Test 5 Failed: synthesize_wav did not return AudioStreamWAV")
	else:
		if not stereo_stream.stereo:
			failures.append("Test 5 Failed: AudioStreamWAV stereo flag is false")
		if stereo_stream.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Test 5 Failed: AudioStreamWAV format must be 16_BITS")
		var expected_bytes = int(0.2 * 44100) * 4 # 2 channels * 2 bytes per sample
		if stereo_stream.data.size() != expected_bytes:
			failures.append("Test 5 Failed: AudioStreamWAV data size mismatch (got %d, expected %d)" % [stereo_stream.data.size(), expected_bytes])
		if stereo_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			failures.append("Test 5 Failed: AudioStreamWAV loop_mode should be LOOP_FORWARD")
		if stereo_stream.loop_end != int(0.2 * 44100):
			failures.append("Test 5 Failed: AudioStreamWAV loop_end mismatch")

	return failures
