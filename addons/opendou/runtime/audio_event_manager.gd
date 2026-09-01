class_name AudioEventManager
extends Node

## Central Dispatcher and Manager for OpenDou Audio Events, Game Syncs, SoundBanks, Spatial Acoustics, Live Update, and Virtual Voice Pools.

const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const GameSyncManagerClass = preload("res://addons/opendou/runtime/game_sync_manager.gd")
const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const LiveUpdateServerClass = preload("res://addons/opendou/runtime/network/live_update_server.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const ListenerResolverClass = preload("res://addons/opendou/runtime/listener_resolver.gd")

# Central Game Syncs Manager (States, Switches, Global RTPCs, Triggers)
var sync_manager: GameSyncManager

# Central SoundBank Manager (Monolithic Banks, Prefetch RAM, Disk Streaming)
var bank_manager: SoundBankManager

# Central Spatial Acoustics Manager (Rooms, Portals, Diffraction Pathfinding)
var spatial_acoustics: SpatialAcousticsManager

# Live Update TCP Server for in-game real-time tweaking
var live_update_server: LiveUpdateServer

# All currently active runtime event instances
var active_instances: Array[EventInstance] = []

# Registered event definitions by name
var event_registry: Dictionary = {} # StringName -> AudioEventDef

# Voice Pool Manager managing physical channels & virtual voices
var voice_pool: VoicePoolManager

# Listener position cache
var active_listener_position: Vector3 = Vector3.ZERO

## Pool de reproductores nativos para las voces anonimas.
##
## Se crea en _init() para que el manager sea coherente desde el primer momento,
## y se mete en el arbol en _ready(): un reproductor fuera del arbol no puede
## reproducir, asi que sin ese paso las voces cambiarian de estado sin sonar.
var player_pool: OpenDouNativePlayerPool = null

## Resolutor del oyente activo.
var listener_resolver: OpenDouListenerResolver = null

func _init() -> void:
	sync_manager = GameSyncManagerClass.new()
	bank_manager = SoundBankManagerClass.new()
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	live_update_server = LiveUpdateServerClass.new()
	voice_pool = VoicePoolManagerClass.new(64)
	player_pool = NativePlayerPoolClass.new(64)
	voice_pool.set_player_pool(player_pool)
	listener_resolver = ListenerResolverClass.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Los reproductores solo pueden reproducir dentro del arbol.
	if player_pool != null and player_pool.get_parent() == null:
		add_child(player_pool)

## Sustituye el pool de reproductores nativos.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	if pool == null:
		return
	if player_pool != null and player_pool != pool and player_pool.get_parent() == self:
		remove_child(player_pool)
		player_pool.queue_free()
	player_pool = pool
	if voice_pool != null:
		voice_pool.set_player_pool(pool)
	if is_inside_tree() and pool.get_parent() == null:
		add_child(pool)

# ==============================================================================
# LIVE UPDATE & PROFILING API
# ==============================================================================

## Starts the Live Update TCP server for remote editor authoring.
func start_live_update_server(port: int = 3016) -> bool:
	return live_update_server.start_server(port)

## Stops the Live Update server.
func stop_live_update_server() -> void:
	live_update_server.stop_server()

# ==============================================================================
# SOUNDBANK API
# ==============================================================================

## Loads a monolithic sound bank file into memory.
func load_bank(file_path: String, bank_name: StringName = &"") -> RefCounted:
	return bank_manager.load_bank(file_path, bank_name)

## Unloads a sound bank, freeing its prefetch RAM and closing its file descriptor.
func unload_bank(bank_name: StringName) -> void:
	bank_manager.unload_bank(bank_name)

# ==============================================================================
# CONVENIENCE GAME SYNCS API
# ==============================================================================

## Sets a global game state with optional smooth crossfade transition time.
func set_state(group_name: StringName, state_name: StringName, transition_duration_sec: float = 0.0) -> void:
	sync_manager.set_state(group_name, state_name, transition_duration_sec)

## Gets the active state name for a state group.
func get_state(group_name: StringName, default_state: StringName = &"") -> StringName:
	return sync_manager.get_state(group_name, default_state)

## Gets the transition progress weight (0.0 to 1.0) of an active state change.
func get_state_transition_weight(group_name: StringName) -> float:
	return sync_manager.get_state_transition_weight(group_name)

## Sets a discrete switch (either entity-scoped or global).
func set_switch(group_name: StringName, state_name: StringName, entity: Node = null) -> void:
	sync_manager.set_switch(group_name, state_name, entity)

## Gets a switch state.
func get_switch(group_name: StringName, entity: Node = null, default_state: StringName = &"") -> StringName:
	return sync_manager.get_switch(group_name, entity, default_state)

## Sets a global RTPC value.
func set_rtpc(param_name: StringName, value: float, immediate: bool = false) -> void:
	sync_manager.set_rtpc(param_name, value, immediate)

## Gets a global RTPC value.
func get_rtpc(param_name: StringName, default_value: float = 0.0) -> float:
	return sync_manager.get_rtpc(param_name, default_value)

## Posts a trigger (musical stinger / cue point).
func post_trigger(trigger_name: StringName) -> void:
	sync_manager.post_trigger(trigger_name)

# Legacy and cross-node RTPC aliases for backward compatibility
func set_rtpc_value(param_name: StringName, value: float, immediate: bool = false) -> void:
	set_rtpc(param_name, value, immediate)

func get_rtpc_value(param_name: StringName, default_value: float = 0.0) -> float:
	return get_rtpc(param_name, default_value)

func set_global_parameter(param_name: StringName, value: float, immediate: bool = false) -> void:
	set_rtpc(param_name, value, immediate)

func get_global_parameter(param_name: StringName) -> float:
	return get_rtpc(param_name)

# ==============================================================================
# EVENT DISPATCHING & LIFECYCLE
# ==============================================================================

## Configures the maximum physical voice pool size.
func set_max_physical_voices(count: int) -> void:
	voice_pool = VoicePoolManagerClass.new(count)

## Fija una posicion fija de oyente, con prioridad sobre la regla automatica.
func set_listener_position(pos: Vector3) -> void:
	active_listener_position = pos
	if listener_resolver != null:
		listener_resolver.set_listener_position(pos)

## Fija un nodo como oyente explicito, para juegos con el oyente desacoplado de
## la camara. Pasar null vuelve a la regla automatica de Godot.
func set_listener_node(node: Node3D) -> void:
	if listener_resolver != null:
		listener_resolver.set_listener_node(node)

## Vuelve a la regla automatica: AudioListener3D activo y, en su defecto, camara.
func clear_listener_override() -> void:
	if listener_resolver != null:
		listener_resolver.clear_override()

## Registers an event definition into the global registry.
func register_event_definition(event_def: AudioEventDef) -> void:
	if event_def and not event_def.event_name.is_empty():
		event_registry[event_def.event_name] = event_def

## Posts an audio event by name or by definition, returning the instantiated EventInstance.
func post_event(event: Variant, caller: Node = null) -> EventInstance:
	var def: AudioEventDef = null
	
	if event is AudioEventDef:
		def = event
	elif event is String or event is StringName:
		var event_name: StringName = StringName(event)
		if event_registry.has(event_name):
			def = event_registry[event_name]
		else:
			push_warning("[OpenDou] Event '%s' not found in registry." % str(event_name))
			return null
			
	if not def:
		return null
		
	var instance: EventInstance = EventInstanceClass.new(def, caller)
	active_instances.append(instance)
	instance.play()
	return instance

## Stops all currently playing event instances.
func stop_all() -> void:
	for instance in active_instances:
		instance.stop()
	active_instances.clear()

## Empuja los valores calculados de cada voz fisica a su reproductor nativo.
##
## Este paso es el que faltaba: sin el, calculated_volume_db,
## calculated_pitch_scale y el cutoff de oclusion se recalculan cada frame y no
## afectan a ningun sonido. Una voz arrancaba en el suelo de -80 dB que pone
## play_stream() y se quedaba ahi para siempre.
func _apply_voices() -> void:
	if voice_pool == null:
		return
	for instance in active_instances:
		if instance == null or instance.assigned_channel_id < 0:
			continue
		var ch = voice_pool.get_channel(instance.assigned_channel_id)
		if ch == null or not ch.is_busy:
			continue
		var cutoff: float = float(instance.calculated_properties.get(&"cutoff_hz", 20000.0))
		ch.apply(
			instance.calculated_volume_db,
			instance.calculated_pitch_scale,
			cutoff,
			instance.emitter_position
		)

## Resuelve el oyente del frame y actualiza la posicion cacheada.
func _update_listener() -> void:
	if listener_resolver == null or not is_inside_tree():
		return
	if listener_resolver.resolve(get_viewport()):
		active_listener_position = listener_resolver.position

## Main frame update loop.
func _process(delta: float) -> void:
	# 1. Resolver el oyente. Todo lo que dependa de distancia va DESPUES.
	_update_listener()

	# 2. Live Update remoto.
	if live_update_server and live_update_server.is_server_running:
		live_update_server.poll()
		live_update_server.dispatch_commands(event_registry, sync_manager)

	# 3. Game Syncs (RTPCs y transiciones de estado).
	if sync_manager:
		sync_manager.process(delta)

	# 4. Parametros de instancia y limpieza de las terminadas.
	for i in range(active_instances.size() - 1, -1, -1):
		var instance: EventInstance = active_instances[i]
		instance.interpolate_locals(delta)
		var global_rtpcs = sync_manager.global_rtpcs if sync_manager else {}
		instance.update_parameters(delta, global_rtpcs)
		if instance.is_finished():
			if voice_pool and instance.assigned_channel_id >= 0:
				voice_pool.virtualize(instance)
			active_instances.remove_at(i)

	# 5. Asignar permiso: quien es audible dentro del presupuesto.
	if voice_pool:
		voice_pool.resolve_voice_stealing(active_instances, active_listener_position, delta)

	# 6. Aplicar los valores calculados a los reproductores reales.
	_apply_voices()

	# 7. Telemetria.
	if live_update_server and live_update_server.is_server_running:
		var phys_count = voice_pool.get_active_physical_count() if voice_pool else 0
		var virt_count = voice_pool.get_active_virtual_count(active_instances) if voice_pool else 0
		live_update_server.send_telemetry(phys_count, virt_count, active_instances.size())
