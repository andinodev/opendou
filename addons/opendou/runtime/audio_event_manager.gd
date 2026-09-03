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
const EnvironmentStateClass = preload("res://addons/opendou/runtime/spatial/environment_state.gd")
const MediumFilterInstallerClass = preload("res://addons/opendou/runtime/spatial/medium_filter_installer.gd")
const AccessibilityApplierClass = preload("res://addons/opendou/runtime/accessibility_applier.gd")
const OcclusionSchedulerClass = preload("res://addons/opendou/runtime/spatial/occlusion_scheduler.gd")
const RoomPathDispatcherClass = preload("res://addons/opendou/runtime/spatial/room_path_dispatcher.gd")
const SpatialBackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")
const SpatialSettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")
const InstanceLimiterClass = preload("res://addons/opendou/runtime/instance_limiter.gd")
const MixChainInstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")
const LoudnessMeterClass = preload("res://addons/opendou/runtime/loudness_meter.gd")
const MixBusApplierClass = preload("res://addons/opendou/runtime/mix_bus_applier.gd")
const DistanceModelClass = preload("res://addons/opendou/runtime/spatial/distance_model.gd")
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
## Velocidad del oyente (m/s), por diferencia de posicion entre frames. Para el doppler.
var listener_velocity: Vector3 = Vector3.ZERO
var _listener_seen: bool = false

## Quien convierte las voces 3D en estereo: &"godot" o &"steam_audio". Se decide una vez
## en _init y no cambia en caliente. Lo leen el pool de voces, el menu, el HUD y la suite.
var spatial_backend: StringName = &"godot"

## Ajustes de espacializacion del jugador (HRTF, mezcla, salida). Persisten en user:// y se
## aplican en vivo a los streams nativos del pool al cambiar.
var spatial_settings: OpenDouSpatialSettings = null

## Limites de instancias por evento, emisor y radio (Fase 8). Se consulta en post_event.
var instance_limiter: OpenDouInstanceLimiter = null

## Medidor de sonoridad BS.1770 (Fase 8). Apagado por defecto: se engancha a un bus con
## loudness_meter.attach(); mientras este enganchado, el manager lo alimenta por frame.
var loudness_meter: OpenDouLoudnessMeter = null

## Mezcla dinamica aplicada al AudioServer (Fase 8): instantaneas, ducking y filtros por bus,
## sobre la base que deja el jugador. Hasta esta fase nadie escribia estos valores.
var mix: OpenDouMixBusApplier = null

## Pila de instantaneas de mezcla. El tope manda; al vaciarse, Default.
var _snapshot_stack: Array[Dictionary] = []   # {"name": StringName, "priority": int}

## Vinculaciones estado -> instantanea (MixStateBinding).
var _mix_state_bindings: Array = []

## Pool de reproductores nativos para las voces anonimas.
##
## Se crea en _init() para que el manager sea coherente desde el primer momento,
## y se mete en el arbol en _ready(): un reproductor fuera del arbol no puede
## reproducir, asi que sin ese paso las voces cambiarian de estado sin sonar.
var player_pool: OpenDouNativePlayerPool = null

## Resolutor del oyente activo.
var listener_resolver: OpenDouListenerResolver = null
## El OpenDouListener3D registrado (Fase 10), si hay uno.
var _listener_node_ref: WeakRef = null
## Entorno (Fase 10): volumenes registrados y estado efectivo del oyente.
var acoustic_volumes: Array = []
var environment: OpenDouEnvironmentState = EnvironmentStateClass.new()
var _active_medium_snapshot: StringName = &""
var _had_culled: bool = false
## Fase 13: fuente de oyente del simulador por sala (room_name -> handle) y bus con convolucion.
var _room_listener_sources: Dictionary = {}
var _reflections_started: bool = false
var _listener_room_name: StringName = &""
## Camas ambisonicas registradas (Fase 13): reciben la orientacion del oyente cada cuadro.
var _ambisonic_beds: Array = []
## Fase 13: el dispositivo tiene mas de dos canales. Los tests lo fuerzan para afirmar la decision.
var surround_available: bool = AudioServer.get_speaker_mode() != AudioServer.SPEAKER_MODE_STEREO
var _warned_hrtf_override: String = ""

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
	sync_manager.state_changed.connect(_on_state_changed_for_mix)
	bank_manager = SoundBankManagerClass.new()
	spatial_acoustics = SpatialAcousticsManagerClass.new()
	live_update_server = LiveUpdateServerClass.new()
	voice_pool = VoicePoolManagerClass.new(64)
	player_pool = NativePlayerPoolClass.new(64)
	voice_pool.set_player_pool(player_pool)
	voice_pool.spatial_backend = spatial_backend
	listener_resolver = ListenerResolverClass.new()
	if spatial_acoustics != null:
		spatial_acoustics.surface_volumes = acoustic_volumes
	occlusion_scheduler = OcclusionSchedulerClass.new()
	occlusion_scheduler.voice_pool = voice_pool
	occlusion_scheduler.use_simulator = is_steam_audio_backend()
	if spatial_acoustics != null:
		spatial_acoustics.convolution_allowed = is_steam_audio_backend()
	room_path_dispatcher = RoomPathDispatcherClass.new()
	room_path_dispatcher.acoustics = spatial_acoustics
	reflection_dispatcher = ReflectionDispatcherClass.new()
	hdr_engine = AudioHDREngineClass.new()
	instance_limiter = InstanceLimiterClass.new()
	loudness_meter = LoudnessMeterClass.new()
	mix = MixBusApplierClass.new()
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
	# Cadena de masterizacion en Master segun el ajuste de proyecto (vacio = nada). Idempotente.
	MixChainInstallerClass.install_from_setting()

## Aplica los ajustes del jugador a todos los streams nativos, en vivo. Con backend godot
## no hay streams y no hace nada; el menu lo muestra deshabilitado.
func _apply_spatial_settings() -> void:
	# Accesibilidad (Fase 10) sobre Master: vale para los dos backends.
	if spatial_settings != null:
		AccessibilityApplierClass.apply(spatial_settings)
	var node: Node3D = get_listener_node()
	# El radio de la cabeza va al C++ aunque el backend activo sea godot: es barato y asi el
	# cambio de backend no lo pierde.
	if ClassDB.class_exists("OpenDouSpatialStream"):
		var c: float = environment.speed_of_sound if environment != null else 343.0
		ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", node.head_radius_m if node != null else 0.0875, c)
	if spatial_settings == null or not is_steam_audio_backend():
		return
	var speakers: bool = spatial_settings.output == "speakers"
	if node != null and node.output_mode != 0:
		speakers = node.output_mode == 2
	# Altavoces: estereo con nuestro paneo (1); surround real, mono procesado y Godot panea (2).
	var mode: int = 0
	if speakers:
		mode = 2 if surround_available else 1
	var blend: float = spatial_settings.blend
	if player_pool != null:
		player_pool.default_spatial_blend = blend
		player_pool.default_output_mode = mode
		player_pool.set_host_panning(1.0 if mode == 2 else 0.0)
		# Se escribe en todos los streams; en los ocupados el canal lo sobreescribe cada frame
		# como factor por voz (default_spatial_blend x (1 - spread), Fase 9), que sin spread
		# es el mismo valor.
		player_pool.for_each_spatial_stream(func(s): s.spatial_blend = blend; s.output_mode = mode)
	# El SOFA del oyente manda sobre el del jugador; si no carga, se avisa una vez y se sigue.
	if node != null and not node.hrtf_override.is_empty():
		if bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", node.hrtf_override)):
			return
		if _warned_hrtf_override != node.hrtf_override:
			_warned_hrtf_override = node.hrtf_override
			push_warning("[OpenDou] el HRTF del oyente %s no se pudo cargar: manda el del jugador" % node.hrtf_override)
	if spatial_settings.hrtf == "default":
		if str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name")) != "default":
			ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_default")
	elif not bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", spatial_settings.hrtf)):
		push_warning("[OpenDou] el HRTF %s no se pudo cargar: se vuelve al incorporado" % spatial_settings.hrtf)
		spatial_settings.hrtf = "default"
	spatial_settings.save_to_disk()

## Cuanto de cada voz activa llega a `position` (Fase 10, la IA oye). Reutiliza el grafo de
## salas y la oclusion con otro destino; por eso cuesta un rayo por voz si hay world_3d.
## loudness_db = sonoridad de diseno + volumen calculado (sin la oclusion hacia el oyente,
## que aqui no aplica) + distancia con el modelo de la instancia + camino.
func get_loudness_at(position: Vector3, world_3d: World3D = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var point_room: StringName = &""
	if spatial_acoustics != null:
		var r = spatial_acoustics.get_room_at_position(position)
		if r != null:
			point_room = r.room_name
	for instance in active_instances:
		if instance == null or instance.definition == null or not instance.has_spatial_position or not instance.is_playing():
			continue
		var d: float = instance.emitter_position.distance_to(position)
		var db: float = instance.definition.hdr_loudness_db + instance.calculated_volume_db - instance.occlusion_attenuation_db
		db += DistanceModelClass.attenuation_db(d, instance.attenuation_model, instance.unit_size, instance.attenuation_curve, instance.attenuation_curve_distance_m)
		var emitter_room: StringName = &""
		if spatial_acoustics != null:
			var er = spatial_acoustics.get_room_at_position(instance.emitter_position)
			if er != null:
				emitter_room = er.room_name
		if room_path_dispatcher != null and emitter_room != &"" and point_room != &"" and emitter_room != point_room:
			var chain: Dictionary = room_path_dispatcher.chain_for(emitter_room, point_room, instance.emitter_position, position)
			if bool(chain.sealed):
				db += room_path_dispatcher.max_attenuation_db
			else:
				var virtual_distance: float = instance.emitter_position.distance_to(chain.entry_pos) + float(chain.chain_length) + Vector3(chain.exit_pos).distance_to(position)
				db += room_path_dispatcher.attenuation_db_for(virtual_distance, chain.exit_pos, position)
				var min_open: float = 1.0
				for portal in chain.portals:
					min_open = minf(min_open, portal.open_factor)
				# Un portal cerrado no es un muro: -26 dB (open_factor 0.05) para que la IA oiga
				# algo a traves de una puerta, como el jugador.
				db += 20.0 * (log(maxf(min_open, 0.05)) / log(10.0))
		elif world_3d != null and occlusion_scheduler != null:
			var query := PhysicsRayQueryParameters3D.create(instance.emitter_position, position, occlusion_scheduler.collision_mask)
			var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
			var ray_hits: Array[bool] = [not hit.is_empty()]
			db += occlusion_scheduler.occlusion_manager.evaluate_occlusion(instance.emitter_position, position, ray_hits).volume_attenuation_db
			for v in acoustic_volumes:
				if v != null and is_instance_valid(v) and v.environment != null and v.environment.occluder_enabled:
					db -= v.environment.occluder_db_per_m * v.segment_length_inside(instance.emitter_position, position)
		out.append({"instance": instance, "event_name": instance.definition.event_name, "loudness_db": db, "from_position": instance.emitter_position})
	return out

## Registra un OpenDouAcousticVolume3D (Fase 10).
func register_acoustic_volume(volume: Node3D) -> void:
	if not acoustic_volumes.has(volume):
		acoustic_volumes.append(volume)
	if spatial_acoustics != null:
		spatial_acoustics.surface_volumes = acoustic_volumes

func unregister_acoustic_volume(volume: Node3D) -> void:
	acoustic_volumes.erase(volume)

## Resuelve el entorno del oyente y empuja el medio a quien lo necesita, solo si cambio.
func _update_environment(delta: float) -> void:
	if acoustic_volumes.is_empty() and environment.inside.is_empty() and is_equal_approx(environment.speed_of_sound, 343.0):
		return
	environment.update(acoustic_volumes, active_listener_position, delta)
	if not environment.medium_changed:
		return
	var c: float = environment.speed_of_sound
	if voice_pool != null:
		voice_pool.set_speed_of_sound(c)
	if spatial_acoustics != null:
		spatial_acoustics.speed_of_sound = c
	if ClassDB.class_exists("OpenDouSpatialStream"):
		var node: Node3D = get_listener_node()
		ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", node.head_radius_m if node != null else 0.0875, c)
	MediumFilterInstallerClass.apply(environment.medium_lowpass_hz)
	if environment.medium_snapshot != _active_medium_snapshot:
		if _active_medium_snapshot != &"":
			pop_snapshot(_active_medium_snapshot)
		if environment.medium_snapshot != &"":
			push_snapshot(environment.medium_snapshot)
		_active_medium_snapshot = environment.medium_snapshot

func register_ambisonic_bed(bed: Node) -> void:
	if not _ambisonic_beds.has(bed):
		_ambisonic_beds.append(bed)

func unregister_ambisonic_bed(bed: Node) -> void:
	_ambisonic_beds.erase(bed)

## Fuente de oyente para una sala (la crea si no existe). -1 sin simulador con reflexiones.
func listener_source_for_room(room_name: StringName) -> int:
	if _room_listener_sources.has(room_name):
		return int(_room_listener_sources[room_name])
	if not ClassDB.class_exists("OpenDouSimulator") or not bool(ClassDB.class_call_static("OpenDouSimulator", "is_ready")):
		return -1
	var h: int = int(ClassDB.class_call_static("OpenDouSimulator", "create_listener_source"))
	if h >= 0:
		_room_listener_sources[room_name] = h
	return h

## RT60 por banda trazado para la sala; cero si no hay resultado.
func get_room_reverb_times(room_name: StringName) -> Vector3:
	if not _room_listener_sources.has(room_name) or not ClassDB.class_exists("OpenDouSimulator"):
		return Vector3.ZERO
	return ClassDB.class_call_static("OpenDouSimulator", "get_reverb_times", int(_room_listener_sources[room_name]))

## Sala del oyente: mueve su fuente de oyente, arranca el hilo de reflexiones la primera vez y
## pone la convolucion en el bus de la sala si la sala lo pide y el simulador esta.
func _update_listener_room() -> void:
	if spatial_acoustics == null or not is_steam_audio_backend():
		return
	var room = spatial_acoustics.get_room_at_position(active_listener_position)
	if room == null or room.reverb_mode != 2:
		return
	if occlusion_scheduler == null or not occlusion_scheduler.ensure_simulator():
		return
	var h: int = listener_source_for_room(room.room_name)
	if h < 0:
		return
	# El oyente compartido del simulador lo fijaba solo el planificador cuando habia voces
	# simuladas; sin voces, las reflexiones no tenian oyente y no trazaban nada.
	ClassDB.class_call_static("OpenDouSimulator", "set_listener", active_listener_position, -active_listener_basis.z, active_listener_basis.y)
	ClassDB.class_call_static("OpenDouSimulator", "set_listener_source_position", h, active_listener_position)
	if not _reflections_started:
		ClassDB.class_call_static("OpenDouSimulator", "start_reflections", 10.0)
		_reflections_started = true
	if room.assigned_reverb_bus != &"" and spatial_acoustics.reverb_bus_pool != null and not spatial_acoustics.reverb_bus_pool.has_convolution(room.assigned_reverb_bus):
		spatial_acoustics.reverb_bus_pool.install_convolution(room.assigned_reverb_bus, h, room.reverb_send_amount)
	_listener_room_name = room.room_name

func _exit_tree() -> void:
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "stop_reflections")
	_reflections_started = false
	_room_listener_sources.clear()
	# No dejar el filtro del medio en Master cuando el manager se va (tests, cambio de escena).
	MediumFilterInstallerClass.apply(20000.0)
	if ClassDB.class_exists("OpenDouSpatialStream"):
		ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.0875, 343.0)
	AccessibilityApplierClass.apply_mono(false)
	if spatial_settings != null and spatial_settings.night_mode:
		AccessibilityApplierClass.apply_night(false)

## Registra el OpenDouListener3D (Fase 10). Si hay dos, manda el ultimo y se avisa una vez.
func register_listener(node: Node3D) -> void:
	var current = _listener_node_ref.get_ref() if _listener_node_ref != null else null
	if current != null and current != node:
		push_warning("[OpenDou] hay mas de un OpenDouListener3D: manda el ultimo registrado (%s)" % node.name)
	_listener_node_ref = weakref(node)
	listener_resolver.set_opendou_listener(node)
	if not node.listener_changed.is_connected(_apply_spatial_settings):
		node.listener_changed.connect(_apply_spatial_settings)
	_apply_spatial_settings()

func unregister_listener(node: Node3D) -> void:
	if _listener_node_ref == null or _listener_node_ref.get_ref() != node:
		return
	if node.listener_changed.is_connected(_apply_spatial_settings):
		node.listener_changed.disconnect(_apply_spatial_settings)
	_listener_node_ref = null
	listener_resolver.set_opendou_listener(null)
	_apply_spatial_settings()

func get_listener_node() -> Node3D:
	if _listener_node_ref == null:
		return null
	var n = _listener_node_ref.get_ref()
	return n if n != null and is_instance_valid(n) else null

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

# ==============================================================================
# MEZCLA DINAMICA: INSTANTANEAS Y BASE POR BUS
# ==============================================================================

## Apila una instantanea de mezcla y transiciona al tope. OpenDouParameterArea3D lo llama al
## entrar el oyente; MixStateBinding, al entrar en un estado.
func push_snapshot(name: StringName, blend_sec: float = -1.0, priority: int = 0) -> void:
	if not mix.snapshots.registered_snapshots.has(name):
		push_warning("[OpenDou] push_snapshot: la instantanea '%s' no esta registrada" % String(name))
		return
	_snapshot_stack.append({"name": name, "priority": priority})
	_apply_snapshot_top(blend_sec)

## Quita la ultima entrada de ese nombre, este o no en el tope, y transiciona al tope
## resultante (Default si la pila queda vacia).
func pop_snapshot(name: StringName, blend_sec: float = -1.0) -> void:
	for i in range(_snapshot_stack.size() - 1, -1, -1):
		if _snapshot_stack[i]["name"] == name:
			_snapshot_stack.remove_at(i)
			break
	_apply_snapshot_top(blend_sec)

## El tope es la de mayor prioridad; a igual prioridad, la mas reciente.
func _apply_snapshot_top(blend_sec: float) -> void:
	var top: StringName = &"Default"
	var best_priority: int = -2147483648
	for entry in _snapshot_stack:
		if int(entry["priority"]) >= best_priority:
			best_priority = int(entry["priority"])
			top = entry["name"]
	mix.snapshots.transition_to(top, blend_sec)

## Registra una vinculacion estado -> instantanea. Si el estado ya esta activo, apila ahora.
func register_mix_state_binding(binding: MixStateBinding) -> void:
	if binding == null or _mix_state_bindings.has(binding):
		return
	_mix_state_bindings.append(binding)
	if sync_manager.get_state(binding.state_group) == binding.state_name:
		push_snapshot(binding.snapshot_name, binding.blend_sec, binding.priority)

func unregister_mix_state_binding(binding: MixStateBinding) -> void:
	if _mix_state_bindings.has(binding):
		_mix_state_bindings.erase(binding)
		pop_snapshot(binding.snapshot_name, binding.blend_sec)

func _on_state_changed_for_mix(group: StringName, new_state: StringName, previous: StringName) -> void:
	for b in _mix_state_bindings:
		if b.state_group != group:
			continue
		if b.state_name == previous:
			pop_snapshot(b.snapshot_name, b.blend_sec)
		if b.state_name == new_state:
			push_snapshot(b.snapshot_name, b.blend_sec, b.priority)

## Volumen base de un bus: lo que el jugador o el proyecto dejaron, sin instantaneas ni
## ducking. Quien mueva volumenes de bus por su cuenta lo hace por aqui.
func set_bus_base_volume_db(bus: StringName, db: float) -> void:
	mix.set_bus_base_volume_db(bus, db)

func get_bus_base_volume_db(bus: StringName) -> float:
	return mix.get_bus_base_volume_db(bus)

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
func _apply_voices(delta: float) -> void:
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
			instance.set_orientation(-pos_node.global_transform.basis.z)
		# Movimiento y doppler (Fase 9). En steam_audio con retardo por distancia lo produce la
		# linea de retardo y aqui se fuerza a 1: aplicarlo dos veces doblaria el efecto.
		instance.update_motion(delta)
		var to_listener: Vector3 = active_listener_position - instance.emitter_position
		if instance.doppler_enabled and instance.has_spatial_position and not (is_steam_audio_backend() and instance.propagation_delay_enabled):
			var factor: float = spatial_acoustics.calculate_doppler_pitch(instance.emitter_velocity + instance.flow_velocity, listener_velocity, to_listener)
			instance.doppler_pitch = lerpf(instance.doppler_pitch, factor, clampf(10.0 * delta, 0.0, 1.0))
		else:
			instance.doppler_pitch = 1.0
		var volume_db: float = instance.calculated_volume_db
		# calculate_voice_gain_db() devuelve el nivel de salida relativo a la
		# ventana, siempre <= 0, asi que funciona como atenuacion. Su entrada es la
		# sonoridad de DISENO del evento, no el nivel de mezcla.
		if hdr_enabled and hdr_engine != null and instance.definition != null:
			volume_db += hdr_engine.calculate_voice_gain_db(instance.definition.hdr_loudness_db)
		# Fundido de stop(fade): multiplica la ganancia hasta que la instancia termine sola.
		volume_db += linear_to_db(maxf(instance.stop_fade_gain(), 0.0001))
		# Directividad (GDScript en ambos backends; la nativa llega en la Fase 12).
		# Con fuente del simulador la directividad la aplica el efecto directo: no se suma dos veces.
		if instance.has_spatial_position and instance.directivity_dipole_weight > 0.0 and not ch.uses_direct_effect():
			volume_db += DistanceModelClass.directivity_db(instance.emitter_forward, to_listener, instance.directivity_dipole_weight, instance.directivity_power)
		var pitch: float = instance.calculated_pitch_scale * instance.doppler_pitch
		if environment.medium_pitch_scale != 1.0:
			pitch *= environment.medium_pitch_scale
		var cutoff: float = float(instance.calculated_properties.get(&"cutoff_hz", 20000.0))
		# Viento (Fase 10): aproximacion perceptual, no fisica. En contra: menos nivel y menos
		# agudos, solo para las voces lejanas. Sin viento no cuesta nada.
		if instance.has_spatial_position and environment.has_wind():
			var dist: float = to_listener.length()
			if dist > environment.wind_min_distance_m and dist > 0.001:
				var headwind: float = maxf(0.0, -environment.wind_velocity.dot(to_listener / dist))
				if headwind > 0.0:
					volume_db -= minf(12.0, 0.3 * headwind)
					cutoff *= 1.0 - 0.5 * clampf(headwind / 20.0, 0.0, 1.0)
		# Capas del contenedor (Fase 11): con un arbol determinista los desplazamientos se
		# re-resuelven cada cuadro, y asi un blend por RTPC cruza de verdad.
		if instance.live_blend and instance.definition != null:
			var voices = instance.definition.resolve_voices(instance.playback_context)
			for k in range(instance.voice_streams.size()):
				var off: float = -80.0
				var pm: float = 1.0
				for v in voices:
					if v.stream == instance.voice_streams[k]:
						off = v.volume_offset_db
						pm = v.pitch_modifier
						break
				instance.voice_offsets_db[k] = off
				instance.voice_pitch_mods[k] = pm
		var primary_offset: float = instance.voice_offsets_db[0] if not instance.voice_offsets_db.is_empty() else 0.0
		var primary_pitch: float = instance.voice_pitch_mods[0] if not instance.voice_pitch_mods.is_empty() else 1.0
		# La posicion aparente es igual a la del emisor salvo cuando el grafo de salas
		# gobierna la voz, asi que aqui no hace falta ninguna rama.
		if instance.has_spatial_position:
			ch.apply_spatial(instance, volume_db + primary_offset, pitch * primary_pitch, cutoff, active_listener_position, active_listener_basis)
		else:
			ch.apply(volume_db + primary_offset, pitch * primary_pitch, cutoff, instance.current_apparent_position)
		for k in range(instance.layer_channel_ids.size()):
			var lch = voice_pool.get_channel(instance.layer_channel_ids[k])
			if lch == null or not lch.is_busy:
				continue
			var lv: float = volume_db + instance.voice_offsets_db[k + 1]
			var lp: float = pitch * instance.voice_pitch_mods[k + 1]
			if instance.has_spatial_position:
				lch.apply_spatial(instance, lv, lp, cutoff, active_listener_position, active_listener_basis)
			else:
				lch.apply(lv, lp, cutoff, instance.current_apparent_position)

## Las reflexiones autoradas (reflectores) no se emiten donde la sala ya trae la IR real
## (CONVOLUTION con extension): quedan como ajuste artistico en salas Sabine (Fase 13).
func reflections_allowed_for(instance) -> bool:
	if reflection_dispatcher != null and not reflection_dispatcher.enabled:
		return false
	if spatial_acoustics == null or not spatial_acoustics.convolution_allowed or instance == null:
		return true
	var room = spatial_acoustics.get_room_at_position(instance.emitter_position)
	return room == null or room.reverb_mode != 2

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
		if node != null and "enable_early_reflections" in node and node.enable_early_reflections and reflections_allowed_for(instance):
			reflection_dispatcher.dispatch(instance, active_listener_position, w3d)

## Resuelve el oyente del frame y actualiza la posicion cacheada.
func _update_listener() -> void:
	if listener_resolver == null or not is_inside_tree():
		return
	if listener_resolver.resolve(get_viewport()):
		var previous_pos: Vector3 = active_listener_position
		active_listener_position = listener_resolver.position
		active_listener_basis = listener_resolver.basis
		var dt: float = get_process_delta_time()
		listener_velocity = (active_listener_position - previous_pos) / dt if dt > 0.0 and _listener_seen else Vector3.ZERO
		_listener_seen = true

## Main frame update loop.
func _process(delta: float) -> void:
	# 1. Resolver el oyente. Todo lo que dependa de distancia va DESPUES.
	_update_listener()
	# 1b. Entorno del oyente (Fase 10): medio, viento, descarte.
	_update_environment(delta)
	# 1c. Sala del oyente (Fase 13): fuente de oyente, hilo de reflexiones y convolucion.
	_update_listener_room()
	# 1d. Camas ambisonicas (Fase 13): la orientacion del oyente a cada una.
	for bed in _ambisonic_beds:
		if bed != null and is_instance_valid(bed):
			bed.set_listener_basis(active_listener_basis)

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
		occlusion_scheduler.set_listener_basis(active_listener_basis)
		occlusion_scheduler.process(active_instances, active_listener_position, w3d, acoustic_volumes)

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

	# 5c. Medidor de sonoridad, solo si alguien lo engancho.
	if loudness_meter != null and loudness_meter.is_attached():
		loudness_meter.process()

	# 5d. La mezcla dinamica llega a los buses: base + instantanea + ducking.
	if mix != null:
		mix.apply(delta)

	# 5e. Descarte por entorno (Fase 10): peso cero en el robo, sin rayos. Solo se recorre
	# si hay algo que descartar o lo hubo el cuadro anterior.
	if not environment.culled_buses.is_empty() or _had_culled:
		_had_culled = not environment.culled_buses.is_empty()
		for instance in active_instances:
			var bus: StringName = instance.definition.target_bus if instance.definition != null else &""
			instance.culled = environment.is_culled(bus)

	# 6. Asignar permiso: quien es audible dentro del presupuesto.
	if voice_pool:
		voice_pool.resolve_voice_stealing(active_instances, active_listener_position, delta)

	# 7. Aplicar los valores calculados a los reproductores reales.
	_apply_voices(delta)

	# 7b. Reflexiones tempranas de las voces que las tengan activadas.
	_dispatch_reflections()

	# 8. Telemetria.
	if live_update_server and live_update_server.is_server_running:
		var phys_count = voice_pool.get_active_physical_count() if voice_pool else 0
		var virt_count = voice_pool.get_active_virtual_count(active_instances) if voice_pool else 0
		live_update_server.send_telemetry(phys_count, virt_count, active_instances.size())
