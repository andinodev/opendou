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
static func create_gunshot() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var duration: float = 0.35
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
