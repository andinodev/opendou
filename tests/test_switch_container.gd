class_name TestSwitchContainer
extends RefCounted

const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	var stream_concrete = AudioStreamWAV.new()
	var stream_wood = AudioStreamWAV.new()
	var stream_water = AudioStreamWAV.new()
	
	var switch_container = AudioSwitchContainerClass.new(&"Surface_Type", &"Concrete")
	switch_container.set_state_node(&"Concrete", AudioPhysicalNodeClass.new(stream_concrete))
	switch_container.set_state_node(&"Wood", AudioPhysicalNodeClass.new(stream_wood))
	switch_container.set_state_node(&"Water", AudioPhysicalNodeClass.new(stream_water))
	
	# Test 1: Routes to specific state (Wood)
	var ctx_wood = AudioPlaybackContextClass.new({}, {&"Surface_Type": &"Wood"})
	var voices_wood: Array[ResolvedVoice] = []
	var res_wood = switch_container.resolve(ctx_wood, voices_wood)
	
	if not res_wood or voices_wood.size() != 1 or voices_wood[0].stream != stream_wood:
		failures.append("Test 1 Failed: Expected Wood stream resolution")
		
	# Test 2: Fallback to default state (Concrete) when switch state is unknown
	var ctx_unknown = AudioPlaybackContextClass.new({}, {&"Surface_Type": &"Lava"})
	var voices_unknown: Array[ResolvedVoice] = []
	var res_unknown = switch_container.resolve(ctx_unknown, voices_unknown)
	
	if not res_unknown or voices_unknown.size() != 1 or voices_unknown[0].stream != stream_concrete:
		failures.append("Test 2 Failed: Expected fallback to default Concrete stream")
		
	# Test 3: Fallback when context has no switch state at all
	var ctx_empty = AudioPlaybackContextClass.new()
	var voices_empty: Array[ResolvedVoice] = []
	var res_empty = switch_container.resolve(ctx_empty, voices_empty)
	
	if not res_empty or voices_empty.size() != 1 or voices_empty[0].stream != stream_concrete:
		failures.append("Test 3 Failed: Expected fallback on empty context")
		
	return failures
