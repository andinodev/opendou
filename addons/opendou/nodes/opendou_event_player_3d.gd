@icon("res://addons/opendou/icons/icon_event_player_3d.svg")
@tool
class_name OpenDouEventPlayer3D
extends AudioStreamPlayer3D

## Declarative 3D Spatial Audio Event Player for OpenDou.
## Integrates 3D acoustic occlusion, binaural HRTF, early reflections, voice virtualization, and Game Syncs.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("OpenDou Event")
@export var event_name: StringName = &""
@export var event_def: AudioEventDef = null
@export var auto_play_event: bool = false
@export var stop_on_tree_exit: bool = true

enum Source { EVENT, BUS_CAPTURE }
@export_group("World Bus")
## BUS_CAPTURE (Fase 11): la voz es lo que suena en `capture_bus` (radio, megafonia). La salida
## directa del bus se calla a -80 dB: la captura es anterior al volumen del bus.
@export var source: Source = Source.EVENT
@export var capture_bus: StringName = &""

@export_group("Procedural Synthesis")
var synth_preset: String = "None"
@export var synth_duration: float = 2.0
@export var synth_frequency: float = 440.0

func _get_property_list() -> Array[Dictionary]:
	# El inspector invoca este metodo en CADA refresco. Antes hacia aqui un load()
	# desde disco y enumeraba el registro de presets entero cada vez; el hint viene
	# ahora de una cache que el propio registro invalida al cambiar.
	var hint_str: String = "None"
	var singleton = SynthPresetRegistryClass.get_singleton()
	if singleton != null:
		hint_str = singleton.get_preset_hint_string()
	return [{
		"name": "synth_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_str,
		"usage": PROPERTY_USAGE_DEFAULT
	}]

@export_group("Game Syncs")
@export var rtpc_bindings: Dictionary = {}
@export var switch_group: StringName = &""
@export var active_switch: StringName = &""
@export var state_group: StringName = &""
@export var active_state: StringName = &""

@export_group("Spatial Acoustics & Occlusion")
@export var enable_early_reflections: bool = true
## Informa al programador central de oclusion; ya no dispara raycasts propios.
@export var enable_dynamic_occlusion: bool = true
@export_flags_3d_physics var occlusion_collision_mask: int = 1
@export var occlusion_refresh_interval: float = 0.05

@export_group("Emitter Physics")
## Cambia el tono con la velocidad relativa. Ambos backends.
@export var doppler_enabled: bool = false
## El sonido llega tarde de lejos (343 m/s). En godot solo retrasa el arranque.
@export var propagation_delay_enabled: bool = false
## Radio en el que la fuente deja de ser un punto al acercarse (0 = apagado).
@export_range(0.0, 200.0, 0.1) var spread_radius_m: float = 0.0
## Refuerzo de graves e ILD extra al pegarse a la oreja (0 = apagado; solo steam_audio).
@export_range(0.0, 2.0, 0.01) var near_field_distance_m: float = 0.0
## Directividad tipo dipolo (0 = omnidireccional). El eje es -Z del nodo.
@export_range(0.0, 1.0, 0.01) var directivity_dipole_weight: float = 0.0
@export_range(0.1, 8.0, 0.1) var directivity_power: float = 1.0
## Con attenuation_model = Curve: curva en dB sobre 0..attenuation_curve_distance_m.
@export var attenuation_curve: Curve = null
@export var attenuation_curve_distance_m: float = 50.0

@export_group("Voice Management")
@export_range(0.0, 100.0, 1.0) var base_priority: float = 50.0
@export var virtualization_mode: int = 0
@export var cull_distance: float = 35.0

@export_group("Mixing & Ducking")
@export_enum("Master", "Music", "SFX", "Voice", "Ambience") var bus_category: String = "SFX"

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var active_instance: EventInstance = null
const MARK_CAPTURE: String = "OpenDou_WorldBus_Capture"
var _capture: AudioEffectCapture = null
var _generator: AudioStreamGenerator = null
var _capture_bus_prev_db: float = 0.0
var _primed: bool = false
var _event_manager: AudioEventManager = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		if stream == null and synth_preset != "None":
			_apply_synth_preset()
		elif stream == null and not event_name.is_empty():
			_auto_infer_synth_preset()
			
		# Un unico camino de arranque: play_event() es quien crea la voz. Antes
		# autoplay llamaba al play() nativo por su cuenta, dejando una voz que el
		# manager no conocia.
		if auto_play_event or (autoplay and stream != null):
			play_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		if stop_on_tree_exit and active_instance != null:
			active_instance.stop()
		_stop_bus_capture()

func _process(_delta: float) -> void:
	if source == Source.BUS_CAPTURE and not Engine.is_editor_hint():
		_pump_bus_capture()

## Altavoz de mundo: captura marcada en el bus origen, bus a -80 dB, y un generador como
## stream de un evento propio que el pool reproduce como cualquier voz.
func _start_bus_capture(manager: AudioEventManager) -> void:
	var idx: int = AudioServer.get_bus_index(String(capture_bus))
	if idx < 0 or manager == null:
		push_warning("[OpenDou] %s: capture_bus '%s' no existe o no hay manager" % [name, capture_bus])
		return
	_capture = null
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectCapture and e.resource_name == MARK_CAPTURE:
			_capture = e
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.resource_name = MARK_CAPTURE
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture)
	# El bus se calla en el servidor Y en la base del aplicador de mezcla: si una regla de
	# ducking o una instantanea nombran este bus, el aplicador lo escribe cada cuadro y sin la
	# base recordaria -80 como su volumen normal para siempre.
	if manager.mix != null:
		_capture_bus_prev_db = manager.mix.get_bus_base_volume_db(capture_bus)
		manager.mix.set_bus_base_volume_db(capture_bus, -80.0)
	else:
		_capture_bus_prev_db = AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, -80.0)
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = AudioServer.get_mix_rate()
	_generator.buffer_length = 0.2
	var def = AudioEventDefClass.new(StringName("WorldBus_%s" % capture_bus), _generator)
	def.target_bus = StringName(bus_category)
	def.is_looping = true
	def.stream_length = 0.0
	active_instance = manager.post_event(def, self)
	if active_instance != null:
		active_instance.bind_player(self)
		active_instance.copy_attenuation_from_player(self)
		active_instance.copy_emitter_settings_from_player(self)
		active_instance.virtualization_mode = virtualization_mode
		active_instance.max_distance = cull_distance
		active_instance.set_position(global_position if is_inside_tree() else position)
	_primed = false
	if AudioServer.get_bus_index(bus_category) != -1:
		bus = bus_category

func _pump_bus_capture() -> void:
	if _capture == null or active_instance == null or not active_instance.is_playing():
		return
	var manager: AudioEventManager = _get_manager()
	if manager == null or manager.voice_pool == null or active_instance.assigned_channel_id < 0:
		return
	var ch = manager.voice_pool.get_channel(active_instance.assigned_channel_id)
	if ch == null:
		return
	var pb = ch.get_source_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	if not _primed:
		# Colchon inicial de silencio para no quedarse sin muestras entre cuadros.
		var silence := PackedVector2Array()
		silence.resize(int(_generator.mix_rate * 0.1))
		pb.push_buffer(silence)
		_primed = true
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		return
	var frames: PackedVector2Array = _capture.get_buffer(avail)
	var room: int = pb.get_frames_available()
	if frames.size() > room:
		frames = frames.slice(frames.size() - room)
	if not frames.is_empty():
		pb.push_buffer(frames)

func _stop_bus_capture() -> void:
	if _capture != null:
		var idx: int = AudioServer.get_bus_index(String(capture_bus))
		if idx >= 0:
			var manager: AudioEventManager = _get_manager()
			if manager != null and manager.mix != null:
				manager.mix.set_bus_base_volume_db(capture_bus, _capture_bus_prev_db)
			AudioServer.set_bus_volume_db(idx, _capture_bus_prev_db)
			for i in range(AudioServer.get_bus_effect_count(idx)):
				if AudioServer.get_bus_effect(idx, i) == _capture:
					AudioServer.remove_bus_effect(idx, i)
					break
	_capture = null
	_generator = null


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
	if source == Source.BUS_CAPTURE:
		if active_instance != null:
			stop_event()
		_start_bus_capture(manager)
		return
	# El reproductor de este nodo puede hospedar UNA voz. Si ya habia una activa hay
	# que detenerla: si no, la vieja se queda ocupando el emisor y, con el bonus de
	# histeresis del pool, le gana a la nueva. Dos disparos seguidos del mismo emisor
	# -dos pisadas, dos disparos de arma- dejaban muda la segunda.
	if active_instance != null:
		stop_event()

	
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
		# El reproductor de este nodo ES la voz fisica. Vincularlo evita que el
		# pool le asigne ademas una voz anonima, que era la doble reproduccion.
		active_instance.bind_player(self)
		active_instance.copy_attenuation_from_player(self)
		active_instance.copy_emitter_settings_from_player(self)
		active_instance.virtualization_mode = virtualization_mode
		active_instance.max_distance = cull_distance
		var cur_pos: Vector3 = global_position if is_inside_tree() else position
		active_instance.set_position(cur_pos)
		
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


## Stops playback of the currently active event instance.
func stop_event(fade_time: float = 0.0) -> void:
	if active_instance != null:
		active_instance.stop(fade_time)
	if source == Source.BUS_CAPTURE:
		_stop_bus_capture()
	if is_inside_tree() and playing:
		stop()

## Sets a local RTPC parameter value on this emitter and updates the active instance.
func set_rtpc(param_name: StringName, value: float) -> void:
	rtpc_bindings[param_name] = value
	if active_instance != null:
		active_instance.set_parameter(param_name, value)
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_rtpc(param_name, value)

## Sets the active switch value for a switch group on this emitter.
func set_switch(group: StringName, switch_value: StringName) -> void:
	switch_group = group
	active_switch = switch_value
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_switch(group, switch_value, self)

## Sets a global game state from this emitter.
func set_state(group: StringName, state_value: StringName) -> void:
	state_group = group
	active_state = state_value
	var manager: AudioEventManager = _get_manager()
	if manager != null:
		manager.set_state(group, state_value)

## Returns the latest calculated physical occlusion factor (0.0 = clear, 1.0 = fully occluded).
func get_calculated_occlusion() -> float:
	if active_instance == null:
		return 0.0
	# El programador central escribe el LPF objetivo en la instancia y de ahi se
	# deriva el factor. El rango va del LPF sin ocluir al de oclusion total, que
	# son los limites que usa OcclusionManager.
	var span: float = 20000.0 - 1500.0
	return clampf((20000.0 - active_instance.target_spatial_lpf) / span, 0.0, 1.0)

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
