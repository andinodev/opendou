class_name TestCompositeTree
extends RefCounted

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Create physical sounds
	var concrete_1 = AudioStreamWAV.new()
	var concrete_2 = AudioStreamWAV.new()
	var metal_1 = AudioStreamWAV.new()
	var metal_2 = AudioStreamWAV.new()
	
	# Random containers for each surface
	var random_concrete = AudioRandomContainerClass.new([
		AudioPhysicalNodeClass.new(concrete_1),
		AudioPhysicalNodeClass.new(concrete_2)
	])
	
	var random_metal = AudioRandomContainerClass.new([
		AudioPhysicalNodeClass.new(metal_1),
		AudioPhysicalNodeClass.new(metal_2)
	])
	
	# Switch container routing surfaces
	var root_switch = AudioSwitchContainerClass.new(&"Surface_Type", &"Concrete")
	root_switch.set_state_node(&"Concrete", random_concrete)
	root_switch.set_state_node(&"Metal", random_metal)
	
	# AudioEventDef with composite tree
	var footstep_event = AudioEventDefClass.new(&"Footstep_Player")
	footstep_event.root_container = root_switch
	
	# Test 1: Resolve event with Surface_Type = Metal
	var ctx_metal = AudioPlaybackContextClass.new({}, {&"Surface_Type": &"Metal"})
	var voices_metal = footstep_event.resolve_voices(ctx_metal)
	
	if voices_metal.size() != 1:
		failures.append("Test 1 Failed: Expected 1 voice for Metal footstep")
	elif voices_metal[0].stream != metal_1 and voices_metal[0].stream != metal_2:
		failures.append("Test 1 Failed: Expected a Metal stream, got unknown")
		
	# Test 2: Resolve event with default/Concrete fallback
	var ctx_default = AudioPlaybackContextClass.new()
	var voices_default = footstep_event.resolve_voices(ctx_default)
	
	if voices_default.size() != 1:
		failures.append("Test 2 Failed: Expected 1 voice for Concrete footstep")
	elif voices_default[0].stream != concrete_1 and voices_default[0].stream != concrete_2:
		failures.append("Test 2 Failed: Expected a Concrete stream, got unknown")
		
	return failures
