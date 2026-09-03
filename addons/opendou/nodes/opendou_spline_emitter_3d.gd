@icon("res://addons/opendou/icons/icon_spline_emitter_3d.svg")
@tool
class_name OpenDouSplineEmitter3D
extends AudioStreamPlayer3D

## Continuous volumetric 3D spline audio emitter (for rivers, powerlines, wide barriers, and roads).
## Projects sound smoothly from the closest point along a Curve3D to the listener in real-time.

## 3D Curve geometry defining the continuous sound path.
@export var curve: Curve3D:
	set(val):
		curve = val
		update_configuration_warnings()

@export var spline_path: Curve3D:
	get: return curve
	set(val): curve = val

## Spread expansion curve over normalized distance (0.0 = far -> 0 deg, 1.0 = near -> 180 deg).
@export var sound_spread_curve: Curve

## Enables dynamic atmospheric air damping (loss of high frequencies over distance).
@export var enable_air_absorption: bool = true

## Enables stabilized Doppler frequency shift for moving listeners or emitters.
@export var enable_doppler: bool = true

## Maximum audible distance for distance culling and curve normalization.
@export var max_virtual_distance: float = 60.0

## Base pitch scale multiplier.
@export var base_pitch_scale: float = 1.0

## Velocidad del flujo a lo largo de la curva, en m/s (rios, cintas). Positiva en el sentido
## de la curva. Entra en el doppler: un rio que corre hacia el oyente sube el tono (Fase 9).
@export var flow_speed_mps: float = 0.0

## Physics collision mask for acoustic line-of-sight checks.
@export_flags_3d_physics var acoustic_collision_mask: int = 1

## Transform que define el espacio en el que vive la curva.
##
## Se captura en _ready() y NO sigue al nodo. El nodo se mueve como cabeza de
## reproduccion virtual, y si la curva se interpretara en su espacio vivo se
## moveria con el: bucle de realimentacion, y la curva entera derivando hacia el
## oyente frame a frame. Medido antes del arreglo: 96 m de deriva en 60 frames,
## pasandose de largo al oyente y acelerando.
var _curve_anchor: Transform3D = Transform3D()
var _anchor_captured: bool = false
var _virtual_target_pos: Vector3 = Vector3.ZERO
var _current_air_cutoff: float = 20000.0
var _prev_listener_pos: Vector3 = Vector3.ZERO
var _prev_emitter_pos: Vector3 = Vector3.ZERO

func _init() -> void:
	if sound_spread_curve == null:
		sound_spread_curve = Curve.new()
		sound_spread_curve.add_point(Vector2(0.0, 0.0))  # Far: 0 spread
		sound_spread_curve.add_point(Vector2(1.0, 1.0))  # Near: 180 deg spread

func _ready() -> void:
	reanchor()
	_virtual_target_pos = global_position
	_prev_emitter_pos = global_position

## Fija el espacio de la curva a la posicion actual del nodo.
##
## Llamalo cuando reubiques el emisor a proposito, por ejemplo un rio o una cinta
## transportadora montados sobre un vehiculo en marcha.
func reanchor() -> void:
	_curve_anchor = global_transform if is_inside_tree() else transform
	_anchor_captured = true

## Transform que define el espacio en el que vive la curva.
func get_curve_anchor() -> Transform3D:
	if not _anchor_captured:
		return global_transform if is_inside_tree() else transform
	return _curve_anchor

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if curve == null or curve.point_count < 2:
		warnings.append("OpenDouSplineEmitter3D requires a Curve3D with at least 2 points to project volumetric sound.")
	return warnings

## Calculates the closest 3D world coordinate along the spline relative to a given listener position.
func get_closest_virtual_point(listener_pos: Vector3) -> Vector3:
	if curve == null or curve.point_count < 2:
		return global_position if is_inside_tree() else position
	var anchor: Transform3D = get_curve_anchor()
	# El oyente se lleva al espacio del ANCLA, no al del nodo: el nodo se mueve
	# cada frame como cabeza de reproduccion, y usar su transform vivo arrastraria
	# la curva con el.
	var local_listener: Vector3 = anchor.affine_inverse() * listener_pos
	var closest_local: Vector3 = curve.get_closest_point(local_listener)
	return anchor * closest_local

## Velocidad del flujo en el punto de la curva mas cercano al oyente: tangente x velocidad.
func get_flow_velocity_at(listener_pos: Vector3) -> Vector3:
	if curve == null or curve.point_count < 2 or is_zero_approx(flow_speed_mps):
		return Vector3.ZERO
	var anchor: Transform3D = get_curve_anchor()
	var local_listener: Vector3 = anchor.affine_inverse() * listener_pos
	var offset: float = curve.get_closest_offset(local_listener)
	var sample: Transform3D = curve.sample_baked_with_rotation(offset, false, true)
	var tangent_local: Vector3 = -sample.basis.z
	return (anchor.basis * tangent_local).normalized() * flow_speed_mps

## Updates the virtual emitter transform, air absorption, and Doppler pitch based on listener state.
func update_spline_acoustics(listener_pos: Vector3, listener_vel: Vector3 = Vector3.ZERO, delta: float = 0.016) -> void:
	if curve == null or curve.point_count < 2:
		return
	
	# Distance Culling Check (Distance to closest point > max_distance + 10m skips heavy calculations)
	var closest_pt = get_closest_virtual_point(listener_pos)
	var dist_to_closest = closest_pt.distance_to(listener_pos)
	
	if dist_to_closest > (max_virtual_distance + 10.0):
		return
	
	_virtual_target_pos = closest_pt
	
	# El nodo se mueve como cabeza de reproduccion VISUAL (depurador, tests de anclaje). Desde
	# la Fase 15 no suena: la voz es del pool y toma la posicion de resolve_emitter_position();
	# doppler, aire y flujo los hace el sistema de voces.
	global_position = global_position.lerp(_virtual_target_pos, clampf(delta * 20.0, 0.0, 1.0))
	_prev_emitter_pos = global_position

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_provider_tick()
	
	# Retrieve active listener
	var viewport = get_viewport()
	if viewport != null:
		var camera = viewport.get_camera_3d()
		if camera != null:
			var listener_pos = camera.global_position
			var listener_vel = (listener_pos - _prev_listener_pos) / maxf(0.001, delta)
			_prev_listener_pos = listener_pos
			update_spline_acoustics(listener_pos, listener_vel, delta)

# ==============================================================================
# SISTEMA DE VOCES (Fase 15, C3)
# ==============================================================================

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

@export_group("Event")
## Evento que suena en el punto resuelto. Sin el, el `stream` del nodo se envuelve en una
## definicion propia (en bucle) con el bus del nodo.
@export var event_def: AudioEventDef = null
## Arranca la voz al entrar al arbol (o en cuanto haya stream o evento). El nodo NO suena por
## si mismo: la voz es del pool (robo de voces, salas, backend binaural) y este nodo solo
## aporta la posicion cada cuadro.
@export var auto_play_event: bool = true
@export_group("")

var active_instance: EventInstance = null
var _event_manager: AudioEventManager = null
var _own_def: AudioEventDef = null

func set_event_manager(m: AudioEventManager) -> void:
	_event_manager = m

func _get_manager() -> AudioEventManager:
	if _event_manager != null and is_instance_valid(_event_manager):
		return _event_manager
	if is_inside_tree():
		var root_node = get_tree().root
		if root_node != null and root_node.has_node("OpenDou"):
			var node = root_node.get_node("OpenDou")
			if node is AudioEventManager:
				return node
	return null

## Publica el evento por el manager con este nodo como proveedor de posicion.
func play_event() -> bool:
	if active_instance != null and active_instance.is_playing():
		return true
	var manager: AudioEventManager = _get_manager()
	if manager == null:
		return false
	var def: AudioEventDef = event_def
	if def == null:
		if stream == null:
			return false
		if _own_def == null or _own_def.base_stream != stream:
			_own_def = AudioEventDefClass.new(StringName("%s_%d" % [name, get_instance_id()]), stream)
			_own_def.is_looping = true
			_own_def.stream_length = maxf(float(stream.get_length()), 0.1)
		_own_def.target_bus = StringName(bus)
		def = _own_def
	manager.register_event_definition(def)
	active_instance = manager.post_event(def, null)
	if active_instance == null:
		return false
	active_instance.position_provider = self
	active_instance.copy_attenuation_from_player(self)
	active_instance.doppler_enabled = _provider_doppler_enabled()
	active_instance.max_distance = _provider_max_distance()
	active_instance.set_position(resolve_emitter_position(manager.active_listener_position))
	return true

func stop_event() -> void:
	if active_instance != null:
		active_instance.stop()
	active_instance = null

func _provider_tick() -> void:
	if Engine.is_editor_hint():
		return
	# El reproductor nativo del nodo no debe sonar: si alguien llamo a play(), se para y la
	# voz sale por el pool.
	if playing:
		stop()
	if auto_play_event and (active_instance == null or not active_instance.is_playing()) and (event_def != null or stream != null):
		play_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		stop_event()

## Proveedor de posicion: el punto de la curva mas cercano al oyente.
func resolve_emitter_position(listener_pos: Vector3) -> Vector3:
	return get_closest_virtual_point(listener_pos)

## Velocidad del flujo en ese punto (entra al doppler de la voz).
func resolve_flow_velocity(listener_pos: Vector3) -> Vector3:
	return get_flow_velocity_at(listener_pos)

func _provider_doppler_enabled() -> bool:
	return enable_doppler

func _provider_max_distance() -> float:
	return max_virtual_distance + 10.0
