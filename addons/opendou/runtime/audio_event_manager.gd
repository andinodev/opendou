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
const OcclusionSchedulerClass = preload("res://addons/opendou/runtime/spatial/occlusion_scheduler.gd")
const RoomPathDispatcherClass = preload("res://addons/opendou/runtime/spatial/room_path_dispatcher.gd")
const SpatialBackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")
const SpatialSettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")
const InstanceLimiterClass = preload("res://addons/opendou/runtime/instance_limiter.gd")
const ReflectionDispatcherClass = preload("res://addons/opendou/runtime/reflection_dispatcher.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")

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
## Orientacion del oyente del frame. El backend steam_audio la necesita para la direccion.
var active_listener_basis: Basis = Basis.IDENTITY

## Quien convierte las voces 3D en estereo: &"godot" o &"steam_audio". Se decide una vez
## en _init y no cambia en caliente. Lo leen el pool de voces, el menu, el HUD y la suite.
var spatial_backend: StringName = &"godot"

## Ajustes de espacializacion del jugador (HRTF, mezcla, salida). Persisten en user:// y se
## aplican en vivo a los streams nativos del pool al cambiar.
var spatial_settings: OpenDouSpatialSettings = null

## Limites de instancias por evento, emisor y radio (Fase 8). Se consulta en post_event.
var instance_limiter: OpenDouInstanceLimiter = null

## Pool de reproductores nativos para las voces anonimas.
##
## Se crea en _init() para que el manager sea coherente desde el primer momento,
## y se mete en el arbol en _ready(): un reproductor fuera del arbol no puede
## reproducir, asi que sin ese paso las voces cambiarian de estado sin sonar.
var player_pool: OpenDouNativePlayerPool = null

## Resolutor del oyente activo.
var listener_resolver: OpenDouListenerResolver = null

## Programador unico de raycasts de oclusion, con presupuesto por frame.
var occlusion_scheduler: OpenDouOcclusionScheduler = null

## Aplica el grafo de salas y portales a las voces fisicas.
##
## Antes de esto, salas y portales se calculaban y no llegaban a ninguna voz.
var room_path_dispatcher: OpenDouRoomPathDispatcher = null

## Despachador de reflexiones tempranas como voces del pool.
var reflection_dispatcher: OpenDouReflectionDispatcher = null

## Motor de ventana de sonoridad HDR.
##
## Estaba huerfano: solo lo usaba el mixer del editor. Existia ademas un segundo
## motor duplicado, HDRAudioManager, que solo accionaba una demo. Se consolido en
## este, que tiene ataque y liberacion separados, limites de ventana y senal de
## cambio.
var hdr_engine: AudioHDREngine = null

## Si el HDR contribuye a la mezcla.
##
## Va activado porque con la sonoridad por defecto de los eventos su contribucion
## es exactamente 0 dB: dejarlo apagado habria movido el huerfano del editor al
## runtime en lugar de arreglarlo.
var hdr_enabled: bool = true

func _init() -> void:
	spatial_backend = SpatialBackendClass.resolve(SpatialBackendClass.read_setting(), SpatialBackendClass.native_available())
	sync_manager = GameSyncManagerClass.new()
	bank_manager = SoundBankManagerClass.new()
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	live_update_server = LiveUpdateServerClass.new()
	voice_pool = VoicePoolManagerClass.new(64)
	player_pool = NativePlayerPoolClass.new(64)
	voice_pool.set_player_pool(player_pool)
	voice_pool.spatial_backend = spatial_backend
	listener_resolver = ListenerResolverClass.new()
	occlusion_scheduler = OcclusionSchedulerClass.new()
	room_path_dispatcher = RoomPathDispatcherClass.new()
	room_path_dispatcher.acoustics = spatial_acoustics
	reflection_dispatcher = ReflectionDispatcherClass.new()
	hdr_engine = AudioHDREngineClass.new()
	instance_limiter = InstanceLimiterClass.new()
	spatial_settings = SpatialSettingsClass.new()
	spatial_settings.changed.connect(_apply_spatial_settings)

func is_steam_audio_backend() -> bool:
	return spatial_backend == SpatialBackendClass.STEAM_AUDIO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Los reproductores solo pueden reproducir dentro del arbol.
	if player_pool != null and player_pool.get_parent() == null:
		add_child(player_pool)
	spatial_settings.load_from_disk()
	_apply_spatial_settings()

## Aplica los ajustes del jugador a todos los streams nativos, en vivo. Con backend godot
## no hay streams y no hace nada; el menu lo muestra deshabilitado.
func _apply_spatial_settings() -> void:
	if spatial_settings == null or not is_steam_audio_backend():
		return
	var mode: int = 1 if spatial_settings.output == "speakers" else 0
	var blend: float = spatial_settings.blend
	if player_pool != null:
		player_pool.default_spatial_blend = blend
		player_pool.default_output_mode = mode
		player_pool.for_each_spatial_stream(func(s): s.spatial_blend = blend; s.output_mode = mode)
	if spatial_settings.hrtf == "default":
		if str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name")) != "default":
			ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_default")
	elif not bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", spatial_settings.hrtf)):
		push_warning("[OpenDou] el HRTF %s no se pudo cargar: se vuelve al incorporado" % spatial_settings.hrtf)
		spatial_settings.hrtf = "default"
	spatial_settings.save_to_disk()

## Texto para el menu y el HUD: que backend suena y con que HRTF.
func spatial_backend_label() -> String:
	if not is_steam_audio_backend():
		return "Godot"
	return "Steam Audio %s · HRTF: %s" % [
		str(ClassDB.class_call_static("OpenDouSpatialStream", "get_steam_audio_version")),
		str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name"))]

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

## AudioStreamWAV de un stream de un banco cargado, listo para usar como
## base_stream de un AudioEventDef.
func get_bank_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV:
	if bank_manager == null:
		return null
	return bank_manager.get_stream(bank_name, stream_id)

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
## Cambia el presupuesto de voces fisicas.
##
## Antes esto era `voice_pool = VoicePoolManagerClass.new(count)` a secas, y el pool
## nuevo nacia SIN reproductores: devirtualize() salia temprano por player_pool == null
## y el motor entero se quedaba MUDO. Es la llamada mas obvia que haria un juego al
## arrancar -"quiero 32 voces"-, asi que el defecto dejaba sin audio a cualquiera que la
## usara.
func set_max_physical_voices(count: int) -> void:
	var target: int = maxi(1, count)
	if voice_pool != null and voice_pool.max_physical_voices == target:
		return
	# Las voces que estaban sonando hay que detenerlas por el camino bueno. Descartar
	# el pool sin mas dejaba sus reproductores sonando y las instancias apuntando a
	# canales de un pool que ya no existe.
	if voice_pool != null:
		for instance in active_instances:
			if instance != null and instance.assigned_channel_id >= 0:
				voice_pool.virtualize(instance)
	voice_pool = VoicePoolManagerClass.new(target)
	voice_pool.set_player_pool(player_pool)
	voice_pool.spatial_backend = spatial_backend

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

	# Limites de instancias: se decide ANTES de crear nada. Una rechazada no existe; una
	# robada se va con el fundido de la definicion.
	var has_position: bool = caller is Node3D
	var position: Vector3 = Vector3.ZERO
	if caller is Node3D:
		position = caller.global_position if caller.is_inside_tree() else caller.position
	var verdict: Dictionary = instance_limiter.check(def, caller, position, has_position, active_instances, active_listener_position)
	if not bool(verdict["allow"]):
		return null
	if verdict["steal"] != null:
		verdict["steal"].stop(def.limit_fade_out_sec)

	var instance: EventInstance = EventInstanceClass.new(def, caller)
	# El contexto se refresca ANTES de play(): la primera resolucion tiene que ver el
	# estado vivo, no un contexto vacio.
	var initial_rtpcs = sync_manager.global_rtpcs if sync_manager else {}
	instance.refresh_playback_context(initial_rtpcs, sync_manager)
	active_instances.append(instance)
	instance.play()
	return instance

## Stops all currently playing event instances.
func stop_all() -> void:
	for instance in active_instances:
		# virtualize() desconecta la senal finished, detiene el canal y devuelve el
		# reproductor al pool. Sin esto, stop_all() solo marcaba la instancia como
		# parada: el canal seguia ocupado, el reproductor seguia sonando -para siempre
		# si el evento era un bucle- y el Callable de finished retenia la instancia.
		if voice_pool != null and instance != null and instance.assigned_channel_id >= 0:
			voice_pool.virtualize(instance)
		instance.stop()
	active_instances.clear()

## Alimenta la ventana HDR con la sonoridad de las voces activas y la avanza.
##
## Tiene que ocurrir ANTES de aplicar, porque la ganancia de cada voz depende de
## donde quede la ventana este frame.
func _update_hdr(delta: float) -> void:
	if hdr_engine == null or not hdr_enabled:
		return
	for instance in active_instances:
		if instance == null or instance.definition == null:
			continue
		hdr_engine.push_event_loudness(instance.definition.hdr_loudness_db)
	hdr_engine.update(delta)

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
		# Emisor de nodo en steam_audio: el nodo dice donde esta la voz cada frame.
		var pos_node: Node3D = ch.get_position_node()
		if pos_node != null:
			instance.set_position(pos_node.global_position)
		var volume_db: float = instance.calculated_volume_db
		# calculate_voice_gain_db() devuelve el nivel de salida relativo a la
		# ventana, siempre <= 0, asi que funciona como atenuacion. Su entrada es la
		# sonoridad de DISENO del evento, no el nivel de mezcla.
		if hdr_enabled and hdr_engine != null and instance.definition != null:
			volume_db += hdr_engine.calculate_voice_gain_db(instance.definition.hdr_loudness_db)
		# Fundido de stop(fade): multiplica la ganancia hasta que la instancia termine sola.
		volume_db += linear_to_db(maxf(instance.stop_fade_gain(), 0.0001))
		var cutoff: float = float(instance.calculated_properties.get(&"cutoff_hz", 20000.0))
		# La posicion aparente es igual a la del emisor salvo cuando el grafo de salas
		# gobierna la voz, asi que aqui no hace falta ninguna rama.
		if instance.has_spatial_position:
			ch.apply_spatial(instance, volume_db, instance.calculated_pitch_scale, cutoff, active_listener_position, active_listener_basis)
		else:
			ch.apply(volume_db, instance.calculated_pitch_scale, cutoff, instance.current_apparent_position)

## Emite las reflexiones tempranas de las voces cuyo emisor las tenga activadas.
func _dispatch_reflections() -> void:
	if reflection_dispatcher == null or not is_inside_tree():
		return
	reflection_dispatcher.collect_finished()
	var vp := get_viewport()
	var w3d: World3D = vp.find_world_3d() if vp != null else null
	if w3d == null:
		return
	for instance in active_instances:
		if instance == null or instance.assigned_channel_id < 0:
			continue
		var node = instance.get_bound_player()
		if node != null and "enable_early_reflections" in node and node.enable_early_reflections:
			reflection_dispatcher.dispatch(instance, active_listener_position, w3d)

## Resuelve el oyente del frame y actualiza la posicion cacheada.
func _update_listener() -> void:
	if listener_resolver == null or not is_inside_tree():
		return
	if listener_resolver.resolve(get_viewport()):
		active_listener_position = listener_resolver.position
		active_listener_basis = listener_resolver.basis

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

	# 3b. Camino por salas y portales. Va ANTES de la oclusion para que la oclusion pueda
	# saltarse las voces que el grafo gobierna: sin eso, el mismo mamparo se cobraria dos
	# veces y el presupuesto de raycasts se gastaria en voces ya resueltas.
	if room_path_dispatcher != null:
		room_path_dispatcher.process_pool(voice_pool, active_listener_position)

	# 4. Oclusion presupuestada: un unico manager y un techo de raycasts.
	if occlusion_scheduler != null and is_inside_tree():
		var vp := get_viewport()
		var w3d: World3D = vp.find_world_3d() if vp != null else null
		occlusion_scheduler.process(active_instances, active_listener_position, w3d)

	# 5. Parametros de instancia y limpieza de las terminadas.
	for i in range(active_instances.size() - 1, -1, -1):
		var instance: EventInstance = active_instances[i]
		instance.interpolate_locals(delta)
		var global_rtpcs = sync_manager.global_rtpcs if sync_manager else {}
		instance.update_parameters(delta, global_rtpcs)
		instance.refresh_playback_context(global_rtpcs, sync_manager)
		if instance.is_finished():
			# virtualize() suelta el canal pero deja la instancia en STATE_VIRTUAL, y una
			# instancia terminada y fuera de la lista respondia is_playing() == true. Se
			# conserva el estado final (STOPPED o KILLED) tras soltar el canal.
			var final_state = instance.voice_state
			if voice_pool and instance.assigned_channel_id >= 0:
				voice_pool.virtualize(instance)
			instance.voice_state = final_state
			active_instances.remove_at(i)

	# 5b. Ventana HDR: se alimenta con la sonoridad de las voces activas y avanza
	# antes de aplicar, porque la ganancia de cada voz depende de donde quede.
	_update_hdr(delta)

	# 6. Asignar permiso: quien es audible dentro del presupuesto.
	if voice_pool:
		voice_pool.resolve_voice_stealing(active_instances, active_listener_position, delta)

	# 7. Aplicar los valores calculados a los reproductores reales.
	_apply_voices()

	# 7b. Reflexiones tempranas de las voces que las tengan activadas.
	_dispatch_reflections()

	# 8. Telemetria.
	if live_update_server and live_update_server.is_server_running:
		var phys_count = voice_pool.get_active_physical_count() if voice_pool else 0
		var virt_count = voice_pool.get_active_virtual_count(active_instances) if voice_pool else 0
		live_update_server.send_telemetry(phys_count, virt_count, active_instances.size())
