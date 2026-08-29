class_name TestRandomContainer
extends RefCounted

const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Create dummy streams for testing
	var stream_a = AudioStreamWAV.new()
	var stream_b = AudioStreamWAV.new()
	var stream_c = AudioStreamWAV.new()
	
	var node_a = AudioPhysicalNodeClass.new(stream_a)
	var node_b = AudioPhysicalNodeClass.new(stream_b)
	var node_c = AudioPhysicalNodeClass.new(stream_c)
	
	var container = AudioRandomContainerClass.new([node_a, node_b, node_c])
	container.use_shuffle = true
	container.no_repeat_count = 1
	
	var context = AudioPlaybackContextClass.new()
	
	# Test 1: Resolves exactly one voice
	var voices: Array[ResolvedVoice] = []
	var res = container.resolve(context, voices)
	if not res or voices.size() != 1:
		failures.append("Test 1 Failed: Random container expected 1 resolved voice")
		
	# Test 2: Shuffle prevents immediate repetition with 2 items
	var container_two = AudioRandomContainerClass.new([node_a, node_b])
	container_two.use_shuffle = true
	container_two.no_repeat_count = 1
	
	var v1: Array[ResolvedVoice] = []
	container_two.resolve(context, v1)
	var v2: Array[ResolvedVoice] = []
	container_two.resolve(context, v2)
	
	if v1[0].stream == v2[0].stream:
		failures.append("Test 2 Failed: Shuffle with 2 items should alternate, got same stream twice")
		
	# Test 3: Pitch and Volume Jitter
	container.pitch_jitter_range = Vector2(0.1, 0.1) # Fixed +10%
	container.volume_jitter_db_range = Vector2(-2.0, -2.0) # Fixed -2dB
	var v_jitter: Array[ResolvedVoice] = []
	container.resolve(context, v_jitter)
	
	if not is_equal_approx(v_jitter[0].pitch_modifier, 1.1):
		failures.append("Test 3a Failed: Pitch jitter expected 1.1, got %f" % v_jitter[0].pitch_modifier)
	if not is_equal_approx(v_jitter[0].volume_offset_db, -2.0):
		failures.append("Test 3b Failed: Volume jitter expected -2.0dB, got %f" % v_jitter[0].volume_offset_db)
		
	return failures
