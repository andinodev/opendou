class_name TestBlendContainer
extends RefCounted

const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	var stream_idle = AudioStreamWAV.new()
	var stream_high = AudioStreamWAV.new()
	
	# Curve for Idle (0 RPM: 0dB, 4000 RPM: -80dB)
	var curve_idle = Curve.new()
	curve_idle.add_point(Vector2(0.0, 0.0))
	curve_idle.add_point(Vector2(4000.0, -80.0))
	curve_idle.bake()
	
	# Curve for High RPM (0 RPM: -80dB, 4000 RPM: 0dB)
	var curve_high = Curve.new()
	curve_high.add_point(Vector2(0.0, -80.0))
	curve_high.add_point(Vector2(4000.0, 0.0))
	curve_high.bake()
	
	var blend_container = AudioBlendContainerClass.new(&"RPM")
	blend_container.add_layer(AudioPhysicalNodeClass.new(stream_idle), curve_idle)
	blend_container.add_layer(AudioPhysicalNodeClass.new(stream_high), curve_high)
	
	# Test 1: At 0 RPM, only Idle should resolve (High is culled at -80dB)
	var ctx_idle = AudioPlaybackContextClass.new({&"RPM": 0.0})
	var voices_idle: Array[ResolvedVoice] = []
	blend_container.resolve(ctx_idle, voices_idle)
	
	if voices_idle.size() != 1 or voices_idle[0].stream != stream_idle:
		failures.append("Test 1 Failed: At 0 RPM, expected only Idle voice resolved")
		
	# Test 2: At 4000 RPM, only High should resolve (Idle is culled at -80dB)
	var ctx_high = AudioPlaybackContextClass.new({&"RPM": 4000.0})
	var voices_high: Array[ResolvedVoice] = []
	blend_container.resolve(ctx_high, voices_high)
	
	if voices_high.size() != 1 or voices_high[0].stream != stream_high:
		failures.append("Test 2 Failed: At 4000 RPM, expected only High voice resolved")
		
	# Test 3: At 2000 RPM (midpoint), BOTH layers should resolve with ~ -40dB offset
	var ctx_mid = AudioPlaybackContextClass.new({&"RPM": 2000.0})
	var voices_mid: Array[ResolvedVoice] = []
	blend_container.resolve(ctx_mid, voices_mid)
	
	if voices_mid.size() != 2:
		failures.append("Test 3 Failed: At 2000 RPM, expected both layers resolved, got %d" % voices_mid.size())
	elif not is_equal_approx(voices_mid[0].volume_offset_db, -40.0):
		failures.append("Test 3 Failed: Midpoint volume expected ~ -40dB, got %f" % voices_mid[0].volume_offset_db)
		
	return failures
