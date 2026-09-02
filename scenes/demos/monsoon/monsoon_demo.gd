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
## si el trueno sonara en el bus medido, su propia energia taparia el ducking que se
## quiere demostrar.
##
## LA ESCENA lleva las tres terrazas con su metadata, el canal, la linea de arboles con
## su curva, el enjambre, el jugador, la telemetria, el monitor, la luz y el cartel. Este
## script solo hace lo dinamico: autorar los eventos -sus streams se sintetizan y no
## pueden vivir en un .tscn-, postear el campo de emisores, y las teclas.
## Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

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

## Reparto del campo de emisores. Tiene que coincidir con las terrazas de la escena.
const TERRACE_STEP: Vector3 = Vector3(0.0, -2.0, 26.0)
const TERRACE_SIZE: Vector3 = Vector3(40.0, 1.0, 24.0)
const TERRACE_COUNT: int = 3

## Cuantos emisores de ambiente se postean.
@export var emitter_count: int = 200

## Cuantas voces fisicas puede haber a la vez. El resto se virtualiza.
@export var physical_voice_budget: int = 32

## Duracion del trueno en segundos. Es un export para que los tests puedan acortarlo:
## en headless el bucle corre a maxima velocidad y esperar cuatro segundos de tiempo
## logico cuesta decenas de miles de frames.
@export var thunder_seconds: float = 4.0

@onready var telemetry: MonsoonTelemetry = $Telemetry

var event_manager = null
var ambience_bus: StringName = AMBIENCE_BUS
var nature_bus: StringName = NATURE_BUS

var _thunder_def: AudioEventDef = null
var _ambience_defs: Array[AudioEventDef] = []
var _previous_voice_budget: int = -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Semilla fija: la escena tiene que sonar y medirse igual en cada arranque.
	_rng.seed = 20260901

	ambience_bus = DemoAudioClass.ensure_bus(AMBIENCE_BUS)
	nature_bus = DemoAudioClass.ensure_bus(NATURE_BUS)
	_wire_geometric_emitters()

	# El manager es el AUTOLOAD, no una copia: es el mismo que resuelven los emisores
	# del rig en _get_manager(). Dos managers dejarian el estado partido en dos.
	event_manager = DemoAudioClass.manager(self)
	if event_manager == null:
		push_error("[MonsoonDemo] no hay autoload OpenDou: la escena no puede sonar")
		return
	_previous_voice_budget = event_manager.voice_pool.max_physical_voices
	event_manager.set_max_physical_voices(physical_voice_budget)
	FootstepEventsClass.register(event_manager)

	_build_ambience_defs()
	_build_thunder_def()
	_build_emitter_field()
	telemetry.bind_demo(self)

## Da su stream y su bus a los tres emisores que la escena ya declara.
##
## El bus se asigna aqui y no en el .tscn porque no existe hasta que alguien lo crea, y
## un bus inexistente en una escena produce un error del motor al cargarla. Los streams,
## porque se sintetizan.
func _wire_geometric_emitters() -> void:
	var canal: OpenDouMultiPositionEmitter3D = $IrrigationCanal
	canal.bus = String(nature_bus)
	canal.stream = AudioSynthesizerClass.create_water_stream_ambient_loop(4.0)

	var treeline: OpenDouSplineEmitter3D = $Treeline
	treeline.bus = String(nature_bus)
	treeline.stream = AudioSynthesizerClass.create_canopy_wind_loop(4.0)

	var swarm: OpenDouGranularEmitter3D = $CicadaSwarm
	swarm.bus = String(nature_bus)
	swarm.source_stream = AudioSynthesizerClass.create_cicada_swarm_loop(2.0)

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
		# create_water_droplet toma PITCH en Hz, no duracion: 0.8 daria 0.8 Hz.
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
		var terrace: int = i % TERRACE_COUNT
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
