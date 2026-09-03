@icon("res://addons/opendou/icons/icon_multi_position_emitter_3d.svg")
@tool
class_name OpenDouMultiPositionEmitter3D
extends AudioStreamPlayer3D

## Declarative Large Audio Object / Multi-Position Emitter for OpenDou.
## Binds a single physical audio stream to multiple spatial emission vertices
## with closest-point tracking, blended gain, comb-filter suppression, and per-vertex occlusion.

const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")

enum RenderingMode {
	CLOSEST_POINT_TRACKING,
	MULTI_POINT_BLENDED
}

# ==============================================================================
# EXPORTED PROPERTIES
# ==============================================================================

@export_group("Multi-Position Geometry")
@export var emission_points: Array[Vector3] = [Vector3.ZERO]:
	set(val):
		var typed_pts: Array[Vector3] = []
		for p in val:
			if p is Vector3:
				typed_pts.append(p)
		emission_points = typed_pts
		_update_cached_aabb()

@export var rendering_mode: RenderingMode = RenderingMode.CLOSEST_POINT_TRACKING

enum SourceMode { POINTS, MESH }
@export_group("Mesh Source")
## MESH (Fase 11): el punto mas cercano SOBRE los triangulos del MeshInstance3D (BVH), no un
## vertice muestreado. POINTS es el comportamiento de siempre.
@export var source_mode: SourceMode = SourceMode.POINTS
@export_node_path("MeshInstance3D") var mesh_path: NodePath = NodePath("")
## El origen no se mueve si el nuevo punto esta mas cerca que esto (evita el temblor).
@export_range(0.0, 5.0, 0.01) var mesh_hysteresis_m: float = 0.25
@export_group("")
@export_range(0.0, 1.0, 0.01) var smooth_position_lag: float = 0.1

@export_group("Acoustic Phase & Envelopment")
@export var random_phase_offset: bool = true
@export var envelopment_on_inside: bool = true

@export_group("Acoustic Occlusion & Culling")
@export var cull_distance: float = 50.0
@export var vertex_occlusion: bool = true

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var _current_render_pos: Vector3 = Vector3.ZERO
var _bvh = null
var _mesh_point: Vector3 = Vector3.ZERO
var _mesh_point_valid: bool = false
var _active_vertex_idx: int = 0
var _listener_node: Node3D = null
var _is_inside_volume: bool = false
var _cached_aabb: AABB = AABB()

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if not Engine.is_editor_hint() and source_mode == SourceMode.MESH:
		rebuild_mesh()
	_update_cached_aabb()
	if emission_points.is_empty():
		emission_points = [Vector3.ZERO]
	_current_render_pos = global_position if is_inside_tree() else position

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_provider_tick()

## Punto que suena para un oyente: el mas cercano (o el mezclado, o el de la malla), suavizado.
## Desde la Fase 15 el nodo NO se mueve (mover el nodo desplazaba sus propios puntos): la voz
## del pool toma esta posicion cada cuadro.
func resolve_emitter_position(listener_pos: Vector3) -> Vector3:
	var delta: float = maxf(get_process_delta_time(), 0.001)
	_is_inside_volume = is_position_inside_emission_volume(listener_pos)
	var target_render_pos: Vector3 = Vector3.ZERO
	if source_mode == SourceMode.MESH:
		target_render_pos = get_mesh_closest_point(listener_pos)
	else:
		match rendering_mode:
			RenderingMode.CLOSEST_POINT_TRACKING:
				target_render_pos = get_closest_point_to(listener_pos)
			RenderingMode.MULTI_POINT_BLENDED:
				target_render_pos = calculate_blended_position(listener_pos)

	# Smooth lag interpolation to prevent spatial clicks
	if smooth_position_lag <= 0.001 or not _render_pos_valid:
		_current_render_pos = target_render_pos
		_render_pos_valid = true
	else:
		var alpha = delta / maxf(0.001, smooth_position_lag + delta)
		_current_render_pos = _current_render_pos.lerp(target_render_pos, alpha)
	return _current_render_pos

var _render_pos_valid: bool = false

func _provider_doppler_enabled() -> bool:
	return false

func _provider_max_distance() -> float:
	return cull_distance

# ==============================================================================
# SPATIAL TRACKING & GEOMETRY
# ==============================================================================

## Reconstruye el BVH desde el MeshInstance3D, en espacio mundo con su transformacion actual.
func rebuild_mesh() -> void:
	_bvh = null
	_mesh_point_valid = false
	if mesh_path.is_empty():
		return
	var mi = get_node_or_null(mesh_path) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var faces: PackedVector3Array = mi.mesh.get_faces()
	var world := PackedVector3Array()
	world.resize(faces.size())
	var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
	for i in range(faces.size()):
		world[i] = xf * faces[i]
	_bvh = preload("res://addons/opendou/runtime/spatial/triangle_bvh.gd").new()
	_bvh.build(world)

## Punto de la malla mas cercano al objetivo, con histeresis.
func get_mesh_closest_point(global_target: Vector3) -> Vector3:
	if _bvh == null:
		return TransformUtilsClass.world_position_of(self)
	var q: Vector3 = _bvh.closest_point(global_target)
	if _mesh_point_valid and q.distance_to(_mesh_point) < mesh_hysteresis_m:
		return _mesh_point
	_mesh_point = q
	_mesh_point_valid = true
	return q

## Returns the global coordinate of the emission vertex closest to the target position.
func get_closest_point_to(global_target: Vector3) -> Vector3:
	if emission_points.is_empty():
		return TransformUtilsClass.world_position_of(self)

	var node_pos = TransformUtilsClass.world_position_of(self)
	var closest_pos: Vector3 = node_pos + emission_points[0]
	var min_dist_sq: float = (closest_pos - global_target).length_squared()
	_active_vertex_idx = 0

	for i in range(emission_points.size()):
		var pt_global = node_pos + emission_points[i]
		var dist_sq = (pt_global - global_target).length_squared()
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_pos = pt_global
			_active_vertex_idx = i

	return closest_pos

## Calculates the weighted centroid position across all active vertices.
func calculate_blended_position(global_target: Vector3) -> Vector3:
	if emission_points.is_empty():
		return TransformUtilsClass.world_position_of(self)

	var node_pos = TransformUtilsClass.world_position_of(self)
	var sum_pos = Vector3.ZERO
	var sum_weight = 0.0
	var d_max = maxf(1.0, cull_distance)

	for i in range(emission_points.size()):
		var pt_global = node_pos + emission_points[i]
		var dist = (pt_global - global_target).length()
		var w = clampf(1.0 - (dist / d_max), 0.0, 1.0)
		w = w * w # Quadratic falloff
		sum_pos += pt_global * w
		sum_weight += w

	if sum_weight <= 0.0001:
		return get_closest_point_to(global_target)
	return sum_pos / sum_weight

## Evaluates whether a point is inside the bounding AABB of all emission points.
func is_position_inside_emission_volume(global_target: Vector3) -> bool:
	_update_cached_aabb()
	var local_target = global_target - (TransformUtilsClass.world_position_of(self))
	# Expand slightly to account for boundary margin
	var expanded = _cached_aabb.grow(1.0)
	return expanded.has_point(local_target)

func _update_cached_aabb() -> void:
	if emission_points.is_empty():
		_cached_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
		return
	var b = AABB(emission_points[0], Vector3.ZERO)
	for pt in emission_points:
		b = b.expand(pt)
	_cached_aabb = b

# ==============================================================================
# DYNAMIC VERTICES API
# ==============================================================================

func add_emission_point(local_pos: Vector3) -> int:
	emission_points.append(local_pos)
	_update_cached_aabb()
	return emission_points.size() - 1

func remove_emission_point(index: int) -> void:
	if index >= 0 and index < emission_points.size():
		emission_points.remove_at(index)
		_update_cached_aabb()

func clear_emission_points() -> void:
	emission_points.clear()
	_update_cached_aabb()

func set_emission_points(points: Array) -> void:
	var typed_pts: Array[Vector3] = []
	for p in points:
		if p is Vector3:
			typed_pts.append(p)
	emission_points = typed_pts
	_update_cached_aabb()

## Extracts vertex coordinates from a MeshInstance3D geometry.
func update_points_from_mesh(mesh_instance: MeshInstance3D, sample_step: int = 8) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var arrays = mesh_instance.mesh.get_faces()
	if arrays.is_empty():
		return
	clear_emission_points()
	var step = max(1, sample_step)
	for i in range(0, arrays.size(), step):
		add_emission_point(arrays[i])

# ==============================================================================
# ACOUSTIC OCCLUSION & PHASE SUPPRESSION
# ==============================================================================

## Returns a deterministic pseudo-random micro-phase offset for a given vertex.
func get_vertex_micro_phase_offset(vertex_index: int) -> float:
	# Generates distinct micro-offsets [0.1ms, 2.5ms]
	var seed_val = float(vertex_index * 1337 + 42)
	return 0.1 + fmod(absf(sin(seed_val) * 2.4), 2.4)

## Returns the active origin coordinate for physical occlusion raycasts.
func get_occlusion_raycast_origin(listener_pos: Vector3) -> Vector3:
	if not vertex_occlusion:
		return global_position if is_inside_tree() else position
	return get_closest_point_to(listener_pos)

## Evaluates whether the emitter should be distance-culled.
func should_cull_at_distance(listener_pos: Vector3) -> bool:
	var closest = get_closest_point_to(listener_pos)
	return (closest - listener_pos).length() > cull_distance

func _get_listener_position() -> Vector3:
	if _listener_node != null and is_instance_valid(_listener_node):
		return _listener_node.global_position if _listener_node.is_inside_tree() else _listener_node.position
	var vp = get_viewport()
	if vp != null:
		var cam = vp.get_camera_3d()
		if cam != null:
			return cam.global_position
	return Vector3.ZERO

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
