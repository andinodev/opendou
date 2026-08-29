@tool
class_name AudioGranularSynthesizer
extends RefCounted

## Real-time Granular Synthesizer generating asynchronous micro-sound grains with Hanning windowing, time-stretch, and pitch modulation.

class Grain:
	var start_source_sample: float = 0.0
	var current_source_sample: float = 0.0
	var duration_samples: int = 2048
	var current_sample_idx: int = 0
	var playback_rate: float = 1.0 # 1.0 = normal, 2.0 = octave up, 0.5 = octave down
	var is_active: bool = false

var source_samples: PackedFloat32Array = PackedFloat32Array()

# Synthesis parameters
var grain_size_ms: float = 40.0
var grain_rate_hz: float = 45.0 # Grains spawned per second
var playhead_pos_ratio: float = 0.0 # 0.0 to 1.0 position in source sample
var position_jitter_ms: float = 10.0
var pitch_jitter_semitones: float = 0.0
var sample_rate: int = 44100

var active_grains: Array[Grain] = []
var max_concurrent_grains: int = 32
var grain_spawn_accumulator: float = 0.0

func _init(p_source: PackedFloat32Array = PackedFloat32Array(), p_rate: int = 44100) -> void:
	source_samples = p_source
	sample_rate = p_rate

## Spawns a new grain with Hanning envelope and randomized jitter.
func spawn_grain() -> void:
	if source_samples.is_empty() or active_grains.size() >= max_concurrent_grains:
		return
		
	var g = Grain.new()
	var dur_samples = int((grain_size_ms / 1000.0) * float(sample_rate))
	g.duration_samples = max(dur_samples, 64)
	
	var base_src_idx = playhead_pos_ratio * float(source_samples.size())
	var jitter_samples = (position_jitter_ms / 1000.0) * float(sample_rate) * randf_range(-1.0, 1.0)
	g.start_source_sample = clampf(base_src_idx + jitter_samples, 0.0, float(source_samples.size() - 1))
	g.current_source_sample = g.start_source_sample
	
	var pitch_shift = randf_range(-pitch_jitter_semitones, pitch_jitter_semitones)
	g.playback_rate = pow(2.0, pitch_shift / 12.0)
	g.current_sample_idx = 0
	g.is_active = true
	
	active_grains.append(g)

## Synthesizes a block of audio samples by summing overlapping active grains.
func generate_block(num_samples: int) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	out.resize(num_samples)
	out.fill(0.0)
	
	if source_samples.is_empty():
		return out
		
	var spawn_interval_samples = float(sample_rate) / maxf(grain_rate_hz, 1.0)
	var src_len = source_samples.size()
	
	for i in range(num_samples):
		grain_spawn_accumulator += 1.0
		if grain_spawn_accumulator >= spawn_interval_samples:
			grain_spawn_accumulator -= spawn_interval_samples
			spawn_grain()
			
		var acc_sample: float = 0.0
		var alive_grains: Array[Grain] = []
		
		for g in active_grains:
			if not g.is_active:
				continue
				
			# Hanning window: w[n] = 0.5 * (1 - cos(2*pi*n / (N - 1)))
			var t = float(g.current_sample_idx) / float(g.duration_samples)
			var hanning = 0.5 * (1.0 - cos(t * TAU))
			
			var read_idx = int(g.current_source_sample) % src_len
			var sample_val = source_samples[read_idx]
			acc_sample += sample_val * hanning
			
			g.current_source_sample += g.playback_rate
			g.current_sample_idx += 1
			
			if g.current_sample_idx < g.duration_samples:
				alive_grains.append(g)
				
		active_grains = alive_grains
		out[i] = clampf(acc_sample, -1.0, 1.0)
		
	return out
