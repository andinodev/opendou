@icon("res://addons/opendou/icons/icon_event_player_3d.svg")
@tool
class_name OpenDouEventPlayer
extends AudioStreamPlayer

## Declarative Non-Spatial Audio Event Player for OpenDou.
## Ideal for 2D/UI audio, global interactive music, background ambiances, and narrator dialogue.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("OpenDou Event")
@export var event_name: StringName = &""
@export var event_def: AudioEventDef = null
@export var auto_play_event: bool = false
@export var stop_on_tree_exit: bool = true

@export_group("Procedural Synthesis")
var synth_preset: String = "None"
@export var synth_duration: float = 2.0
@export var synth_frequency: float = 440.0

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var presets: Array[String] = ["None"]
	var reg = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	if reg != null:
		var singleton = reg.get_singleton()
		if singleton != null:
			for p_name in singleton.get_preset_names():
				presets.append(str(p_name))
	var hint_str = ",".join(presets)
	properties.append({
		"name": "synth_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_str,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

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
	if not Engine.is_editor_hint():
		if stream == null and synth_preset != "None":
			_apply_synth_preset()
		elif stream == null and not event_name.is_empty():
			_auto_infer_synth_preset()
			
		if auto_play_event:
			play_event()
		elif autoplay and stream != null and not playing:
			play()

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
		elif not target_name.is_empty() and manager.event_registry.has(target_name):
			active_instance = manager.post_event(target_name, self)
		elif not target_name.is_empty():
			var fallback_def = AudioEventDefClass.new(target_name)
			fallback_def.target_bus = StringName(bus_category)
			active_instance = EventInstanceClass.new(fallback_def, self)
			active_instance.play()
			manager.active_instances.append(active_instance)
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

	if stream == null and synth_preset != "None":
		_apply_synth_preset()
	elif stream == null and not target_name.is_empty():
		_auto_infer_synth_preset()

	if AudioServer.get_bus_index(bus_category) != -1:
		bus = bus_category

	if stream != null and is_inside_tree():
		play(0.0)

## Stops playback of the currently active event instance.
func stop_event(fade_time: float = 0.0) -> void:
	if active_instance != null:
		active_instance.stop(fade_time)
	if is_inside_tree() and playing:
		stop()

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

func _apply_synth_preset() -> void:
	if synth_preset == "None" or synth_preset.is_empty():
		return
		
	var reg = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	if reg != null:
		var singleton = reg.get_singleton()
		if singleton != null:
			var p_dict = singleton.get_preset(StringName(synth_preset))
			if not p_dict.is_empty():
				var s = singleton.get_preset_stream(StringName(synth_preset))
				if s != null:
					stream = s
					return

	match synth_preset:
		"Rain":
			stream = AudioSynthesizerClass.create_rain_ambient_loop(synth_duration)
		"Server_Hum":
			stream = AudioSynthesizerClass.create_server_ambient_loop(synth_duration)
		"Water_Stream":
			stream = AudioSynthesizerClass.create_water_stream_ambient_loop(synth_duration)
		"Turret_Scan":
			stream = AudioSynthesizerClass.create_tone(880.0, 0.4, 0.2)
		"Radio_Beacon":
			stream = AudioSynthesizerClass.create_tone(1200.0, 0.3, 0.15)
		"Footstep":
			stream = AudioSynthesizerClass.create_footstep(active_switch if not active_switch.is_empty() else &"Metal", 1)
		"Gunshot":
			stream = AudioSynthesizerClass.create_gunshot(0.3)
		"Engine":
			stream = AudioSynthesizerClass.create_engine_loop(120.0, synth_duration)
		"Tone":
			stream = AudioSynthesizerClass.create_tone(synth_frequency, synth_duration)
		"Wind_Canopy":
			stream = AudioSynthesizerClass.create_canopy_wind_loop(synth_duration)
		"Bird_Chirp":
			stream = AudioSynthesizerClass.create_bird_chirp(synth_frequency if synth_frequency != 440.0 else 2400.0, synth_duration if synth_duration != 2.0 else 0.35)
		"Thunder_Rumble":
			stream = AudioSynthesizerClass.create_thunder_rumble(synth_duration if synth_duration != 2.0 else 2.5)
		"Cicada_Swarm":
			stream = AudioSynthesizerClass.create_cicada_swarm_loop(synth_duration)
		"Frog_Croak":
			stream = AudioSynthesizerClass.create_frog_croak(synth_duration if synth_duration != 2.0 else 0.45)
		"Water_Droplet":
			stream = AudioSynthesizerClass.create_water_droplet(synth_frequency if synth_frequency != 440.0 else 1200.0)
		"Cyber_Hornet":
			stream = AudioSynthesizerClass.create_cyber_hornet_loop(synth_duration if synth_duration != 2.0 else 1.5)

func _auto_infer_synth_preset() -> void:
	var reg = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	if reg != null:
		var singleton = reg.get_singleton()
		if singleton != null:
			var names: Array[StringName] = singleton.get_preset_names()
			var ev_str: String = str(event_name).to_lower()
			for p_name in names:
				var p_str: String = str(p_name).to_lower()
				if ev_str.contains(p_str) or p_str.contains(ev_str):
					synth_preset = str(p_name)
					_apply_synth_preset()
					return

	var n: String = str(event_name).to_lower()
	if n.contains("wind") or n.contains("canopy"):
		synth_preset = "Wind_Canopy"
	elif n.contains("bird") or n.contains("chirp") or n.contains("avian"):
		synth_preset = "Bird_Chirp"
	elif n.contains("thunder") or n.contains("lightning") or n.contains("rumble"):
		synth_preset = "Thunder_Rumble"
	elif n.contains("cicada") or n.contains("insect") or n.contains("swarm"):
		synth_preset = "Cicada_Swarm"
	elif n.contains("frog") or n.contains("croak") or n.contains("amphibian"):
		synth_preset = "Frog_Croak"
	elif n.contains("droplet") or n.contains("drip"):
		synth_preset = "Water_Droplet"
	elif n.contains("hornet") or n.contains("bee") or n.contains("wasp"):
		synth_preset = "Cyber_Hornet"
	elif n.contains("rain"):
		synth_preset = "Rain"
	elif n.contains("server"):
		synth_preset = "Server_Hum"
	elif n.contains("water") or n.contains("stream"):
		synth_preset = "Water_Stream"
	elif n.contains("turret"):
		synth_preset = "Turret_Scan"
	elif n.contains("beacon") or n.contains("radio_beacon"):
		synth_preset = "Radio_Beacon"
	elif n.contains("gun") or n.contains("shot") or n.contains("weapon"):
		synth_preset = "Gunshot"
	elif n.contains("footstep"):
		synth_preset = "Footstep"
	if synth_preset != "None":
		_apply_synth_preset()
