class_name TestModularSynthEngine
extends RefCounted

const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: ModularSynthEngine loads properly
	if ModularSynthEngineClass == null:
		failures.append("Test 1 Failed: modular_synth_engine.gd failed to load")
		return failures

	# Test 2: Generator 1 - Filtered_Noise (White, Pink, Brown)
	var noise_types = ["White", "Pink", "Brown"]
	for n_type in noise_types:
		var layer = {
			"generator_type": "Filtered_Noise",
			"noise_type": n_type,
			"filter": {
				"type": "LowPass",
				"cutoff_hz": 1200.0,
				"resonance_q": 1.5
			}
		}
		var samples = ModularSynthEngineClass.generate_layer_samples(layer, 0.2, 44100, 42)
		if samples.size() != int(0.2 * 44100):
			failures.append("Test 2 Failed: Filtered_Noise (%s) generated wrong sample size %d" % [n_type, samples.size()])
		var energy = _calculate_rms(samples)
		if energy <= 0.0001:
			failures.append("Test 2 Failed: Filtered_Noise (%s) has zero energy" % n_type)

	# Test 3: Generator 2 - FM_Chirp (2-op FM with frequency sweep and trill)
	var fm_layer = {
		"generator_type": "FM_Chirp",
		"base_freq": 2200.0,
		"mod_mult": 1.5,
		"mod_index": 2.5,
		"frequency_sweep": {
			"start_mult": 1.0,
			"end_mult": 0.5,
			"trill_rate": 8.0
		}
	}
	var fm_samples = ModularSynthEngineClass.generate_layer_samples(fm_layer, 0.25, 44100, 100)
	if fm_samples.size() != int(0.25 * 44100):
		failures.append("Test 3 Failed: FM_Chirp generated incorrect sample count")
	if _calculate_rms(fm_samples) <= 0.001:
		failures.append("Test 3 Failed: FM_Chirp has near-zero RMS energy")

	# Test 4: Generator 3 - Karplus_Strong physical modeling
	var ks_layer = {
		"generator_type": "Karplus_Strong",
		"base_freq": 220.0,
		"decay_factor": 0.985,
		"damping": 0.4
	}
	var ks_samples = ModularSynthEngineClass.generate_layer_samples(ks_layer, 0.3, 44100, 123)
	if ks_samples.size() != int(0.3 * 44100):
		failures.append("Test 4 Failed: Karplus_Strong generated incorrect sample count")
	# Assert physical decay: tail energy must be less than head energy
	var ks_head_rms = _calculate_slice_rms(ks_samples, 0, int(0.05 * 44100))
	var ks_tail_rms = _calculate_slice_rms(ks_samples, int(0.25 * 44100), ks_samples.size())
	if ks_head_rms <= 0.01 or ks_tail_rms >= ks_head_rms:
		failures.append("Test 4 Failed: Karplus_Strong string did not decay properly (head: %f, tail: %f)" % [ks_head_rms, ks_tail_rms])

	# Test 5: Generator 4 - Wavetable_PM (Phase modulation)
	var pm_layer = {
		"generator_type": "Wavetable_PM",
		"base_freq": 180.0,
		"phase_modulation_index": 3.0,
		"mod_freq": 360.0
	}
	var pm_samples = ModularSynthEngineClass.generate_layer_samples(pm_layer, 0.2, 44100, 77)
	if pm_samples.size() != int(0.2 * 44100):
		failures.append("Test 5 Failed: Wavetable_PM sample count mismatch")
	if _calculate_rms(pm_samples) <= 0.01:
		failures.append("Test 5 Failed: Wavetable_PM generated near-silent signal")

	# Test 6: Generator 5 - Harmonic_Buzz (additive harmonics + flutter)
	var buzz_layer = {
		"generator_type": "Harmonic_Buzz",
		"base_freq": 110.0,
		"harmonics": 8,
		"flutter_rate": 6.0,
		"flutter_depth": 0.08
	}
	var buzz_samples = ModularSynthEngineClass.generate_layer_samples(buzz_layer, 0.2, 44100, 55)
	if buzz_samples.size() != int(0.2 * 44100):
		failures.append("Test 6 Failed: Harmonic_Buzz sample count mismatch")
	if _calculate_rms(buzz_samples) <= 0.01:
		failures.append("Test 6 Failed: Harmonic_Buzz generated near-silent signal")

	# Test 7: Generator 6 - Sub_Rumble (Sub-bass 30-75Hz with distortion swells)
	var rumble_layer = {
		"generator_type": "Sub_Rumble",
		"base_freq": 45.0,
		"swell_rate": 2.0
	}
	var rumble_samples = ModularSynthEngineClass.generate_layer_samples(rumble_layer, 0.3, 44100, 99)
	if rumble_samples.size() != int(0.3 * 44100):
		failures.append("Test 7 Failed: Sub_Rumble sample count mismatch")
	if _calculate_rms(rumble_samples) <= 0.01:
		failures.append("Test 7 Failed: Sub_Rumble generated near-silent signal")

	# Test 8: Generator 7 - Resonant_Formant (3-formant vocal resonator)
	var formant_layer = {
		"generator_type": "Resonant_Formant",
		"base_freq": 140.0,
		"formants": [600.0, 1200.0, 2400.0]
	}
	var formant_samples = ModularSynthEngineClass.generate_layer_samples(formant_layer, 0.2, 44100, 33)
	if formant_samples.size() != int(0.2 * 44100):
		failures.append("Test 8 Failed: Resonant_Formant sample count mismatch")
	if _calculate_rms(formant_samples) <= 0.005:
		failures.append("Test 8 Failed: Resonant_Formant generated near-silent signal")

	# Test 9: Generator 8 - Impulse_Ping (High-Q impulse exponential pitch curve)
	var ping_layer = {
		"generator_type": "Impulse_Ping",
		"base_freq": 880.0,
		"pitch_mult": 3.0,
		"pitch_decay": 0.04,
		"ring_q": 15.0
	}
	var ping_samples = ModularSynthEngineClass.generate_layer_samples(ping_layer, 0.2, 44100, 44)
	if ping_samples.size() != int(0.2 * 44100):
		failures.append("Test 9 Failed: Impulse_Ping sample count mismatch")
	if _calculate_rms(ping_samples) <= 0.005:
		failures.append("Test 9 Failed: Impulse_Ping generated near-silent signal")

	# Test 10: Generator 9 - Basic_Wave (Sine, Saw, Square, Triangle)
	var wave_types = ["Sine", "Saw", "Square", "Triangle"]
	for w_type in wave_types:
		var wave_layer = {
			"generator_type": "Basic_Wave",
			"wave_type": w_type,
			"base_freq": 440.0
		}
		var wave_samples = ModularSynthEngineClass.generate_layer_samples(wave_layer, 0.1, 44100, 1)
		if wave_samples.size() != int(0.1 * 44100):
			failures.append("Test 10 Failed: Basic_Wave (%s) sample count mismatch" % w_type)
		if _calculate_rms(wave_samples) <= 0.1:
			failures.append("Test 10 Failed: Basic_Wave (%s) energy too low" % w_type)

	# Test 11: apply_drive distortion non-linear curves
	var soft_val = ModularSynthEngineClass.apply_drive(0.8, "Soft_Clip", 2.5)
	if soft_val > 1.0 or soft_val < -1.0 or is_equal_approx(soft_val, 0.8):
		failures.append("Test 11 Failed: apply_drive Soft_Clip did not compress signal correctly (%f)" % soft_val)

	var hard_val = ModularSynthEngineClass.apply_drive(1.5, "Hard_Clip", 2.0)
	if not is_equal_approx(hard_val, 1.0):
		failures.append("Test 11 Failed: apply_drive Hard_Clip did not clamp at 1.0 (%f)" % hard_val)

	var fold_val = ModularSynthEngineClass.apply_drive(1.0, "Foldback", 4.0)
	if fold_val > 1.0 or fold_val < -1.0:
		failures.append("Test 11 Failed: apply_drive Foldback out of range (%f)" % fold_val)

	var none_val = ModularSynthEngineClass.apply_drive(0.75, "None", 3.0)
	if not is_equal_approx(none_val, 0.75):
		failures.append("Test 11 Failed: apply_drive None modified signal (%f)" % none_val)

	# Test 12: Pitch Envelope and ADSR modulation
	var env_layer = {
		"generator_type": "Basic_Wave",
		"wave_type": "Sine",
		"base_freq": 200.0,
		"pitch_envelope": {
			"amount_st": 12.0,
			"decay": 0.05
		},
		"envelope": {
			"attack": 0.02,
			"decay": 0.03,
			"sustain": 0.4,
			"release": 0.05
		}
	}
	var env_samples = ModularSynthEngineClass.generate_layer_samples(env_layer, 0.2, 44100, 10)
	if env_samples.size() != int(0.2 * 44100):
		failures.append("Test 12 Failed: ADSR modulated layer sample count mismatch")
	# Attack check: sample at t=0 should be near 0
	if absf(env_samples[0]) > 0.05:
		failures.append("Test 12 Failed: ADSR attack starting amplitude should be near 0 (got %f)" % env_samples[0])

	# Test 13: LFO modulation (Amplitude, Pitch, Filter_Cutoff)
	var lfo_targets = ["Amplitude", "Pitch", "Filter_Cutoff"]
	for tgt in lfo_targets:
		var lfo_layer = {
			"generator_type": "Basic_Wave",
			"wave_type": "Sine",
			"base_freq": 300.0,
			"lfo": {
				"wave": "Sine",
				"rate_hz": 5.0,
				"depth": 0.5,
				"target": tgt
			},
			"filter": {
				"type": "LowPass",
				"cutoff_hz": 1500.0,
				"resonance_q": 1.0
			}
		}
		var lfo_samples = ModularSynthEngineClass.generate_layer_samples(lfo_layer, 0.15, 44100, 20)
		if lfo_samples.is_empty() or _calculate_rms(lfo_samples) <= 0.001:
			failures.append("Test 13 Failed: LFO modulation target '%s' generated invalid samples" % tgt)

	# Test 14: Stochastic base frequency variation (base_freq_var)
	var layer_var1 = {
		"generator_type": "Basic_Wave",
		"wave_type": "Sine",
		"base_freq": 440.0,
		"base_freq_var": 0.15
	}
	var var_samples1 = ModularSynthEngineClass.generate_layer_samples(layer_var1, 0.1, 44100, 101)
	var var_samples2 = ModularSynthEngineClass.generate_layer_samples(layer_var1, 0.1, 44100, 202)
	# Different seeds should produce slightly different phases/frequencies with base_freq_var > 0
	var samples_differ = false
	for i in range(mini(var_samples1.size(), var_samples2.size())):
		if not is_equal_approx(var_samples1[i], var_samples2[i]):
			samples_differ = true
			break
	if not samples_differ:
		failures.append("Test 14 Failed: base_freq_var did not vary output across different seeds")

	# Test 15: synthesize_wav() for Single_Generator
	var single_preset = {
		"type": "Single_Generator",
		"generator_type": "Basic_Wave",
		"wave_type": "Triangle",
		"base_freq": 220.0,
		"duration": 0.3,
		"gain_db": -3.0,
		"loop_mode": true
	}
	var stream_single = ModularSynthEngineClass.synthesize_wav(single_preset, 42)
	if stream_single == null or not (stream_single is AudioStreamWAV):
		failures.append("Test 15 Failed: synthesize_wav did not return AudioStreamWAV")
	else:
		if stream_single.data.is_empty():
			failures.append("Test 15 Failed: Single_Generator stream data is empty")
		if stream_single.format != AudioStreamWAV.FORMAT_16_BITS:
			failures.append("Test 15 Failed: Stream format must be 16-bit PCM")
		if stream_single.mix_rate != 44100:
			failures.append("Test 15 Failed: Stream mix_rate must be 44100")
		if stream_single.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			failures.append("Test 15 Failed: Stream loop_mode should be LOOP_FORWARD when loop_mode is true")
		if stream_single.loop_end <= 0:
			failures.append("Test 15 Failed: Stream loop_end should be > 0 for looping stream")

	# Test 16: synthesize_wav() for Layer_Container compounding
	var multi_layer_preset = {
		"type": "Layer_Container",
		"duration": 0.4,
		"gain_db": -2.0,
		"drive": {
			"type": "Soft_Clip",
			"amount": 1.5
		},
		"loop_mode": false,
		"layers": [
			{
				"generator_type": "Karplus_Strong",
				"base_freq": 160.0,
				"decay_factor": 0.98,
				"gain_db": 0.0
			},
			{
				"generator_type": "Filtered_Noise",
				"noise_type": "Pink",
				"filter": {
					"type": "HighPass",
					"cutoff_hz": 800.0,
					"resonance_q": 1.0
				},
				"gain_db": -6.0
			},
			{
				"generator_type": "Sub_Rumble",
				"base_freq": 50.0,
				"gain_db": -3.0
			}
		]
	}
	var stream_multi = ModularSynthEngineClass.synthesize_wav(multi_layer_preset, 777)
	if stream_multi == null or not (stream_multi is AudioStreamWAV):
		failures.append("Test 16 Failed: synthesize_wav with Layer_Container did not return AudioStreamWAV")
	else:
		if stream_multi.data.is_empty():
			failures.append("Test 16 Failed: Layer_Container stream data is empty")
		if stream_multi.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			failures.append("Test 16 Failed: Layer_Container stream loop_mode should be LOOP_DISABLED")
		var expected_bytes = int(0.4 * 44100) * 2
		if stream_multi.data.size() != expected_bytes:
			failures.append("Test 16 Failed: Layer_Container data byte size mismatch (got %d, expected %d)" % [stream_multi.data.size(), expected_bytes])

	return failures

static func _calculate_rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum_sq: float = 0.0
	for s in samples:
		sum_sq += s * s
	return sqrt(sum_sq / float(samples.size()))

static func _calculate_slice_rms(samples: PackedFloat32Array, start_idx: int, end_idx: int) -> float:
	start_idx = clampi(start_idx, 0, samples.size())
	end_idx = clampi(end_idx, start_idx, samples.size())
	var count = end_idx - start_idx
	if count <= 0:
		return 0.0
	var sum_sq: float = 0.0
	for i in range(start_idx, end_idx):
		sum_sq += samples[i] * samples[i]
	return sqrt(sum_sq / float(count))
