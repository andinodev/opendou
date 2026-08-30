@icon("res://addons/opendou/icons/icon_event_player_3d.svg")
@tool
class_name OpenDouEventPlayer
extends AudioStreamPlayer

## Declarative Non-Spatial Audio Event Player for OpenDou.
## Ideal for 2D/UI audio, global interactive music, background ambiances, and narrator dialogue.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("OpenDou Event")
@export var event_name: StringName = &""
@export var event_def: AudioEventDef = null
@export var auto_play_event: bool = false
@export var stop_on_tree_exit: bool = true

@export_group("Game Syncs")
@export var rtpc_bindings: Dictionary = {}
@export var switch_group: StringName = &""
@export var active_switch: StringName = &""
@export var state_group: StringName = &""
@export var active_state: StringName = &""

@export_group("Voice Management")
@export_range(0.0, 100.0, 1.0) var base_priority: float = 50.0
@export var virtualization_mode: int = 0

@export_group("Mixing & Ducking")
@export_enum("Master", "Music", "SFX", "Voice", "Ambience") var bus_category: String = "SFX"

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var active_instance: EventInstance = null
var _event_manager: AudioEventManager = null

func _ready() -> void:
	if not Engine.is_editor_hint() and auto_play_event:
		play_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if stop_on_tree_exit and active_instance != null:
			active_instance.stop()

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Sets an explicit AudioEventManager instance for dependency injection or isolated tests.
func set_event_manager(manager: AudioEventManager) -> void:
	_event_manager = manager

## Plays the configured or specified audio event.
func play_event(p_event_name: StringName = &"") -> void:
	var target_name: StringName = p_event_name if not p_event_name.is_empty() else event_name
	var manager: AudioEventManager = _get_manager()
	
	if manager != null:
		if event_def != null and p_event_name.is_empty():
			active_instance = manager.post_event(event_def, self)
		elif not target_name.is_empty():
			active_instance = manager.post_event(target_name, self)
	elif event_def != null:
		active_instance = EventInstanceClass.new(event_def, self)
		active_instance.play()
	elif not target_name.is_empty():
		var fallback_def = AudioEventDefClass.new(target_name)
		fallback_def.target_bus = StringName(bus_category)
		active_instance = EventInstanceClass.new(fallback_def, self)
		active_instance.play()
		
	if active_instance != null:
		active_instance.virtualization_mode = virtualization_mode
		
		for param_name in rtpc_bindings:
			active_instance.set_parameter(param_name, float(rtpc_bindings[param_name]), true)
			
		if not switch_group.is_empty() and not active_switch.is_empty():
			set_switch(switch_group, active_switch)
		if not state_group.is_empty() and not active_state.is_empty():
			set_state(state_group, active_state)

## Stops playback of the currently active event instance.
func stop_event(fade_time: float = 0.0) -> void:
	if active_instance != null:
		active_instance.stop(fade_time)

## Sets a local RTPC parameter value on this player and updates the active instance.
func set_rtpc(param_name: StringName, value: float) -> void:
	rtpc_bindings[param_name] = value
	if active_instance != null:
		active_instance.set_parameter(param_name, value)
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_rtpc(param_name, value)

## Sets the active switch value for a switch group on this player.
func set_switch(group: StringName, switch_value: StringName) -> void:
	switch_group = group
	active_switch = switch_value
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_switch(group, switch_value, self)

## Sets a global game state from this player.
func set_state(group: StringName, state_value: StringName) -> void:
	state_group = group
	active_state = state_value
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_state(group, state_value)

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _get_manager() -> AudioEventManager:
	if _event_manager != null and is_instance_valid(_event_manager):
		return _event_manager
	if is_inside_tree():
		var root = get_tree().root
		if root != null and root.has_node("OpenDou"):
			var node = root.get_node("OpenDou")
			if node is AudioEventManager:
				return node
	if Engine.has_singleton("OpenDou"):
		var s = Engine.get_singleton("OpenDou")
		if s is AudioEventManager:
			return s
	return null
