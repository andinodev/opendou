class_name DemoSurfaceSwitches
extends Node3D

## Demo 03: Footsteps & Dynamic Surface Switches (Wood, Concrete, Metal, Water)

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")

var footstep_event_def: AudioEventDef
var switch_container: AudioSwitchContainer
var current_surface: StringName = &"Concrete"

func _ready() -> void:
	setup_surface_system()

func setup_surface_system() -> void:
	footstep_event_def = AudioEventDefClass.new(&"Character_Footstep")
	
	switch_container = AudioSwitchContainerClass.new()
	switch_container.switch_group = &"SurfaceType"
	switch_container.default_state = &"Concrete"
	
	# Wood Variations
	var wood_random = AudioRandomContainerClass.new()
	wood_random.is_shuffle = true
	wood_random.pitch_jitter = 0.04
	for i in range(1, 4):
		var node = AudioPhysicalNodeClass.new()
		node.resource_path = "res://sfx/footsteps/wood_%d.wav" % i
		wood_random.children.append(node)
	switch_container.branches[&"Wood"] = wood_random
	
	# Concrete Variations
	var concrete_random = AudioRandomContainerClass.new()
	concrete_random.is_shuffle = true
	concrete_random.pitch_jitter = 0.05
	for i in range(1, 4):
		var node = AudioPhysicalNodeClass.new()
		node.resource_path = "res://sfx/footsteps/concrete_%d.wav" % i
		concrete_random.children.append(node)
	switch_container.branches[&"Concrete"] = concrete_random
	
	# Metal Variations
	var metal_random = AudioRandomContainerClass.new()
	metal_random.is_shuffle = true
	metal_random.pitch_jitter = 0.03
	for i in range(1, 4):
		var node = AudioPhysicalNodeClass.new()
		node.resource_path = "res://sfx/footsteps/metal_%d.wav" % i
		metal_random.children.append(node)
	switch_container.branches[&"Metal"] = metal_random
	
	# Water Variations
	var water_random = AudioRandomContainerClass.new()
	water_random.is_shuffle = true
	water_random.pitch_jitter = 0.06
	for i in range(1, 4):
		var node = AudioPhysicalNodeClass.new()
		node.resource_path = "res://sfx/footsteps/water_%d.wav" % i
		water_random.children.append(node)
	switch_container.branches[&"Water"] = water_random
	
	footstep_event_def.root_logic_node = switch_container

## Simulates stepping on a surface, resolving voices through the switch & random composite tree.
func trigger_footstep(surface: StringName) -> Array:
	current_surface = surface
	var ctx = AudioPlaybackContextClass.new()
	ctx.switches[&"SurfaceType"] = current_surface
	
	return footstep_event_def.resolve_voices(ctx)
