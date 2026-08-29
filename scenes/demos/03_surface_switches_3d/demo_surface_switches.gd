class_name DemoSurfaceSwitches
extends Node3D

## Demo 03: Footsteps & Dynamic Surface Switches (Wood, Concrete, Metal, Water)

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var footstep_event_def: AudioEventDef
var switch_container: AudioSwitchContainer
var current_surface: StringName = &"Concrete"

# Scene Node References
@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioPlayer")
@onready var character_marker: CSGCylinder3D = get_node_or_null("Environment3D/CharacterMarker")
@onready var btn_back: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnBack")

@onready var lbl_surface: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblSurface")
@onready var lbl_sample: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblSample")

@onready var btn_wood: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnWood")
@onready var btn_concrete: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnConcrete")
@onready var btn_metal: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnMetal")
@onready var btn_water: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnWater")
@onready var btn_step: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnStep")

const SURFACE_POSITIONS = {
	&"Wood": Vector3(-6, 1, -6),
	&"Concrete": Vector3(6, 1, -6),
	&"Metal": Vector3(-6, 1, 6),
	&"Water": Vector3(6, 1, 6)
}

func _init() -> void:
	setup_surface_system()

func _ready() -> void:
	if not footstep_event_def:
		setup_surface_system()
	_connect_ui()
	_update_ui()

func setup_surface_system() -> void:
	footstep_event_def = AudioEventDefClass.new(&"Character_Footstep")
	
	switch_container = AudioSwitchContainerClass.new(&"SurfaceType", &"Concrete")
	
	# Wood Variations
	var wood_random = AudioRandomContainerClass.new()
	wood_random.use_shuffle = true
	for i in range(1, 4):
		var wav = AudioSynthesizerClass.create_footstep(&"Wood", i)
		wood_random.add_child_node(AudioPhysicalNodeClass.new(wav))
	switch_container.set_state_node(&"Wood", wood_random)
	
	# Concrete Variations
	var concrete_random = AudioRandomContainerClass.new()
	concrete_random.use_shuffle = true
	for i in range(1, 4):
		var wav = AudioSynthesizerClass.create_footstep(&"Concrete", i)
		concrete_random.add_child_node(AudioPhysicalNodeClass.new(wav))
	switch_container.set_state_node(&"Concrete", concrete_random)
	
	# Metal Variations
	var metal_random = AudioRandomContainerClass.new()
	metal_random.use_shuffle = true
	for i in range(1, 4):
		var wav = AudioSynthesizerClass.create_footstep(&"Metal", i)
		metal_random.add_child_node(AudioPhysicalNodeClass.new(wav))
	switch_container.set_state_node(&"Metal", metal_random)
	
	# Water Variations
	var water_random = AudioRandomContainerClass.new()
	water_random.use_shuffle = true
	for i in range(1, 4):
		var wav = AudioSynthesizerClass.create_footstep(&"Water", i)
		water_random.add_child_node(AudioPhysicalNodeClass.new(wav))
	switch_container.set_state_node(&"Water", water_random)
	
	footstep_event_def.root_container = switch_container

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_wood:
		btn_wood.pressed.connect(func(): select_surface(&"Wood"))
	if btn_concrete:
		btn_concrete.pressed.connect(func(): select_surface(&"Concrete"))
	if btn_metal:
		btn_metal.pressed.connect(func(): select_surface(&"Metal"))
	if btn_water:
		btn_water.pressed.connect(func(): select_surface(&"Water"))
	if btn_step:
		btn_step.pressed.connect(func(): trigger_footstep(current_surface))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func select_surface(surf: StringName) -> void:
	current_surface = surf
	if character_marker and SURFACE_POSITIONS.has(surf):
		character_marker.position = SURFACE_POSITIONS[surf]
	trigger_footstep(current_surface)

## Simulates stepping on a surface, resolving voices through the switch & random composite tree and playing audio.
func trigger_footstep(surface: StringName) -> Array:
	if not footstep_event_def:
		setup_surface_system()
	current_surface = surface
	var ctx = AudioPlaybackContextClass.new()
	ctx.set_switch(&"SurfaceType", current_surface)
	
	var resolved = footstep_event_def.resolve_voices(ctx)
	if not resolved.is_empty():
		var voice = resolved[0]
		if voice and voice.stream:
			if lbl_sample:
				lbl_sample.text = "Resolved Sample: %s" % voice.stream.resource_name
			if audio_player:
				audio_player.stream = voice.stream
				audio_player.volume_db = voice.volume_offset_db
				audio_player.pitch_scale = voice.pitch_modifier
				audio_player.play()
				
	_update_ui()
	return resolved

func _update_ui() -> void:
	if lbl_surface:
		lbl_surface.text = "Active Switch: %s" % str(current_surface)
