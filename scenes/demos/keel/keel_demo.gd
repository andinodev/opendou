class_name KeelDemo
extends Node3D

## «Bajo la quilla»: la acustica compone.
##
## Una valvula rota silba en la sala de maquinas y nunca se ve. Suena como cuatro cosas
## distintas segun donde estes y si la escotilla esta abierta: directa a traves de la
## escotilla, difractada al cerrarla, como cola de reverb desde el pasillo, y opaca al
## bajar a la bahia inundada.
##
## LA TESIS: es el MISMO emisor sin tocar. Nada en este script lo modifica despues de
## darle su definicion. Todo lo que cambia es geometria.
##
## LA ESCENA lleva los tres recintos con sus colisionadores, los suelos con su metadata,
## los mamparos, la escotilla, los reflectores, el area de parametro, el bake, el
## depurador, el emisor, los personajes, la luz y el cartel. Este script solo hace lo
## dinamico: autorar el evento -que no puede vivir en un .tscn porque su stream se
## sintetiza-, propagar la apertura de la escotilla, y las teclas.
## Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

## Bus de la valvula. Existe para poder MEDIRLA: en Master se mezcla con las pisadas y
## el resto, y la asercion de la escotilla no distinguiria su caida.
const VALVE_BUS: StringName = &"KeelValve"

## Apertura de la escotilla. Asignarla propaga al portal en runtime.
@export_range(0.0, 1.0, 0.01) var hatch_open_factor: float = 1.0:
	set(val):
		hatch_open_factor = clampf(val, 0.0, 1.0)
		if hatch != null:
			hatch.open_factor = hatch_open_factor

@onready var hatch: OpenDouPortal3D = $Hatch
@onready var valve_emitter: OpenDouEventPlayer3D = $BrokenValve
@onready var debugger: OpenDouAcousticDebugger3D = $AcousticDebugger

var event_manager = null
var valve_bus: StringName = VALVE_BUS

## Los recintos de la escena, por nombre. Se leen del arbol: la escena es la fuente de
## verdad, no una constante de este script.
var rooms: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is OpenDouRoom3D:
			rooms[child.room_name] = child

	event_manager = DemoAudioClass.manager(self)
	if event_manager != null:
		FootstepEventsClass.register(event_manager)
	_author_valve_event()

	# La escotilla arranca donde diga la escena.
	hatch.open_factor = hatch_open_factor

## Da a la valvula su definicion de evento.
##
## Es la unica excepcion legitima a componer en la escena: no hay assets de audio, el
## silbido se sintetiza en tiempo de ejecucion, y un AudioStream sintetizado no puede
## vivir en un .tscn. El NODO si esta en la escena, con su unit_size, su area_mask y su
## posicion puestos ahi.
func _author_valve_event() -> void:
	var hiss := AudioSynthesizerClass.create_server_ambient_loop(3.0)
	var def = AudioEventDefClass.new(&"BrokenValve", hiss)
	def.is_looping = true
	def.stream_length = float(hiss.get_length())
	def.base_volume_db = -6.0
	def.base_priority = 70.0
	def.hdr_loudness_db = -6.0
	valve_bus = DemoAudioClass.ensure_bus(VALVE_BUS)
	def.target_bus = valve_bus
	if event_manager != null:
		event_manager.register_event_definition(def)
	valve_emitter.event_def = def

	# Se arranca AQUI y no con auto_play_event en la escena. Los hijos hacen _ready antes
	# que el padre, asi que un auto_play habria disparado con event_def todavia en null y
	# la valvula no habria sonado nunca.
	valve_emitter.play_event()

## Alterna el depurador acustico. Devuelve su nuevo estado.
func toggle_debugger() -> bool:
	if debugger == null:
		return false
	debugger.enabled = not debugger.enabled
	return debugger.enabled

## Retira las instancias de esta escena del autoload, que sobrevive al cambio de escena.
func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			toggle_debugger()
		elif event.keycode == KEY_E:
			# Girar la rueda de la escotilla.
			hatch_open_factor = 0.0 if hatch_open_factor > 0.5 else 1.0
