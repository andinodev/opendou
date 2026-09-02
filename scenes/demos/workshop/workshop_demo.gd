class_name WorkshopDemo
extends Node3D

## «El taller»: los objetos suenan solos.
##
## Una lata, una caja y una llave caen de la repisa sobre una mesa metalica y el suelo de
## hormigon y suenan segun con que chocan y a que velocidad; el mecanico saluda al
## acercarse, con subtitulo y boca; la radio del taller es un altavoz de verdad: lo que
## suena en el bus Radio sale de una caja en la pared, con directividad; el motor es un
## contenedor por RPM y carga; la lona del fondo suena desde su punto mas cercano.
##
## LA ESCENA lleva todo eso como nodos. Este script autora los streams (se sintetizan),
## suelta la repisa, mueve RPM y carga con las teclas y convierte el disparo del area en
## la linea del mecanico. Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const VehicleEngineEventsClass = preload("res://scenes/shared/vehicle_engine_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const TableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")

const RADIO_BUS: StringName = &"Radio"
const ENGINE_BUS: StringName = &"Engine"

@onready var engine: OpenDouEventPlayer3D = $Engine
@onready var radio_source: OpenDouEventPlayer = $RadioSource
@onready var radio_speaker: OpenDouEventPlayer3D = $RadioSpeaker
@onready var tarp: OpenDouMultiPositionEmitter3D = $Tarp
@onready var greet_zone: OpenDouParameterArea3D = $GreetZone
@onready var mechanic_voice: OpenDouDialogueEmitter3D = $Mechanic/Voice
@onready var debugger: OpenDouAcousticDebugger3D = $AcousticDebugger

var event_manager = null
var rpm: float = 900.0
var load_on: bool = false
var shelf_released: bool = false

func _ready() -> void:
	event_manager = DemoAudioClass.manager(self)
	DemoAudioClass.ensure_bus(RADIO_BUS)
	DemoAudioClass.ensure_bus(ENGINE_BUS)
	if event_manager != null:
		FootstepEventsClass.register(event_manager)
		_author_clank()
		_author_radio()
		_author_greeting()
		var engine_def = VehicleEngineEventsClass.register(event_manager)
		engine_def.target_bus = ENGINE_BUS
	greet_zone.triggered.connect(_on_greet_triggered)
	# La lona reproduce su propio stream: el emisor multiposicion no pasa por el evento.
	tarp.stream = AudioSynthesizerClass.create_canopy_wind_loop(3.0)
	tarp.volume_db = -14.0
	tarp.play()
	radio_source.play_event()
	radio_speaker.play_event()
	engine.play_event()
	_apply_engine_state()

## Impacto: switch Material -> tres ramas con variaciones.
func _author_clank() -> void:
	var sw = AudioSwitchContainerClass.new(&"Material", &"Concrete")
	for mat in [&"Concrete", &"Metal", &"Wood"]:
		var rnd = AudioRandomContainerClass.new()
		rnd.pitch_jitter_range = Vector2(-0.08, 0.08)
		for v in range(1, 4):
			rnd.add_child_node(AudioPhysicalNodeClass.new(AudioSynthesizerClass.create_footstep(mat, v)))
		sw.set_state_node(mat, rnd)
	var def = AudioEventDefClass.new(&"Clank")
	def.root_container = sw
	def.stream_length = 0.25
	def.base_volume_db = -2.0
	def.base_priority = 55.0
	event_manager.register_event_definition(def)

func _author_radio() -> void:
	var def = AudioEventDefClass.new(&"RadioMusic", AudioSynthesizerClass.create_music_pad_loop(2.0))
	def.is_looping = true
	def.stream_length = 2.0
	def.target_bus = RADIO_BUS
	def.base_volume_db = -6.0
	event_manager.register_event_definition(def)
	radio_source.event_name = &"RadioMusic"

func _author_greeting() -> void:
	var table = TableClass.new()
	table.add_entry(&"greet", "es", AudioSynthesizerClass.create_tone(180.0, 1.2, 0.4, true))
	mechanic_voice.dialogue_table = table
	var def = AudioEventDefClass.new(&"MechanicGreets", AudioSynthesizerClass.create_tone(880.0, 0.15, 0.3, true))
	def.stream_length = 0.15
	event_manager.register_event_definition(def)

func _on_greet_triggered(_event: StringName, _target: Node3D) -> void:
	if not mechanic_voice.is_speaking():
		mechanic_voice.speak(&"greet")

## Suelta los tres objetos de la repisa.
func release_shelf() -> void:
	shelf_released = true
	for n in [$Can, $Crate, $Wrench]:
		n.freeze = false

func set_rpm(value: float) -> void:
	rpm = clampf(value, VehicleEngineEventsClass.RPM_MIN, VehicleEngineEventsClass.RPM_MAX)
	_apply_engine_state()

func toggle_load() -> void:
	load_on = not load_on
	_apply_engine_state()

func _apply_engine_state() -> void:
	engine.set_rtpc(VehicleEngineEventsClass.RPM_RTPC, rpm)
	engine.set_switch(VehicleEngineEventsClass.LOAD_SWITCH, &"Load" if load_on else &"Idle")

func toggle_debugger() -> bool:
	debugger.enabled = not debugger.enabled
	return debugger.enabled

## Retira las instancias de esta escena del autoload, que sobrevive al cambio de escena.
func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: release_shelf()
			KEY_UP: set_rpm(rpm + 400.0)
			KEY_DOWN: set_rpm(rpm - 400.0)
			KEY_SPACE: toggle_load()
			KEY_F9: toggle_debugger()
