class_name KeelDemo
extends Node3D

## «Bajo la quilla»: la acustica compone.
##
## Una valvula rota silba en la sala de maquinas y nunca se ve. Suena como cuatro cosas
## distintas segun donde estes y si la escotilla esta abierta: directa a traves de la
## escotilla, difractada al cerrarla, como cola de reverb desde el pasillo, y opaca al
## bajar a la bahia inundada.
##
## LA TESIS: es el MISMO emisor sin tocar. Se crea una vez en _build_valve() y nada
## vuelve a modificarlo. Todo lo que cambia es geometria.

const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const PlayerControllerClass = preload("res://scenes/shared/player_controller.gd")
const NpcControllerClass = preload("res://scenes/shared/npc_controller.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const OpenDouPortal3DClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")
const OpenDouReflector3DClass = preload("res://addons/opendou/nodes/opendou_reflector_3d.gd")
const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const OpenDouAcousticGeometryBakeClass = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const OpenDouAcousticDebugger3DClass = preload("res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

## Definicion de los tres recintos: centro, tamano, perfil acustico y suelo.
const ROOM_SPECS: Array[Dictionary] = [
	{"name": &"EngineRoom", "center": Vector3(0, 2, 0), "size": Vector3(12, 5, 12),
		"preset": "Metal", "floor": &"Metal"},
	{"name": &"Corridor", "center": Vector3(14, 2, 0), "size": Vector3(14, 4, 4),
		"preset": "Concrete", "floor": &"Concrete"},
	{"name": &"FloodedBay", "center": Vector3(28, 1, 0), "size": Vector3(12, 4, 12),
		"preset": "Water", "floor": &"Water"},
]

## Mamparos: centro y tamano. Su malla va al grupo AcousticObstacle para el bake.
const BULKHEAD_SPECS: Array[Dictionary] = [
	{"center": Vector3(6.5, 2, 0), "size": Vector3(1, 5, 12)},
	{"center": Vector3(21.5, 2, 0), "size": Vector3(1, 4, 12)},
]

## Bus de la valvula. Existe para poder MEDIRLA: en Master se mezcla con las pisadas y
## el resto, y la asercion de la escotilla no distinguiria su caida.
const VALVE_BUS: StringName = &"KeelValve"

## Apertura de la escotilla. Asignarla propaga al portal en runtime.
@export_range(0.0, 1.0, 0.01) var hatch_open_factor: float = 1.0:
	set(val):
		hatch_open_factor = clampf(val, 0.0, 1.0)
		if hatch != null:
			hatch.open_factor = hatch_open_factor

var rooms: Dictionary = {}
var hatch: OpenDouPortal3D = null
var valve_emitter: OpenDouEventPlayer3D = null
var valve_bus: StringName = VALVE_BUS
var debugger: OpenDouAcousticDebugger3D = null
var event_manager = null

var _built: bool = false

func _ready() -> void:
	build()

## Construye la escena. Idempotente.
func build() -> void:
	if _built:
		return
	_built = true

	event_manager = DemoAudioClass.manager(self)
	if event_manager != null:
		FootstepEventsClass.register(event_manager)

	_build_rooms()
	_build_bulkheads()
	_build_hatch()
	_build_reflectors()
	_build_water_area()
	_build_bake()
	_build_valve()
	_build_characters()
	_build_debugger()

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60.0, 25.0, 0.0)
	light.light_energy = 0.4
	add_child(light)

func _build_rooms() -> void:
	for spec in ROOM_SPECS:
		var room = OpenDouRoom3DClass.new()
		room.name = str(spec["name"])
		room.room_name = spec["name"]
		room.material_preset = spec["preset"]
		room.floor_surface = spec["floor"]
		room.position = spec["center"]
		room.reverb_send_amount = 0.8
		room.reverb_uniformity = 0.6

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec["size"]
		shape.shape = box
		room.add_child(shape)
		add_child(room)
		rooms[spec["name"]] = room

		# Suelo con su metadata, para que las pisadas cambien de timbre por recinto.
		var floor_size := Vector3(spec["size"].x, 1.0, spec["size"].z)
		var floor_pos: Vector3 = spec["center"] - Vector3(0, spec["size"].y * 0.5 + 0.5, 0)
		add_child(SurfacePatchClass.make(spec["floor"], floor_size, floor_pos))

func _build_bulkheads() -> void:
	for i in range(BULKHEAD_SPECS.size()):
		var spec: Dictionary = BULKHEAD_SPECS[i]
		var body = SurfacePatchClass.make(&"Metal", spec["size"], spec["center"])
		body.name = "Bulkhead_%d" % i
		# El grupo va en la malla hija, no en el cuerpo: ver mark_as_acoustic_obstacle().
		SurfacePatchClass.mark_as_acoustic_obstacle(body)
		add_child(body)

func _build_hatch() -> void:
	hatch = OpenDouPortal3DClass.new()
	hatch.name = "Hatch"
	hatch.portal_name = &"EngineHatch"
	hatch.room_a_name = &"EngineRoom"
	hatch.room_b_name = &"Corridor"
	# Escotilla estrecha: 1.4 x 2.0 m, asi que su difraccion se nota incluso abierta.
	hatch.portal_size = Vector2(1.4, 2.0)
	hatch.position = Vector3(6.5, 1.5, 0.0)
	add_child(hatch)
	hatch.open_factor = hatch_open_factor

func _build_reflectors() -> void:
	for i in range(BULKHEAD_SPECS.size()):
		var reflector = OpenDouReflector3DClass.new()
		reflector.name = "Reflector_%d" % i
		reflector.reflector_name = StringName("Bulkhead_%d" % i)
		# Metal: muy reflectante.
		reflector.absorption = 0.05
		reflector.plane_normal = Vector3.LEFT if i == 0 else Vector3.RIGHT
		reflector.position = BULKHEAD_SPECS[i]["center"]
		add_child(reflector)

func _build_water_area() -> void:
	var area = OpenDouParameterArea3DClass.new()
	area.name = "WaterDepth"
	area.parameter_name = &"WaterDepth"
	area.min_value = 0.0
	area.max_value = 1.0
	area.fade_in_time = 0.4
	area.fade_out_time = 0.9
	area.position = ROOM_SPECS[2]["center"]

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ROOM_SPECS[2]["size"]
	shape.shape = box
	area.add_child(shape)
	add_child(area)

func _build_bake() -> void:
	var bake = OpenDouAcousticGeometryBakeClass.new()
	bake.name = "AcousticBake"
	bake.target_group = &"AcousticObstacle"
	bake.auto_bake_on_ready = true
	add_child(bake)

## La valvula: se crea UNA vez y nada vuelve a tocarla. Es la tesis de la demo.
func _build_valve() -> void:
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

	valve_emitter = OpenDouEventPlayer3DClass.new()
	valve_emitter.name = "BrokenValve"
	valve_emitter.event_def = def
	valve_emitter.auto_play_event = true
	valve_emitter.unit_size = 8.0
	valve_emitter.area_mask = 1
	valve_emitter.enable_dynamic_occlusion = true
	valve_emitter.enable_early_reflections = true
	# Al fondo de la sala de maquinas, fuera de la vista desde el pasillo.
	valve_emitter.position = Vector3(-4.0, 1.2, -4.0)
	add_child(valve_emitter)

func _build_characters() -> void:
	var player = PlayerControllerClass.new()
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 3.0)
	add_child(player)

	# Un NPC que cruza la escotilla: sus pisadas se oyen difractadas al cerrarla.
	var npc = NpcControllerClass.new()
	npc.name = "Crewman"
	npc.position = Vector3(2.0, 1.0, 0.0)
	# Local TIPADO: waypoints es Array[Vector3] y un literal sin tipar aborta.
	var route: Array[Vector3] = [
		Vector3(2.0, 1.0, 0.0),
		Vector3(14.0, 1.0, 0.0),
		Vector3(2.0, 1.0, 0.0),
	]
	npc.waypoints = route
	add_child(npc)

func _build_debugger() -> void:
	debugger = OpenDouAcousticDebugger3DClass.new()
	debugger.name = "AcousticDebugger"
	debugger.enabled = false
	debugger.display_mode = 2
	add_child(debugger)

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
