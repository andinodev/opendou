class_name StreetDemo
extends Node3D

## «Una casa canta»: una casa vibra, dos duermen, y la calle es el puente.
##
## Dos edificios de ladrillo hombro con hombro, compartiendo la medianera; enfrente, una
## casa de tres pisos con sus balcones de hierro. La primera casa tiene musica; las otras
## dos, un silencio que no es ausencia de sonido sino la calle amortiguada por ventanas
## cerradas.
##
## LA TESIS: la musica SALE por la ventana entreabierta -filtrada, atenuada y viniendo de
## la ventana-, el coche reverbera entre las tres fachadas, y al entrar en una casa
## dormida la calle se apaga a 300 Hz. Es la escena que junta lo que las otras tres
## demuestran por separado, y la primera que luce el grafo de salas de la Fase 6.
##
## LA ESCENA -250 nodos- lleva cada pared, suelo, techo, cristal, puerta con hoja,
## balcon, sala, portal, reflector, emisor, luz y el cartel. Este script hace solo lo
## dinamico: autorar los eventos -sus streams se sintetizan-, postear las hojas, mover el
## coche, el reloj del barrio, y la tecla E.
## Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")

## Bus de la calle (hojas, perro, farola, coche, brisa) y bus de la casa que canta. Dos
## buses para poder MEDIR cada mitad de la tesis por separado.
const STREET_BUS: StringName = &"StreetAmbience"
const MUSIC_BUS: StringName = &"HouseAMusic"

## Cuantas hojas arrastradas se postean por las aceras.
@export var leaves_count: int = 30

## Velocidad del coche, en m/s. Recorre la calle de un extremo al otro y vuelve.
@export var car_speed: float = 8.0

## Ventana de la casa A: apertura entreabierta y abierta del todo.
const WINDOW_AJAR: float = 0.15
const WINDOW_OPEN: float = 0.85

## Alcance de la tecla E, en metros.
const REACH: float = 2.5

@onready var music_emitter: OpenDouEventPlayer3D = $HouseA_Music
@onready var bass_emitter: OpenDouEventPlayer3D = $HouseA_Bass
@onready var buzz_emitter: OpenDouEventPlayer3D = $Streetlight_Buzz
@onready var car: Node3D = $Car
@onready var car_engine: OpenDouEventPlayer3D = $Car/Engine
@onready var wind: OpenDouSplineEmitter3D = $Wind
@onready var window_a: OpenDouPortal3D = $A_WindowPortal
@onready var window_a_pane: StaticBody3D = $A_WindowPane
@onready var debugger: OpenDouAcousticDebugger3D = $AcousticDebugger
@onready var player = $Player

var event_manager = null
var street_bus: StringName = STREET_BUS
var music_bus: StringName = MUSIC_BUS
var window_a_open: bool = false

var _bark_def: AudioEventDef = null
var _spark_def: AudioEventDef = null
var _car_direction: float = 1.0
var _rng := RandomNumberGenerator.new()
var _doors: Array = []

func _ready() -> void:
	_rng.seed = 20260901
	street_bus = DemoAudioClass.ensure_bus(STREET_BUS)
	music_bus = DemoAudioClass.ensure_bus(MUSIC_BUS)
	wind.bus = String(street_bus)
	wind.stream = AudioSynthesizerClass.create_canopy_wind_loop(4.0)

	event_manager = DemoAudioClass.manager(self)
	if event_manager == null:
		push_error("[StreetDemo] no hay autoload OpenDou: la escena no puede sonar")
		return
	FootstepEventsClass.register(event_manager)

	for child in get_children():
		if child is StreetDoor:
			_doors.append(child)

	_author_music()
	_author_street()
	_scatter_leaves()
	$StreetClock.timeout.connect(_on_street_clock)
	window_a.open_factor = WINDOW_AJAR

## La musica de la casa A: percusion y bajo, dos emisores dentro de la sala.
##
## Espacial a proposito, y no un OpenDouMusicPlayer: es lo que permite que SALGA por la
## ventana. Un reproductor de musica no espacial no puede atravesar un portal.
func _author_music() -> void:
	var drums := AudioSynthesizerClass.create_music_drums_loop(2.0)
	var drums_def = AudioEventDefClass.new(&"HouseA_Drums", drums)
	drums_def.is_looping = true
	drums_def.stream_length = float(drums.get_length())
	drums_def.base_volume_db = -2.0
	drums_def.base_priority = 80.0
	drums_def.hdr_loudness_db = 0.0
	drums_def.target_bus = music_bus
	event_manager.register_event_definition(drums_def)
	music_emitter.event_def = drums_def
	music_emitter.play_event()

	var bass := AudioSynthesizerClass.create_music_bass_loop(2.0)
	var bass_def = AudioEventDefClass.new(&"HouseA_Bass", bass)
	bass_def.is_looping = true
	bass_def.stream_length = float(bass.get_length())
	bass_def.base_volume_db = -2.0
	bass_def.base_priority = 80.0
	bass_def.hdr_loudness_db = -2.0
	bass_def.target_bus = music_bus
	event_manager.register_event_definition(bass_def)
	bass_emitter.event_def = bass_def
	bass_emitter.play_event()

## Los ruidos de la calle: farola, coche, perro y chispazos.
func _author_street() -> void:
	# La farola: un zumbido de red electrica. create_tone no pone loop_mode y un evento
	# en bucle con un WAV que no loopea muere tras una pasada (observacion 37).
	var hum := AudioSynthesizerClass.create_tone(120.0, 2.0, 0.35, false)
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_begin = 0
	hum.loop_end = hum.data.size() / 2
	var hum_def = AudioEventDefClass.new(&"Streetlight_Hum", hum)
	hum_def.is_looping = true
	hum_def.stream_length = 2.0
	hum_def.base_volume_db = -12.0
	hum_def.base_priority = 30.0
	hum_def.hdr_loudness_db = -20.0
	hum_def.target_bus = street_bus
	event_manager.register_event_definition(hum_def)
	buzz_emitter.event_def = hum_def
	buzz_emitter.play_event()

	# El coche: un motor en bucle sobre un nodo que se mueve.
	var engine := AudioSynthesizerClass.create_engine_loop(70.0, 1.0)
	var engine_def = AudioEventDefClass.new(&"Car_Engine", engine)
	engine_def.is_looping = true
	engine_def.stream_length = float(engine.get_length())
	engine_def.base_volume_db = -4.0
	engine_def.base_priority = 60.0
	engine_def.hdr_loudness_db = -9.0
	engine_def.target_bus = street_bus
	event_manager.register_event_definition(engine_def)
	car_engine.event_def = engine_def
	car_engine.play_event()

	# El perro: tres ladridos distintos en un random container.
	var barks = AudioRandomContainerClass.new()
	barks.use_shuffle = true
	barks.pitch_jitter_range = Vector2(-0.08, 0.08)
	for v in range(3):
		barks.add_child_node(AudioPhysicalNodeClass.new(_make_bark(v)))
	_bark_def = AudioEventDefClass.new(&"Dog_Bark")
	_bark_def.root_container = barks
	_bark_def.is_looping = false
	_bark_def.stream_length = 0.35
	_bark_def.base_volume_db = -3.0
	_bark_def.base_priority = 55.0
	_bark_def.hdr_loudness_db = -4.0
	_bark_def.target_bus = street_bus
	event_manager.register_event_definition(_bark_def)

	## Los chispazos de la farola: tres estallidos cortos de ruido.
	#var sparks = AudioRandomContainerClass.new()
	#sparks.use_shuffle = true
	#for v in range(3):
		#sparks.add_child_node(AudioPhysicalNodeClass.new(_make_spark(v)))
	#_spark_def = AudioEventDefClass.new(&"Streetlight_Spark")
	#_spark_def.root_container = sparks
	#_spark_def.is_looping = false
	#_spark_def.stream_length = 0.08
	#_spark_def.base_volume_db = -6.0
	#_spark_def.base_priority = 40.0
	#_spark_def.hdr_loudness_db = -10.0
	#_spark_def.target_bus = street_bus
	#event_manager.register_event_definition(_spark_def)

## Un ladrido: diente de sierra que cae de tono con envolvente seca.
func _make_bark(variation: int) -> AudioStreamWAV:
	return ModularSynthEngineClass.synthesize_wav({
		"type": "Single_Generator",
		"generator_type": "Basic_Wave",
		"wave_type": "Saw",
		"duration": 0.32,
		"base_freq": 380.0 - 40.0 * float(variation),
		"pitch_envelope": {"amount_st": - 9.0, "decay": 0.22},
		"envelope": {"attack": 0.01, "decay": 0.12, "sustain": 0.35, "release": 0.08},
		"filter": {"type": "LowPass", "cutoff_hz": 2200.0, "resonance_q": 1.2},
		"drive": {"type": "Foldback", "amount": 1.4},
		"gain_db": - 6.0,
	}, 7300 + variation)

## Un chispazo: ruido blanco brevisimo con caida instantanea.
func _make_spark(variation: int) -> AudioStreamWAV:
	return ModularSynthEngineClass.synthesize_wav({
		"type": "Single_Generator",
		"generator_type": "Filtered_Noise",
		"noise_type": "White",
		"duration": 0.06 + 0.015 * float(variation),
		"filter": {"type": "HighPass", "cutoff_hz": 3500.0, "resonance_q": 1.0},
		"envelope": {"attack": 0.001, "decay": 0.03, "sustain": 0.1, "release": 0.02},
		"gain_db": - 8.0,
	}, 8800 + variation)

## Hojas secas arrastrandose por las aceras: un campo de instancias posteadas.
func _scatter_leaves() -> void:
	var rustle := ModularSynthEngineClass.synthesize_wav({
		"type": "Single_Generator",
		"generator_type": "Filtered_Noise",
		"noise_type": "Pink",
		"duration": 2.5,
		"filter": {"type": "BandPass", "cutoff_hz": 2800.0, "resonance_q": 1.6},
		"lfo": {"depth": 0.7, "rate_hz": 0.9, "wave": "Sine", "target": "Amplitude"},
		"gain_db": - 14.0,
		"loop_mode": true,
	}, 5100)
	rustle.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rustle.loop_begin = 0
	rustle.loop_end = rustle.data.size() / 2
	var def = AudioEventDefClass.new(&"Leaves_Rustle", rustle)
	def.is_looping = true
	def.stream_length = 2.5
	def.base_volume_db = -10.0
	def.base_priority = 20.0
	def.hdr_loudness_db = -24.0
	def.target_bus = street_bus
	def.max_instances = leaves_count
	event_manager.register_event_definition(def)

	for i in range(leaves_count):
		var side: float = -4.0 if i % 2 == 0 else 4.0
		var pos := Vector3(_rng.randf_range(-13.0, 9.0), 0.15, side + _rng.randf_range(-0.8, 0.8))
		# caller = null: con un caller, la posicion la manda el nodo cada frame.
		var inst = event_manager.post_event(def, null)
		if inst != null:
			inst.set_position(pos)

## El coche recorre la calle y vuelve. En physics para que el doppler nativo lo vea.
func _physics_process(delta: float) -> void:
	var x: float = car.position.x + _car_direction * car_speed * delta
	if x > 9.0:
		x = 9.0
		_car_direction = -1.0
	elif x < -13.0:
		x = -13.0
		_car_direction = 1.0
	car.position.x = x
	car.rotation.y = 0.0 if _car_direction > 0.0 else PI

## El reloj del barrio: un ladrido a veces, un chispazo casi siempre.
func _on_street_clock() -> void:
	if event_manager == null:
		return
	if _rng.randf() < 0.45 and _bark_def != null:
		var bark = event_manager.post_event(_bark_def, null)
		if bark != null:
			bark.set_position(Vector3(_rng.randf_range(-12.0, 8.0), 0.4, _rng.randf_range(-4.5, 4.5)))
	if _rng.randf() < 0.7 and _spark_def != null:
		var spark = event_manager.post_event(_spark_def, null)
		if spark != null:
			spark.set_position(buzz_emitter.global_position)

## La ventana de la casa A: entreabierta o abierta del todo.
func toggle_window() -> void:
	window_a_open = not window_a_open
	window_a.open_factor = WINDOW_OPEN if window_a_open else WINDOW_AJAR
	# La hoja del cristal se desliza para que se VEA lo que se oye.
	window_a_pane.position.x = -4.7 if window_a_open else -4.1

## Lo mas cercano al jugador que se pueda abrir, dentro del alcance. Null si nada.
func nearest_interactable() -> Node3D:
	if player == null:
		return null
	var best: Node3D = null
	var best_d: float = REACH
	for d in _doors:
		var dist: float = d.global_position.distance_to(player.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	var wd: float = window_a.global_position.distance_to(player.global_position)
	if wd < best_d:
		best = window_a
	return best

func toggle_debugger() -> bool:
	if debugger == null:
		return false
	debugger.enabled = not debugger.enabled
	return debugger.enabled

func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F9:
		toggle_debugger()
	elif event.keycode == KEY_E:
		var target := nearest_interactable()
		if target is StreetDoor:
			target.toggle()
		elif target == window_a:
			toggle_window()
