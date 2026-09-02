@icon("res://addons/opendou/icons/icon_granular_emitter.svg")
@tool
class_name OpenDouGranularEmitter3D
extends AudioStreamPlayer3D

## Declarative 3D Spatial Granular Synthesizer for OpenDou.
## Generates continuous asynchronous audio grains with Hanning windowing, time-stretch, and stochastic pitch modulation.

const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

@export_group("Granular Configuration")
@export var source_stream: AudioStreamWAV = null:
	set(val):
		source_stream = val
		_rebuild_synthesizer()

@export_range(5.0, 200.0, 1.0) var grain_size_ms: float = 40.0:
	set(val):
		grain_size_ms = val
		if _granular_synth:
			_granular_synth.grain_size_ms = val

@export_range(1.0, 200.0, 1.0) var grain_rate_hz: float = 45.0:
	set(val):
		grain_rate_hz = val
		if _granular_synth:
			_granular_synth.grain_rate_hz = val

@export_range(0.0, 50.0, 1.0) var position_jitter_ms: float = 15.0:
	set(val):
		position_jitter_ms = val
		if _granular_synth:
			_granular_synth.position_jitter_ms = val

@export_range(0.0, 12.0, 0.5) var pitch_jitter_semitones: float = 2.0:
	set(val):
		pitch_jitter_semitones = val
		if _granular_synth:
			_granular_synth.pitch_jitter_semitones = val

@export_range(1, 64, 1) var max_concurrent_grains: int = 32:
	set(val):
		max_concurrent_grains = val
		if _granular_synth:
			_granular_synth.max_concurrent_grains = val

@export var auto_play_emitter: bool = true
@export var bus_category: String = "SFX"

var _granular_synth: AudioGranularSynthesizer = null
var _playback: AudioStreamGeneratorPlayback = null
var _generator_stream: AudioStreamGenerator = null

func _init() -> void:
	_granular_synth = AudioGranularSynthesizerClass.new()
	_rebuild_synthesizer()

func _ready() -> void:
	if not Engine.is_editor_hint():
		_setup_audio_generator()
		if auto_play_emitter and is_inside_tree():
			play_granular()

func _setup_audio_generator() -> void:
	if stream == null or not (stream is AudioStreamGenerator):
		_generator_stream = AudioStreamGenerator.new()
		_generator_stream.mix_rate = 44100.0
		_generator_stream.buffer_length = 0.1
		stream = _generator_stream

func _rebuild_synthesizer() -> void:
	if _granular_synth == null:
		return
	# La decodificacion la hace OpenDouWavDecoder: aqui se asumia 16 bits mono, y
	# el formato por defecto de AudioStreamWAV es de 8 bits con signo.
	var samples: PackedFloat32Array = PackedFloat32Array()
	if source_stream != null and source_stream.data.size() > 0:
		samples = WavDecoderClass.to_mono_floats(source_stream)
	else:
		# Fallback procedural grain texture (Brown filtered noise)
		var fallback_dict: Dictionary = {
			"type": "Single_Generator",
			"generator_type": "Filtered_Noise",
			"noise_type": "Brown",
			"duration": 1.0,
			"filter": {"type": "BandPass", "cutoff_hz": 1200.0, "resonance_q": 2.0},
			"gain_db": -6.0
		}
		var synth_wav = ModularSynthEngineClass.synthesize_wav(fallback_dict)
		if synth_wav and synth_wav.data.size() > 0:
			samples = WavDecoderClass.to_mono_floats(synth_wav)

	_granular_synth.source_samples = samples
	_granular_synth.grain_size_ms = grain_size_ms
	_granular_synth.grain_rate_hz = grain_rate_hz
	_granular_synth.position_jitter_ms = position_jitter_ms
	_granular_synth.pitch_jitter_semitones = pitch_jitter_semitones
	_granular_synth.max_concurrent_grains = max_concurrent_grains

func set_grain_parameters(size_ms: float, rate_hz: float, pos_jitter_ms: float, pitch_jitter: float) -> void:
	grain_size_ms = size_ms
	grain_rate_hz = rate_hz
	position_jitter_ms = pos_jitter_ms
	pitch_jitter_semitones = pitch_jitter

func synthesize_current_block(num_samples: int) -> PackedFloat32Array:
	if _granular_synth == null:
		return PackedFloat32Array()
	return _granular_synth.generate_block(num_samples)

func play_granular() -> void:
	if not playing and is_inside_tree():
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func stop_granular() -> void:
	if playing:
		stop()
		_playback = null

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not playing or _playback == null or not is_inside_tree():
		return
	var frames_avail = _playback.get_frames_available()
	if frames_avail > 0:
		var samples = synthesize_current_block(frames_avail)
		for i in range(frames_avail):
			var s = samples[i] if i < samples.size() else 0.0
			_playback.push_frame(Vector2(s, s))
