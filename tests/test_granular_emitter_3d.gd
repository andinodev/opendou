class_name TestGranularEmitter3D
extends RefCounted

const OpenDouGranularEmitter3DClass = preload("res://addons/opendou/nodes/opendou_granular_emitter_3d.gd")
const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var emitter = OpenDouGranularEmitter3DClass.new()
	if emitter == null:
		failures.append("Test 1 Failed: Could not instantiate OpenDouGranularEmitter3D")
		return failures

	# Test default properties
	if emitter.grain_size_ms != 40.0 or emitter.grain_rate_hz != 45.0:
		failures.append("Test 2 Failed: Default grain parameters invalid, got size: %f, rate: %f" % [emitter.grain_size_ms, emitter.grain_rate_hz])

	if emitter.max_concurrent_grains != 32 or emitter.auto_play_emitter != true:
		failures.append("Test 3 Failed: Default concurrency/autoplay invalid")

	# Test parameter modification
	emitter.set_grain_parameters(60.0, 80.0, 20.0, 4.0)
	if emitter.grain_size_ms != 60.0 or emitter.grain_rate_hz != 80.0 or emitter.position_jitter_ms != 20.0 or emitter.pitch_jitter_semitones != 4.0:
		failures.append("Test 4 Failed: set_grain_parameters failed to update properties")

	# Test procedural buffer generation
	var block = emitter.synthesize_current_block(256)
	if block.size() != 256:
		failures.append("Test 5 Failed: synthesize_current_block did not return expected sample count, got %d" % block.size())

	emitter.free()
	return failures
