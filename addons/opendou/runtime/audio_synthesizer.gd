@tool
class_name AudioSynthesizer
extends RefCounted

## Utility to synthesize high-quality audible PCM AudioStreamWAV resources for OpenDou demos and runtime testing.

## Creates a 16-bit 44.1kHz mono AudioStreamWAV containing a synthesized frequency tone.
static func create_tone(freq_hz: float = 440.0, duration_sec: float = 0.5, volume: float = 0.5, has_decay: bool = true) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = exp(-4.0 * t / duration_sec) if has_decay else 1.0
		var sample: float = sin(t * freq_hz * TAU) * volume * env
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	return stream

## Creates a rhythmic synthesized footstep AudioStreamWAV with specific acoustic characteristics.
static func create_footstep(surface: StringName, variation: int = 1) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.22
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	var var_offset: float = float(variation) * 15.0
	
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = exp(-18.0 * t)
		var sample: float = 0.0
		
		match surface:
			&"Wood":
				# Warm wooden thud (140Hz resonance + punch)
				var f = 140.0 + var_offset
				sample = (sin(t * f * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.2) * env
			&"Concrete":
				# Crisp high-impact snap (noise burst + 400Hz body)
				sample = ((randf() * 2.0 - 1.0) * 0.6 + sin(t * (380.0 + var_offset) * TAU) * 0.4) * env
			&"Metal":
				# High-pitched resonant metallic ringing (1400Hz + 2200Hz)
				var ring_env: float = exp(-10.0 * t)
				var f1 = 1400.0 + var_offset * 3.0
				var f2 = 2200.0 + var_offset * 4.0
				sample = (sin(t * f1 * TAU) * 0.4 + sin(t * f2 * TAU) * 0.4 + (randf() * 2.0 - 1.0) * 0.2) * ring_env
			&"Water":
				# Splashy squish noise burst with water transients
				var splash_env: float = exp(-12.0 * t)
				sample = ((randf() * 2.0 - 1.0) * 0.7 + sin(t * 800.0 * TAU) * 0.3) * splash_env
			_:
				sample = (randf() * 2.0 - 1.0) * env
				
		var s16: int = clampi(int(sample * 30000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.resource_name = "%s_%d.wav" % [str(surface).to_lower(), variation]
	return stream

## Creates a gunshot burst AudioStreamWAV.
static func create_gunshot(duration: float = 0.3) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = exp(-12.0 * t)
		var pop: float = sin(t * (120.0 * exp(-20.0 * t)) * TAU) * 0.5
		var noise: float = (randf() * 2.0 - 1.0) * 0.5
		var sample: float = (pop + noise) * env
		var s16: int = clampi(int(sample * 32000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	return stream

## Creates an ambient musical synth chord loop (A Major pad: 220, 277.18, 330, 440 Hz).
static func create_chord_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var s1 = sin(t * 220.0 * TAU) * 0.25
		var s2 = sin(t * 277.18 * TAU) * 0.25
		var s3 = sin(t * 330.0 * TAU) * 0.25
		var s4 = sin(t * 440.0 * TAU) * 0.2
		var sample = (s1 + s2 + s3 + s4)
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a looping engine combustion pulse AudioStreamWAV.
static func create_engine_loop(base_freq: float = 55.0, duration_sec: float = 1.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		# Multi-harmonic engine rumble
		var h1 = sin(t * base_freq * TAU) * 0.4
		var h2 = sin(t * base_freq * 2.0 * TAU) * 0.3
		var h3 = sin(t * base_freq * 3.0 * TAU) * 0.2
		var h4 = sin(t * base_freq * 4.0 * TAU) * 0.1
		var sample = (h1 + h2 + h3 + h4)
		var s16: int = clampi(int(sample * 30000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a lush ambient pad chord loop (Layer 1).
static func create_music_pad_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var s1 = sin(t * 196.0 * TAU) * 0.3 # G3
		var s2 = sin(t * 246.94 * TAU) * 0.25 # B3
		var s3 = sin(t * 293.66 * TAU) * 0.25 # D4
		var s4 = sin(t * 392.0 * TAU) * 0.2 # G4
		var sample = (s1 + s2 + s3 + s4) * (0.8 + sin(t * TAU * 0.5) * 0.2)
		var s16: int = clampi(int(sample * 26000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates an energetic rhythmic bassline loop (Layer 2).
static func create_music_bass_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var beat_t = fposmod(t * 4.0, 1.0)
		var env = exp(-6.0 * beat_t)
		var f = 98.0 if t < 1.0 else 87.3 # G2 / F2
		var sample = (sin(t * f * TAU) * 0.6 + sin(t * f * 2.0 * TAU) * 0.4) * env
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a rhythmic drum beat loop (Layer 3).
static func create_music_drums_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var beat_t = fposmod(t * 4.0, 1.0)
		var beat_idx = int(t * 4.0) % 4
		var sample = 0.0
		if beat_idx == 0 or beat_idx == 2:
			# Kick: pitch drop 150Hz -> 45Hz
			var kick_env = exp(-14.0 * beat_t)
			sample += sin(beat_t * (150.0 * exp(-20.0 * beat_t) + 45.0) * TAU) * kick_env * 0.8
		else:
			# Snare: noise burst + 200Hz body
			var snare_env = exp(-10.0 * beat_t)
			sample += ((randf() * 2.0 - 1.0) * 0.6 + sin(beat_t * 220.0 * TAU) * 0.4) * snare_env * 0.7
		# Hi-hat on eighth notes
		var hat_t = fposmod(t * 8.0, 1.0)
		var hat_env = exp(-35.0 * hat_t)
		sample += (randf() * 2.0 - 1.0) * hat_env * 0.25
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates an epic orchestral brass climax loop (Layer 4).
static func create_music_brass_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var b1 = sin(t * 392.0 * TAU) * 0.35 # G4
		var b2 = sin(t * 493.88 * TAU) * 0.3 # B4
		var b3 = sin(t * 587.33 * TAU) * 0.25 # D5
		var b4 = sin(t * 784.0 * TAU) * 0.2 # G5
		var sample = (b1 + b2 + b3 + b4) * (0.85 + sin(t * TAU * 1.5) * 0.15)
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a celebratory brass fanfare stinger (Victory_Brass).
static func create_stinger_fanfare(duration_sec: float = 1.5) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env = exp(-3.0 * t / duration_sec)
		# Ascending arpeggio notes across 1.5 seconds
		var f = 523.25 # C5
		if t < 0.15: f = 261.63 # C4
		elif t < 0.30: f = 329.63 # E4
		elif t < 0.45: f = 392.0 # G4
		var sample = (sin(t * f * TAU) * 0.5 + sin(t * f * 2.0 * TAU) * 0.3 + sin(t * f * 3.0 * TAU) * 0.2) * env
		var s16: int = clampi(int(sample * 30000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

## Creates an ominous danger impact stinger (Danger_Hit).
static func create_stinger_impact(duration_sec: float = 1.2) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env = exp(-5.0 * t)
		var bass_f = 65.0 * exp(-8.0 * t) + 35.0
		var sub = sin(t * bass_f * TAU) * 0.7
		var noise = (randf() * 2.0 - 1.0) * exp(-20.0 * t) * 0.5
		var sample = (sub + noise) * env
		var s16: int = clampi(int(sample * 30000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

## Creates a soothing continuous rain atmospheric loop with gentle droplet transients.
static func create_rain_ambient_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	var last_noise: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		# Pink noise filter (low-pass smooth noise)
		var white = (randf() * 2.0 - 1.0)
		last_noise = (last_noise * 0.92) + (white * 0.08)
		# Periodic gentle droplet pings
		var drop_pulse = sin(t * 12.0 * TAU)
		var drop = (sin(t * 1800.0 * TAU) * 0.15) if drop_pulse > 0.96 else 0.0
		var sample = last_noise * 0.45 + drop
		var s16: int = clampi(int(sample * 24000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a soft 50Hz/100Hz transformer electrical hum for server rooms.
static func create_server_ambient_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var h1 = sin(t * 50.0 * TAU) * 0.4
		var h2 = sin(t * 100.0 * TAU) * 0.25
		var h3 = sin(t * 150.0 * TAU) * 0.1
		var fan_noise = ((randf() * 2.0 - 1.0) * 0.08)
		var sample = (h1 + h2 + h3 + fan_noise) * 0.4
		var s16: int = clampi(int(sample * 22000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a subtle underground water stream / trickling loop.
static func create_water_stream_ambient_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	var stream_filter: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var white = (randf() * 2.0 - 1.0)
		stream_filter = (stream_filter * 0.85) + (white * 0.15)
		var bubble = sin(t * 440.0 * (1.0 + sin(t * 8.0 * TAU) * 0.3) * TAU) * 0.12
		var sample = (stream_filter * 0.5 + bubble) * 0.4
		var s16: int = clampi(int(sample * 24000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a gentle nature / atmospheric foley loop (sparkles and soft pads).
static func create_nature_foley_loop(duration_sec: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(duration_sec * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var s1 = sin(t * 261.63 * TAU) * 0.25 # C4
		var s2 = sin(t * 329.63 * TAU) * 0.25 # E4
		var s3 = sin(t * 392.00 * TAU) * 0.20 # G4
		var s4 = sin(t * 523.25 * TAU) * 0.15 # C5
		var chime = (s1 + s2 + s3 + s4) * (0.6 + sin(t * TAU * 1.0) * 0.4)
		var s16: int = clampi(int(chime * 20000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	return stream

## Creates a lush looping canopy wind atmospheric sound with undulating gusts and foliage rustle.
static func create_canopy_wind_loop(duration: float = 3.0, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	var lp_filter: float = 0.0
	var mid_filter: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var white: float = (randf() * 2.0 - 1.0)
		# Gust modulation with sinusoidal LFOs aligned to loop duration
		var lfo1: float = sin(t / duration * TAU * 1.0) * 0.5 + 0.5
		var lfo2: float = sin(t / duration * TAU * 2.0) * 0.3 + 0.5
		var gust_intensity: float = (lfo1 * 0.6 + lfo2 * 0.4)
		
		# Low frequency wind body
		var alpha_lp: float = 0.04 + gust_intensity * 0.04
		lp_filter = (lp_filter * (1.0 - alpha_lp)) + (white * alpha_lp)
		
		# Foliage mid-high rustle
		var alpha_mid: float = 0.18 + gust_intensity * 0.12
		mid_filter = (mid_filter * (1.0 - alpha_mid)) + (white * alpha_mid)
		var rustle: float = (mid_filter - lp_filter) * (0.2 + gust_intensity * 0.3)
		
		# Subtle sub body
		var sub_wind: float = sin(t * 45.0 * TAU) * 0.08 * gust_intensity
		
		var sample: float = (lp_filter * 1.6 + rustle + sub_wind) * (0.7 + gust_intensity * 0.3)
		var s16: int = clampi(int(sample * 24000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a vibrant avian bird chirp chorus with natural pauses and trill sweeps (looping).
static func create_bird_chirp(base_frequency: float = 2400.0, duration: float = 3.0, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var sample: float = 0.0
		
		# Chirp 1 at t ~ 0.2s
		var t1: float = t - 0.2
		if t1 >= 0.0 and t1 < 0.35:
			var p1: float = t1 / 0.35
			var f1: float = base_frequency * (1.0 + sin(p1 * PI) * 0.45 + sin(p1 * TAU * 4.0) * 0.12)
			var env1: float = pow(sin(p1 * PI), 1.2)
			sample += (sin(t1 * f1 * TAU) * 0.75 + sin(t1 * f1 * 2.0 * TAU) * 0.25) * env1
			
		# Chirp 2 at t ~ 0.8s
		var t2: float = t - 0.8
		if t2 >= 0.0 and t2 < 0.25:
			var p2: float = t2 / 0.25
			var f2: float = (base_frequency * 1.25) * (1.0 + sin(p2 * PI) * 0.35)
			var env2: float = pow(sin(p2 * PI), 1.2)
			sample += sin(t2 * f2 * TAU) * env2 * 0.85
			
		# Chirp 3 at t ~ 1.8s
		var t3: float = t - 1.8
		if t3 >= 0.0 and t3 < 0.4:
			var p3: float = t3 / 0.4
			var f3: float = (base_frequency * 0.9) * (1.0 + sin(p3 * PI * 2.0) * 0.3)
			var env3: float = pow(sin(p3 * PI), 1.2)
			sample += (sin(t3 * f3 * TAU) * 0.8 + sin(t3 * f3 * 1.5 * TAU) * 0.2) * env3
			
		var s16: int = clampi(int(sample * 26000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a deep procedural thunder rumble with continuous rolling sub-bass and seismic aftershocks (looping).
static func create_thunder_rumble(duration: float = 3.5, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	var noise_filter: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var progress: float = t / duration
		var white: float = (randf() * 2.0 - 1.0)
		noise_filter = (noise_filter * 0.94) + (white * 0.06)
		
		# Rolling swells that repeat seamlessly in the loop
		var swell1: float = sin(progress * TAU * 1.0) * 0.5 + 0.5
		var swell2: float = sin(progress * TAU * 3.0) * 0.35 + 0.35
		var rumble_env: float = (swell1 * 0.6 + swell2 * 0.4)
		
		# Deep sub-bass (38Hz - 62Hz)
		var sub_f: float = 45.0 + sin(progress * TAU * 2.0) * 12.0
		var sub: float = sin(t * sub_f * TAU) * 0.55 + sin(t * sub_f * 0.5 * TAU) * 0.3
		
		var sample: float = (noise_filter * 1.5 + sub) * rumble_env * 0.75
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a dense looping cicada swarm texture with pulsating high-frequency carrier buzzing.
static func create_cicada_swarm_loop(duration: float = 2.0, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var pulse: float = maxf(0.0, sin(t / duration * TAU * 16.0))
		pulse = pulse * pulse
		
		var c1: float = sin(t * 5200.0 * TAU) * 0.35
		var c2: float = sin(t * 5850.0 * TAU) * 0.30
		var c3: float = sin(t * 6600.0 * TAU) * 0.25
		var white_hiss: float = (randf() * 2.0 - 1.0) * 0.1
		
		var sample: float = (c1 + c2 + c3 + white_hiss) * (0.25 + pulse * 0.75) * 0.55
		var s16: int = clampi(int(sample * 24000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates an active amphibian frog pond chorus with alternating guttural ribbits (looping).
static func create_frog_croak(duration: float = 2.5, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var sample: float = 0.0
		
		# Frog 1 croak at t ~ 0.3s
		var t1: float = t - 0.3
		if t1 >= 0.0 and t1 < 0.45:
			var p1: float = t1 / 0.45
			var pulse1: float = pow(maxf(0.0, sin(t1 * 36.0 * TAU)), 3.0)
			var f1: float = 260.0 * (1.0 + sin(p1 * PI) * 0.15)
			var c1: float = sin(t1 * f1 * TAU) * 0.6 + sin(t1 * f1 * 2.5 * TAU) * 0.4
			sample += c1 * pulse1 * sin(p1 * PI) * 0.8
			
		# Frog 2 croak at t ~ 1.4s (different pitch/speed)
		var t2: float = t - 1.4
		if t2 >= 0.0 and t2 < 0.5:
			var p2: float = t2 / 0.5
			var pulse2: float = pow(maxf(0.0, sin(t2 * 42.0 * TAU)), 3.0)
			var f2: float = 340.0 * (1.0 + sin(p2 * PI) * 0.1)
			var c2: float = sin(t2 * f2 * TAU) * 0.5 + sin(t2 * f2 * 2.0 * TAU) * 0.5
			sample += c2 * pulse2 * sin(p2 * PI) * 0.75
			
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a gentle trickling cadence of 3D water droplets scattering across time (looping).
static func create_water_droplet(pitch: float = 1200.0, sample_rate: int = 44100) -> AudioStreamWAV:
	var duration: float = 2.0
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var sample: float = 0.0
		
		# Drop 1 at t ~ 0.15s
		var t1: float = t - 0.15
		if t1 >= 0.0 and t1 < 0.12:
			var p1: float = t1 / 0.12
			var f1: float = pitch * (0.7 + 0.75 * exp(-12.0 * p1))
			sample += sin(t1 * f1 * TAU) * exp(-28.0 * p1) * 0.6
			
		# Drop 2 at t ~ 0.75s (lower pitch)
		var t2: float = t - 0.75
		if t2 >= 0.0 and t2 < 0.12:
			var p2: float = t2 / 0.12
			var f2: float = (pitch * 0.85) * (0.7 + 0.75 * exp(-12.0 * p2))
			sample += sin(t2 * f2 * TAU) * exp(-28.0 * p2) * 0.65
			
		# Drop 3 at t ~ 1.45s (higher pitch)
		var t3: float = t - 1.45
		if t3 >= 0.0 and t3 < 0.12:
			var p3: float = t3 / 0.12
			var f3: float = (pitch * 1.3) * (0.7 + 0.75 * exp(-12.0 * p3))
			sample += sin(t3 * f3 * TAU) * exp(-28.0 * p3) * 0.55
			
		var s16: int = clampi(int(sample * 28000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

## Creates a flying insect / cyber-hornet buzz with rapid flutter amplitude modulation (looping).
static func create_cyber_hornet_loop(duration: float = 1.5, sample_rate: int = 44100) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var wing_flutter: float = sin(t * 85.0 * TAU) * 0.4 + 0.6
		var pitch_drift: float = 180.0 + sin(t * 4.0 * TAU) * 25.0
		
		# Wing saw-like harmonics
		var h1: float = sin(t * pitch_drift * TAU) * 0.5
		var h2: float = sin(t * pitch_drift * 2.0 * TAU) * 0.3
		var h3: float = sin(t * pitch_drift * 3.0 * TAU) * 0.15
		var buzz: float = (h1 + h2 + h3) * wing_flutter
		
		var s16: int = clampi(int(buzz * 26000.0), -32768, 32767)
		byte_data.encode_s16(i * 2, s16)
		
	var stream = AudioStreamWAV.new()
	stream.data = byte_data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_samples
	stream.stereo = false
	return stream

