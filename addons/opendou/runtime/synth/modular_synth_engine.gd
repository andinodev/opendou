@tool
class_name ModularSynthEngine
extends RefCounted

## Modular DSP procedural audio synthesis engine for OpenDou.
## Supports 9 DSP generators, physical modeling, phase modulation, ADSR envelopes,
## LFOs, 2nd-order Biquad filtering, non-linear distortion drive, and multi-layer compounding.

## 2nd-order Biquad filter implementation based on RBJ Audio EQ Cookbook formulas.
class Biquad:
	var b0: float = 1.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0

	func setup(filter_type: String, cutoff_hz: float, q: float, sample_rate: float) -> void:
		cutoff_hz = clampf(cutoff_hz, 10.0, sample_rate * 0.49)
		q = maxf(q, 0.1)
		var w0: float = TAU * cutoff_hz / sample_rate
		var cos_w0: float = cos(w0)
		var sin_w0: float = sin(w0)
		var alpha: float = sin_w0 / (2.0 * q)
		var a0: float = 1.0 + alpha

		match filter_type:
			"LowPass":
				b0 = ((1.0 - cos_w0) / 2.0) / a0
				b1 = (1.0 - cos_w0) / a0
				b2 = ((1.0 - cos_w0) / 2.0) / a0
				a1 = (-2.0 * cos_w0) / a0
				a2 = (1.0 - alpha) / a0
			"HighPass":
				b0 = ((1.0 + cos_w0) / 2.0) / a0
				b1 = (-(1.0 + cos_w0)) / a0
				b2 = ((1.0 + cos_w0) / 2.0) / a0
				a1 = (-2.0 * cos_w0) / a0
				a2 = (1.0 - alpha) / a0
			"BandPass":
				b0 = (sin_w0 / 2.0) / a0
				b1 = 0.0
				b2 = (-sin_w0 / 2.0) / a0
				a1 = (-2.0 * cos_w0) / a0
				a2 = (1.0 - alpha) / a0
			_:
				b0 = 1.0
				b1 = 0.0
				b2 = 0.0
				a1 = 0.0
				a2 = 0.0

	func process(x: float) -> float:
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y

## Applies non-linear waveshaping distortion drive to a single sample.
static func apply_drive(sample: float, drive_type: String, drive_amount: float) -> float:
	var amt: float = maxf(drive_amount, 0.001)
	match drive_type:
		"Soft_Clip":
			return tanh(sample * amt)
		"Hard_Clip":
			return clampf(sample * amt, -1.0, 1.0)
		"Foldback":
			return sin(sample * amt)
		_:
			return sample

## Generates a buffer of 32-bit floating point audio samples for a single synthesis layer.
static func generate_layer_samples(layer_dict: Dictionary, duration: float, sample_rate: int = 44100, rng_seed: int = 0) -> PackedFloat32Array:
	if duration <= 0.0:
		duration = float(layer_dict.get("duration", 1.0))
	duration = maxf(duration, 0.001)
	sample_rate = maxi(sample_rate, 8000)

	var num_samples: int = int(duration * sample_rate)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)

	var rng = RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	# Base frequency and stochastic variation
	var base_freq: float = float(layer_dict.get("base_freq", 440.0))
	var base_freq_var: float = float(layer_dict.get("base_freq_var", 0.0))
	if base_freq_var > 0.0:
		base_freq *= (1.0 + rng.randf_range(-base_freq_var, base_freq_var))
	base_freq = maxf(base_freq, 1.0)

	# Pitch Envelope parameters
	var pitch_env_dict: Dictionary = layer_dict.get("pitch_envelope", {})
	var pitch_amount_st: float = float(pitch_env_dict.get("amount_st", 0.0))
	var pitch_decay_time: float = maxf(0.001, float(pitch_env_dict.get("decay", 0.1)))

	# LFO parameters
	var lfo_dict: Dictionary = layer_dict.get("lfo", {})
	var lfo_depth: float = float(lfo_dict.get("depth", 0.0))
	var lfo_wave: String = lfo_dict.get("wave", "Sine")
	var lfo_rate: float = float(lfo_dict.get("rate_hz", 2.0))
	var lfo_target: String = lfo_dict.get("target", "Amplitude")

	var gen_type: String = layer_dict.get("generator_type", "Basic_Wave")

	match gen_type:
		"Filtered_Noise":
			var noise_type: String = layer_dict.get("noise_type", layer_dict.get("sub_type", "White"))
			var b0: float = 0.0
			var b1: float = 0.0
			var b2: float = 0.0
			var b3: float = 0.0
			var b4: float = 0.0
			var b5: float = 0.0
			var b6: float = 0.0
			var brown: float = 0.0

			for i in range(num_samples):
				var white: float = rng.randf_range(-1.0, 1.0)
				match noise_type:
					"Pink":
						b0 = 0.99886 * b0 + white * 0.0555179
						b1 = 0.99332 * b1 + white * 0.0750759
						b2 = 0.96900 * b2 + white * 0.1538520
						b3 = 0.86650 * b3 + white * 0.3104856
						b4 = 0.55000 * b4 + white * 0.5329522
						b5 = -0.7616 * b5 - white * 0.0168980
						var pink: float = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
						b6 = white * 0.115926
						samples[i] = pink * 0.12
					"Brown":
						brown = (brown + 0.02 * white) / 1.02
						samples[i] = brown * 3.5
					_: # White
						samples[i] = white

		"FM_Chirp":
			var mod_mult: float = float(layer_dict.get("mod_mult", layer_dict.get("modulator_ratio", 2.0)))
			var mod_index: float = float(layer_dict.get("mod_index", layer_dict.get("fm_index", 2.0)))
			var sweep_dict: Dictionary = layer_dict.get("frequency_sweep", {})
			var start_mult: float = float(sweep_dict.get("start_mult", 1.0))
			var end_mult: float = float(sweep_dict.get("end_mult", 1.0))
			var trill_rate: float = float(sweep_dict.get("trill_rate", 0.0))
			var carrier_phase: float = 0.0
			var mod_phase: float = 0.0

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var p: float = t / duration if duration > 0.0 else 0.0
				var sweep: float = lerpf(start_mult, end_mult, p)
				if trill_rate > 0.0:
					sweep += sin(t * trill_rate * TAU) * 0.15

				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var st_lfo: float = _calculate_lfo_val(t, lfo_rate, lfo_wave) * lfo_depth * 12.0 if (lfo_target == "Pitch" and lfo_depth > 0.0) else 0.0
				var pitch_mult: float = pow(2.0, (st_env + st_lfo) / 12.0)

				var inst_f: float = base_freq * sweep * pitch_mult
				var inst_mod_f: float = inst_f * mod_mult
				carrier_phase += TAU * inst_f / sample_rate
				mod_phase += TAU * inst_mod_f / sample_rate
				samples[i] = sin(carrier_phase + mod_index * sin(mod_phase))

		"Karplus_Strong":
			var decay_factor: float = float(layer_dict.get("decay_factor", 0.985))
			var damping: float = float(layer_dict.get("damping", 0.5))
			var N: int = maxi(2, int(float(sample_rate) / base_freq))
			var ring_buf = PackedFloat32Array()
			ring_buf.resize(N)
			for j in range(N):
				ring_buf[j] = rng.randf_range(-1.0, 1.0)

			for i in range(num_samples):
				var curr_idx: int = i % N
				var prev_idx: int = (i - 1 + N) % N
				var val: float = (damping * ring_buf[curr_idx] + (1.0 - damping) * ring_buf[prev_idx]) * decay_factor
				ring_buf[curr_idx] = val
				samples[i] = val

		"Wavetable_PM":
			var pm_index: float = float(layer_dict.get("phase_modulation_index", layer_dict.get("pm_index", 2.0)))
			var mod_freq: float = float(layer_dict.get("mod_freq", base_freq * float(layer_dict.get("mod_ratio", 2.0))))
			var carrier_phase: float = 0.0
			var mod_phase: float = 0.0

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var st_lfo: float = _calculate_lfo_val(t, lfo_rate, lfo_wave) * lfo_depth * 12.0 if (lfo_target == "Pitch" and lfo_depth > 0.0) else 0.0
				var pitch_mult: float = pow(2.0, (st_env + st_lfo) / 12.0)

				carrier_phase += TAU * (base_freq * pitch_mult) / sample_rate
				mod_phase += TAU * (mod_freq * pitch_mult) / sample_rate
				samples[i] = sin(carrier_phase + pm_index * sin(mod_phase))

		"Harmonic_Buzz":
			var harmonics: int = clampi(int(layer_dict.get("harmonics", layer_dict.get("num_harmonics", 8))), 1, 32)
			var flutter_rate: float = float(layer_dict.get("flutter_rate", 5.0))
			var flutter_depth: float = float(layer_dict.get("flutter_depth", 0.05))

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var flutter: float = sin(t * flutter_rate * TAU) * flutter_depth
				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var st_lfo: float = _calculate_lfo_val(t, lfo_rate, lfo_wave) * lfo_depth * 12.0 if (lfo_target == "Pitch" and lfo_depth > 0.0) else 0.0
				var pitch_mult: float = pow(2.0, (st_env + st_lfo) / 12.0)
				var f0: float = base_freq * pitch_mult

				var sum: float = 0.0
				for k in range(1, harmonics + 1):
					var amp: float = 1.0 / float(k)
					sum += sin(t * f0 * float(k) * (1.0 + flutter * (float(k) * 0.1)) * TAU) * amp
				samples[i] = sum * 0.5

		"Sub_Rumble":
			var swell_rate: float = float(layer_dict.get("swell_rate", 1.5))
			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var swell: float = 0.7 + 0.3 * sin(t * swell_rate * TAU)
				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var pitch_mult: float = pow(2.0, st_env / 12.0)
				var f0: float = base_freq * pitch_mult

				var sub: float = sin(t * f0 * TAU) * 0.6 + sin(t * f0 * 0.5 * TAU) * 0.4 + sin(t * f0 * 3.0 * TAU) * 0.1
				sub = tanh(sub * 1.5) * swell
				sub += rng.randf_range(-0.04, 0.04)
				samples[i] = sub

		"Resonant_Formant":
			var formants_arr: Array = layer_dict.get("formants", [500.0, 1500.0, 2500.0])
			var f1: float = formants_arr[0] if formants_arr.size() > 0 else 500.0
			var f2: float = formants_arr[1] if formants_arr.size() > 1 else 1500.0
			var f3: float = formants_arr[2] if formants_arr.size() > 2 else 2500.0

			var bp1 = Biquad.new()
			bp1.setup("BandPass", f1, 6.0, float(sample_rate))
			var bp2 = Biquad.new()
			bp2.setup("BandPass", f2, 6.0, float(sample_rate))
			var bp3 = Biquad.new()
			bp3.setup("BandPass", f3, 6.0, float(sample_rate))

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var pitch_mult: float = pow(2.0, st_env / 12.0)
				var f0: float = base_freq * pitch_mult
				var exc: float = sin(t * f0 * TAU) * 0.5 + sin(t * f0 * 2.0 * TAU) * 0.3 + sin(t * f0 * 3.0 * TAU) * 0.2 + rng.randf_range(-0.05, 0.05)
				samples[i] = (bp1.process(exc) + bp2.process(exc) * 0.7 + bp3.process(exc) * 0.4) * 2.0

		"Impulse_Ping":
			var pitch_mult_factor: float = float(layer_dict.get("pitch_mult", 2.5))
			var ping_pitch_decay: float = maxf(0.001, float(layer_dict.get("pitch_decay", 0.05)))
			var ring_q: float = float(layer_dict.get("ring_q", 12.0))

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var inst_f: float = base_freq * (1.0 + pitch_mult_factor * exp(-t / ping_pitch_decay))
				var decay_env: float = exp(-t * ring_q)
				samples[i] = sin(t * inst_f * TAU) * decay_env

		_: # "Basic_Wave"
			var wave_type: String = layer_dict.get("wave_type", layer_dict.get("wave", "Sine"))
			var phase: float = 0.0

			for i in range(num_samples):
				var t: float = float(i) / sample_rate
				var st_env: float = pitch_amount_st * exp(-t / pitch_decay_time) if pitch_amount_st != 0.0 else 0.0
				var st_lfo: float = _calculate_lfo_val(t, lfo_rate, lfo_wave) * lfo_depth * 12.0 if (lfo_target == "Pitch" and lfo_depth > 0.0) else 0.0
				var pitch_mult: float = pow(2.0, (st_env + st_lfo) / 12.0)
				var inst_f: float = base_freq * pitch_mult

				phase += TAU * inst_f / sample_rate
				match wave_type:
					"Sine":
						samples[i] = sin(phase)
					"Saw", "Sawtooth":
						samples[i] = 2.0 * (fposmod(phase / TAU, 1.0)) - 1.0
					"Square":
						samples[i] = 1.0 if sin(phase) >= 0.0 else -1.0
					"Triangle":
						samples[i] = 2.0 * absf(2.0 * (fposmod(phase / TAU, 1.0) - 0.5)) - 1.0
					_:
						samples[i] = sin(phase)

	# Amplitude ADSR Envelope
	var env_dict: Dictionary = layer_dict.get("envelope", {})
	if not env_dict.is_empty():
		var a: float = float(env_dict.get("attack", 0.01))
		var d: float = float(env_dict.get("decay", 0.1))
		var s: float = float(env_dict.get("sustain", 0.7))
		var r: float = float(env_dict.get("release", 0.1))
		var env_var: float = float(env_dict.get("var", 0.0))
		if env_var > 0.0:
			a *= (1.0 + rng.randf_range(-env_var, env_var))
			d *= (1.0 + rng.randf_range(-env_var, env_var))
			r *= (1.0 + rng.randf_range(-env_var, env_var))
			a = maxf(0.0001, a)
			d = maxf(0.0001, d)
			r = maxf(0.0001, r)

		for i in range(num_samples):
			var t: float = float(i) / sample_rate
			var env_mult: float = _calculate_adsr(t, duration, a, d, s, r)
			samples[i] *= env_mult

	# LFO Amplitude modulation
	if lfo_target == "Amplitude" and lfo_depth > 0.0:
		for i in range(num_samples):
			var t: float = float(i) / sample_rate
			var lfo_val: float = _calculate_lfo_val(t, lfo_rate, lfo_wave)
			samples[i] *= clampf(1.0 + lfo_val * lfo_depth, 0.0, 2.0)

	# Biquad Filter (unless Filtered_Noise which uses filter or other generators)
	var filter_dict: Dictionary = layer_dict.get("filter", {})
	var f_type: String = filter_dict.get("type", "None")
	if f_type != "None" and f_type != "":
		var f_cutoff: float = float(filter_dict.get("cutoff_hz", 2000.0))
		var f_q: float = float(filter_dict.get("resonance_q", 1.0))
		var biquad = Biquad.new()
		biquad.setup(f_type, f_cutoff, f_q, float(sample_rate))
		for i in range(num_samples):
			samples[i] = biquad.process(samples[i])

	# Layer Drive
	var drive_dict: Dictionary = layer_dict.get("drive", {})
	var d_type: String = drive_dict.get("type", "None")
	if d_type != "None" and d_type != "":
		var d_amount: float = float(drive_dict.get("amount", 1.0))
		for i in range(num_samples):
			samples[i] = apply_drive(samples[i], d_type, d_amount)

	# Layer Gain
	var layer_gain_db: float = float(layer_dict.get("gain_db", 0.0))
	if not is_zero_approx(layer_gain_db):
		var gain_lin: float = db_to_linear(layer_gain_db)
		for i in range(num_samples):
			samples[i] *= gain_lin

	return samples

## Synthesizes a ready-to-play AudioStreamWAV resource from a single layer or Layer_Container preset dictionary.
static func synthesize_wav(preset_dict: Dictionary, rng_seed: int = 0) -> AudioStreamWAV:
	var sample_rate: int = int(preset_dict.get("sample_rate", 44100))
	var duration: float = float(preset_dict.get("duration", 1.0))
	var p_type: String = preset_dict.get("type", "Single_Generator")

	var master_buffer = PackedFloat32Array()

	if p_type == "Layer_Container":
		var layers: Array = preset_dict.get("layers", [])
		var max_dur = duration
		for l in layers:
			if l is Dictionary:
				var l_dur = float(l.get("duration", duration))
				if l_dur > max_dur:
					max_dur = l_dur
		duration = max_dur
		var total_samples = int(duration * sample_rate)
		master_buffer.resize(total_samples)

		var layer_idx: int = 0
		for l in layers:
			if l is Dictionary:
				var l_dur = float(l.get("duration", duration))
				var l_seed = rng_seed + layer_idx * 1000 if rng_seed != 0 else 0
				var l_samples = generate_layer_samples(l, l_dur, sample_rate, l_seed)
				var l_gain_db = float(l.get("gain_db", 0.0))
				var l_gain_lin = db_to_linear(l_gain_db)
				var count = mini(master_buffer.size(), l_samples.size())
				for i in range(count):
					master_buffer[i] += l_samples[i] * l_gain_lin
				layer_idx += 1
	else:
		master_buffer = generate_layer_samples(preset_dict, duration, sample_rate, rng_seed)

	var num_samples = master_buffer.size()

	# Master Gain
	var master_gain_db = float(preset_dict.get("gain_db", 0.0))
	if not is_zero_approx(master_gain_db):
		var m_gain_lin = db_to_linear(master_gain_db)
		for i in range(num_samples):
			master_buffer[i] *= m_gain_lin

	# Master Drive
	var master_drive_dict: Dictionary = preset_dict.get("drive", {})
	var m_drive_type = master_drive_dict.get("type", "None")
	if m_drive_type != "None" and m_drive_type != "":
		var m_drive_amt = float(master_drive_dict.get("amount", 1.0))
		for i in range(num_samples):
			master_buffer[i] = apply_drive(master_buffer[i], m_drive_type, m_drive_amt)

	# Convert to 16-bit PCM PackedByteArray
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var s = clampf(master_buffer[i], -1.0, 1.0)
		var s16: int = clampi(int(s * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)

	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	var is_loop = bool(preset_dict.get("loop_mode", false))
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = num_samples
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED

	return stream

static func _calculate_adsr(t: float, total_dur: float, a: float, d: float, s: float, r: float) -> float:
	if total_dur <= 0.0:
		return 1.0
	var release_start: float = maxf(a + d, total_dur - r)
	if t < a:
		return (t / a) if a > 0.0001 else 1.0
	elif t < a + d:
		var p = (t - a) / d if d > 0.0001 else 1.0
		return lerpf(1.0, s, clampf(p, 0.0, 1.0))
	elif t < release_start:
		return s
	else:
		var r_dur = total_dur - release_start
		var p = (t - release_start) / r_dur if r_dur > 0.0001 else 1.0
		return lerpf(s, 0.0, clampf(p, 0.0, 1.0))

static func _calculate_lfo_val(t: float, rate_hz: float, wave_type: String) -> float:
	var phase = fposmod(t * rate_hz, 1.0)
	match wave_type:
		"Sine":
			return sin(phase * TAU)
		"Triangle":
			return 2.0 * absf(2.0 * (phase - 0.5)) - 1.0
		"Saw", "Sawtooth":
			return 2.0 * phase - 1.0
		"Square":
			return 1.0 if phase < 0.5 else -1.0
		_:
			return sin(phase * TAU)
