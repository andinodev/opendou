class_name MonsoonDemo
extends Node3D

## «El monzon»: el pool y el HDR bajo presion.
##
## Noche en una terraza de arroz. Lluvia sobre tres superficies, un canal de riego a lo
## largo del terraplen, enjambres de cigarras, ranas y viento en el dosel.
##
## LA TESIS: 200 emisores contra un presupuesto de 32 voces fisicas. 168 quedan
## virtuales y el voice stealing decide cuales cada frame. Todo lo demas de la escena
## existe para poner esa cifra bajo presion.
##
## El ambiente va a un bus propio y EL TRUENO VA A MASTER. Es la leccion de la Fase 3:
## si el trueno sonara en el bus medido, su propia energia tapria el ducking que se
## quiere demostrar.

const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const PlayerControllerClass = preload("res://scenes/shared/player_controller.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const MonsoonTelemetryClass = preload("res://scenes/demos/monsoon/monsoon_telemetry.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")
const OpenDouSplineEmitter3DClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
const OpenDouGranularEmitter3DClass = preload("res://addons/opendou/nodes/opendou_granular_emitter_3d.gd")
const OpenDouAudibleMonitorClass = preload("res://addons/opendou/nodes/opendou_audible_monitor.gd")

## Bus del campo de emisores posteados: lluvia, viento, ranas y goteo.
const AMBIENCE_BUS: StringName = &"MonsoonAmbience"

## Bus de los tres emisores geometricos: canal, linea de arboles y enjambre.
##
## Van a un bus APARTE, y no es cosmetico. Esos tres son nodos nativos con autoplay:
## suenan por su cuenta, fuera del pool de voces, asi que el HDR no los alcanza -solo
## atenua las voces que pasan por PhysicalVoiceChannel.apply()-. Mezclados con el campo
## posteado taparian su ducking al medirlo, y de paso ocultarian esa limitacion real del
## motor a quien lea la escena.
const NATURE_BUS: StringName = &"MonsoonNature"

## Las tres superficies sobre las que cae la lluvia. Las tres del vocabulario.
const TERRACE_SURFACES: Array[StringName] = [&"Water", &"Stone", &"Foliage"]

const TERRACE_SIZE: Vector3 = Vector3(40.0, 1.0, 24.0)
const TERRACE_STEP: Vector3 = Vector3(0.0, -2.0, 26.0)

## Cuantos emisores de ambiente se postean.
@export var emitter_count: int = 200

## Cuantas voces fisicas puede haber a la vez. El resto se virtualiza.
@export var physical_voice_budget: int = 32

## Duracion del trueno en segundos. Es un export para que los tests puedan acortarlo:
## en headless el bucle corre a maxima velocidad y esperar cuatro segundos de tiempo
## logico cuesta decenas de miles de frames.
@export var thunder_seconds: float = 4.0

var event_manager = null
var telemetry: MonsoonTelemetry = null
var ambience_bus: StringName = AMBIENCE_BUS
var nature_bus: StringName = NATURE_BUS

var _thunder_def: AudioEventDef = null
var _ambience_defs: Array[AudioEventDef] = []
var _previous_voice_budget: int = -1
var _built: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	build()

## Construye la escena. Idempotente.
func build() -> void:
	if _built:
		return
	_built = true
	# Semilla fija: la escena tiene que sonar y medirse igual en cada arranque.
	_rng.seed = 20260901

	ambience_bus = DemoAudioClass.ensure_bus(AMBIENCE_BUS)
	nature_bus = DemoAudioClass.ensure_bus(NATURE_BUS)

	# El manager es el AUTOLOAD, no una copia: es el mismo que resuelven los emisores
	# del rig en _get_manager(). Dos managers dejarian el estado partido en dos.
	event_manager = DemoAudioClass.manager(self)
	if event_manager == null:
		push_error("[MonsoonDemo] no hay autoload OpenDou: la escena no puede sonar")
		return
	_previous_voice_budget = event_manager.voice_pool.max_physical_voices
	event_manager.set_max_physical_voices(physical_voice_budget)
	FootstepEventsClass.register(event_manager)

	_build_terraces()
	_build_ambience_defs()
	_build_thunder_def()
	_build_emitter_field()
	_build_canal()
	_build_treeline()
	_build_swarm()
	_build_player()
	_build_overlays()

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-70.0, 140.0, 0.0)
	light.light_energy = 0.15
	light.light_color = Color(0.6, 0.68, 0.85)
	add_child(light)

func _build_terraces() -> void:
	for i in range(TERRACE_SURFACES.size()):
		var pos: Vector3 = TERRACE_STEP * float(i) + Vector3(0.0, -0.5, 0.0)
		add_child(SurfacePatchClass.make(TERRACE_SURFACES[i], TERRACE_SIZE, pos))

## Cuatro fuentes de ambiente con prioridades distintas.
##
## Las prioridades importan: el voice stealing ordena por peso, que combina prioridad y
## distancia. Con todas iguales, el reparto seria solo por distancia y la escena no
## demostraria el criterio compuesto.
func _build_ambience_defs() -> void:
	var specs: Array[Dictionary] = [
		{"name": &"RainPatter", "priority": 35.0, "loudness": -14.0,
			"stream": AudioSynthesizerClass.create_rain_ambient_loop(3.0)},
		{"name": &"CanopyWind", "priority": 30.0, "loudness": -18.0,
			"stream": AudioSynthesizerClass.create_canopy_wind_loop(4.0)},
		{"name": &"FrogCroak", "priority": 22.0, "loudness": -20.0,
			"stream": AudioSynthesizerClass.create_frog_croak(1.2)},
		# create_water_droplet toma PITCH en Hz, no duracion.
		{"name": &"WaterDroplet", "priority": 18.0, "loudness": -24.0,
			"stream": AudioSynthesizerClass.create_water_droplet(1200.0)},
	]
	for spec in specs:
		var stream: AudioStream = spec["stream"]
		var def = AudioEventDefClass.new(spec["name"], stream)
		def.is_looping = true
		def.stream_length = float(stream.get_length())
		def.base_priority = spec["priority"]
		def.base_volume_db = -8.0
		def.hdr_loudness_db = spec["loudness"]
		def.target_bus = ambience_bus
		# max_instances no lo hace cumplir nadie en el motor: se declara con el valor
		# honesto, no con el que haria falta para que funcionara.
		def.max_instances = emitter_count
		event_manager.register_event_definition(def)
		_ambience_defs.append(def)

## El trueno. A Master, NO al bus de ambiente.
func _build_thunder_def() -> void:
	var stream := AudioSynthesizerClass.create_thunder_rumble(thunder_seconds)
	_thunder_def = AudioEventDefClass.new(&"Thunder", stream)
	_thunder_def.is_looping = false
	_thunder_def.stream_length = float(stream.get_length())
	_thunder_def.base_priority = 95.0
	_thunder_def.base_volume_db = 0.0
	# +18 dB de sonoridad de diseno: es lo que empuja la ventana HDR hacia arriba y
	# hunde todo lo demas sin que nadie programe un ducking.
	_thunder_def.hdr_loudness_db = 18.0
	_thunder_def.target_bus = &"Master"
	event_manager.register_event_definition(_thunder_def)

## Postea el campo de emisores repartido sobre las tres terrazas.
func _build_emitter_field() -> void:
	var half := Vector3(TERRACE_SIZE.x * 0.5, 0.0, TERRACE_SIZE.z * 0.5)
	for i in range(emitter_count):
		var def: AudioEventDef = _ambience_defs[i % _ambience_defs.size()]
		var terrace: int = i % TERRACE_SURFACES.size()
		var base: Vector3 = TERRACE_STEP * float(terrace)
		var pos := base + Vector3(
			_rng.randf_range(-half.x, half.x),
			_rng.randf_range(0.2, 6.0),
			_rng.randf_range(-half.z, half.z)
		)
		# caller = null a proposito. Con un caller, update_parameters() sobreescribe
		# emitter_position con la posicion del nodo CADA frame, asi que los 200
		# emisores colapsarian en el origen de la escena y el voice stealing por
		# distancia no tendria nada que decidir.
		var instance = event_manager.post_event(def, null)
		if instance != null:
			instance.set_position(pos)

## El canal de riego: un objeto grande, no un punto.
func _build_canal() -> void:
	var canal = OpenDouMultiPositionEmitter3DClass.new()
	canal.name = "IrrigationCanal"
	canal.stream = AudioSynthesizerClass.create_water_stream_ambient_loop(4.0)
	canal.bus = String(nature_bus)
	canal.unit_size = 12.0
	canal.rendering_mode = OpenDouMultiPositionEmitter3DClass.RenderingMode.CLOSEST_POINT_TRACKING
	canal.cull_distance = 90.0
	# Local TIPADO: emission_points es Array[Vector3] y un literal sin tipar aborta.
	var points: Array[Vector3] = []
	for i in range(13):
		var t: float = float(i) / 12.0
		points.append(Vector3(-20.0 + t * 40.0, 0.4, 12.0 + sin(t * TAU) * 2.0))
	canal.emission_points = points
	# autoplay es una propiedad de AudioStreamPlayer3D, no una llamada a play().
	canal.autoplay = true
	add_child(canal)

## El viento en la linea de arboles: una fuente lineal con absorcion de aire y doppler.
func _build_treeline() -> void:
	var treeline = OpenDouSplineEmitter3DClass.new()
	treeline.name = "Treeline"
	treeline.stream = AudioSynthesizerClass.create_canopy_wind_loop(4.0)
	treeline.bus = String(nature_bus)
	treeline.unit_size = 14.0
	treeline.enable_air_absorption = true
	treeline.enable_doppler = true
	treeline.max_virtual_distance = 120.0

	var curve := Curve3D.new()
	# La curva NO pasa por el origen del nodo: si el punto mas cercano coincidiera con
	# la posicion del nodo, el emisor no se moveria.
	for i in range(7):
		var t: float = float(i) / 6.0
		curve.add_point(Vector3(-24.0 + t * 48.0, 6.0, -14.0 - sin(t * PI) * 6.0))
	treeline.curve = curve
	treeline.autoplay = true
	add_child(treeline)

## El enjambre de cigarras: granular sobre una textura sintetizada.
func _build_swarm() -> void:
	var swarm = OpenDouGranularEmitter3DClass.new()
	swarm.name = "CicadaSwarm"
	swarm.source_stream = AudioSynthesizerClass.create_cicada_swarm_loop(2.0)
	swarm.bus = String(nature_bus)
	swarm.unit_size = 10.0
	swarm.grain_size_ms = 35.0
	swarm.grain_rate_hz = 60.0
	swarm.position_jitter_ms = 25.0
	swarm.pitch_jitter_semitones = 4.0
	swarm.max_concurrent_grains = 24
	swarm.auto_play_emitter = true
	swarm.position = Vector3(10.0, 4.0, -8.0)
	add_child(swarm)

func _build_player() -> void:
	var player = PlayerControllerClass.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)

func _build_overlays() -> void:
	telemetry = MonsoonTelemetryClass.new()
	telemetry.name = "Telemetry"
	add_child(telemetry)
	telemetry.bind_demo(self)

	var monitor = OpenDouAudibleMonitorClass.new()
	monitor.name = "AudibleMonitor"
	monitor.enabled = true
	monitor.max_items_displayed = 8
	add_child(monitor)

## Lanza un trueno. Sube la ventana HDR y hunde el ambiente.
func strike_thunder() -> void:
	if event_manager == null or _thunder_def == null:
		return
	# Igual que el campo: sin caller, para que la posicion del rayo se quede donde se
	# pone y no en el origen de la escena.
	var instance = event_manager.post_event(_thunder_def, null)
	if instance != null:
		instance.set_position(Vector3(_rng.randf_range(-30.0, 30.0), 30.0, -40.0))

## Lo que el pool esta decidiendo ahora mismo.
func get_telemetry() -> Dictionary:
	if event_manager == null or event_manager.voice_pool == null:
		return {}
	var pool = event_manager.voice_pool
	var scheduler = event_manager.occlusion_scheduler
	var hdr = event_manager.hdr_engine
	return {
		"instances": event_manager.active_instances.size(),
		"physical": pool.get_active_physical_count(),
		"virtual": pool.get_active_virtual_count(event_manager.active_instances),
		"budget": pool.max_physical_voices,
		"raycasts": scheduler.raycasts_this_frame if scheduler != null else 0,
		"raycast_budget": scheduler.raycasts_per_frame if scheduler != null else 0,
		"hdr_top_db": hdr.hdr_window_top_db if hdr != null else 0.0,
	}

## Devuelve el pool a como estaba y retira las instancias de esta escena.
##
## El autoload sobrevive al cambio de escena: sin esto, volver al hub y abrir otra demo
## la dejaria con 32 voces y 200 instancias de lluvia que ya no tienen escena.
func _exit_tree() -> void:
	if event_manager == null:
		return
	event_manager.stop_all()
	if _previous_voice_budget > 0:
		event_manager.set_max_physical_voices(_previous_voice_budget)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			strike_thunder()
