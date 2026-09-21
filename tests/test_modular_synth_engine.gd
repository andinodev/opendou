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

	# Test 17: start_offset places a layer on the time axis
	# Without it every layer starts at t=0, so a gunshot cannot spread transient,
	# body, mechanism and tail: everything stacks on the same instant and the
	# result is a blip. Absent means 0.0, so existing presets are untouched.
	var offset_preset = {
		"type": "Layer_Container",
		"duration": 0.2,
		"layers": [
			{
				"name": "late",
				"generator_type": "Basic_Wave",
				"wave_type": "Sine",
				"base_freq": 440.0,
				"duration": 0.1,
				"start_offset": 0.1
			}
		]
	}
	var stream_offset = ModularSynthEngineClass.synthesize_wav(offset_preset, 7)
	if stream_offset == null or not (stream_offset is AudioStreamWAV):
		failures.append("Test 17 Failed: synthesize_wav with start_offset returned no stream")
	else:
		var off_samples = _decode_mono(stream_offset)
		# 0.1 s at 44100 Hz is 4410 samples of EXACT silence, not near-silence.
		var dirty = 0
		for i in range(mini(4410, off_samples.size())):
			if absf(off_samples[i]) > 0.0:
				dirty += 1
		if dirty != 0:
			failures.append("Test 17 Failed: %d non-silent samples before start_offset" % dirty)
		# And there must be signal after it, or an empty buffer would pass.
		if _calculate_slice_rms(off_samples, 4410, off_samples.size()) <= 0.01:
			failures.append("Test 17 Failed: no signal after start_offset")

	# Test 18: the container grows to cover the latest layer
	# The layer ends at 0.3 + 0.2 = 0.5 s, well past the declared 0.2. If the
	# container does not grow, the tail is cut mid-decay.
	var grow_preset = {
		"type": "Layer_Container",
		"duration": 0.2,
		"layers": [
			{
				"name": "tail",
				"generator_type": "Basic_Wave",
				"wave_type": "Sine",
				"base_freq": 220.0,
				"duration": 0.2,
				"start_offset": 0.3
			}
		]
	}
	var stream_grow = ModularSynthEngineClass.synthesize_wav(grow_preset, 7)
	if stream_grow == null:
		failures.append("Test 18 Failed: synthesize_wav returned no stream")
	else:
		var expected_grow = int(0.5 * 44100) * 2
		if absi(stream_grow.data.size() - expected_grow) > 2:
			failures.append("Test 18 Failed: container did not grow (got %d bytes, expected %d)" % [stream_grow.data.size(), expected_grow])

	# Test 19: a start_offset of 0.0 is identical to not declaring it
	# This is the backward-compatibility guarantee: every preset authored before
	# the field existed must render byte for byte the same.
	var plain_layer = {
		"name": "x",
		"generator_type": "Basic_Wave",
		"wave_type": "Sine",
		"base_freq": 330.0,
		"duration": 0.1
	}
	var zero_layer = plain_layer.duplicate(true)
	zero_layer["start_offset"] = 0.0
	var stream_plain = ModularSynthEngineClass.synthesize_wav(
		{"type": "Layer_Container", "duration": 0.1, "layers": [plain_layer]}, 11)
	var stream_zero = ModularSynthEngineClass.synthesize_wav(
		{"type": "Layer_Container", "duration": 0.1, "layers": [zero_layer]}, 11)
	if stream_plain == null or stream_zero == null:
		failures.append("Test 19 Failed: synthesize_wav returned no stream")
	elif stream_plain.data != stream_zero.data:
		failures.append("Test 19 Failed: start_offset 0.0 changed the output")

	# Test 20: filter envelope sweeps the cutoff over time
	# A static cutoff is the other reason a synthesized gunshot sounds like a
	# blip: a real shot decays from bright to dark in tens of milliseconds. With
	# cutoff_hz as the destination and envelope.start_hz as the origin, white
	# noise swept from 9 kHz to 400 Hz must be far brighter in its first third.
	var sweep_layer = {
		"generator_type": "Filtered_Noise",
		"noise_type": "White",
		"filter": {
			"type": "LowPass",
			"resonance_q": 0.9,
			"cutoff_hz": 400.0,
			"envelope": {"start_hz": 9000.0, "decay": 0.04}
		}
	}
	var sweep_samples = ModularSynthEngineClass.generate_layer_samples(sweep_layer, 0.3, 44100, 13)
	if sweep_samples.is_empty():
		failures.append("Test 20 Failed: filter envelope produced no samples")
	else:
		var third = sweep_samples.size() / 3
		var bright = _count_zero_crossings(sweep_samples, 0, third)
		var dark = _count_zero_crossings(sweep_samples, third * 2, sweep_samples.size())
		if bright <= dark * 2:
			failures.append("Test 20 Failed: cutoff did not sweep down (%d crossings early, %d late)" % [bright, dark])

	# Test 21: a filter with no envelope behaves exactly as before
	# Backward compatibility for every preset authored against the static filter.
	var static_layer = {
		"generator_type": "Filtered_Noise",
		"noise_type": "White",
		"filter": {"type": "LowPass", "resonance_q": 0.9, "cutoff_hz": 1200.0}
	}
	var static_a = ModularSynthEngineClass.generate_layer_samples(static_layer, 0.15, 44100, 23)
	var static_b = ModularSynthEngineClass.generate_layer_samples(static_layer, 0.15, 44100, 23)
	if static_a != static_b:
		failures.append("Test 21 Failed: static filter is not deterministic")
	else:
		var s_third = static_a.size() / 3
		var s_early = _count_zero_crossings(static_a, 0, s_third)
		var s_late = _count_zero_crossings(static_a, s_third * 2, static_a.size())
		# No sweep means the brightness holds. If the late third darkened, the
		# envelope was applied without being asked for.
		if absi(s_early - s_late) >= maxi(s_early, s_late) / 2:
			failures.append("Test 21 Failed: brightness drifted without an envelope (%d vs %d)" % [s_early, s_late])

	# Test 22: a Layer_Container is NOT a layer, and treating it as one is garbage
	# This pins the bug behind the Synth Rack waveform fix. The workspace drew its
	# preview by passing the whole container to generate_layer_samples, which
	# finds no generator_type and falls through to the default Basic_Wave sine at
	# 440 Hz. Every layered preset drew the same perfect sine regardless of its
	# contents, while the play button (synthesize_wav) played the real thing.
	var container_preset = {
		"type": "Layer_Container",
		"duration": 0.2,
		"layers": [
			{
				"name": "noise",
				"generator_type": "Filtered_Noise",
				"noise_type": "White",
				"duration": 0.2
			}
		]
	}
	var as_layer = ModularSynthEngineClass.generate_layer_samples(container_preset, 0.2, 44100, 100)
	var as_container = _decode_mono(ModularSynthEngineClass.synthesize_wav(container_preset, 100))
	if as_layer.is_empty() or as_container.is_empty():
		failures.append("Test 22 Failed: one of the two renders came back empty")
	else:
		# The wrong path is a clean sine: a 440 Hz sine crosses zero about 880
		# times per second, so ~176 in 0.2 s. White noise crosses far more often.
		var sine_crossings = _count_zero_crossings(as_layer, 0, as_layer.size())
		var noise_crossings = _count_zero_crossings(as_container, 0, as_container.size())
		if sine_crossings > 400:
			failures.append("Test 22 Failed: expected the container-as-layer path to yield a plain sine, got %d crossings" % sine_crossings)
		if noise_crossings <= sine_crossings * 2:
			failures.append("Test 22 Failed: synthesize_wav should render the actual noise layer (%d vs %d crossings)" % [noise_crossings, sine_crossings])

	return failures

## Rough brightness proxy: a bright signal crosses zero far more often than a
## dark one. Comparing two thirds of the SAME signal needs nothing finer, and it
## avoids pulling an FFT into the test suite.
static func _count_zero_crossings(samples: PackedFloat32Array, start_idx: int, end_idx: int) -> int:
	start_idx = clampi(start_idx, 1, samples.size())
	end_idx = clampi(end_idx, start_idx, samples.size())
	var n: int = 0
	for i in range(start_idx, end_idx):
		if (samples[i - 1] < 0.0) != (samples[i] < 0.0):
			n += 1
	return n

## Samples of a 16-bit stream in [-1, 1]. Stereo returns the left channel.
static func _decode_mono(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	if stream == null:
		return out
	var step: int = 4 if stream.stereo else 2
	var n: int = stream.data.size() / step
	out.resize(n)
	for i in range(n):
		out[i] = float(stream.data.decode_s16(i * step)) / 32768.0
	return out

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
