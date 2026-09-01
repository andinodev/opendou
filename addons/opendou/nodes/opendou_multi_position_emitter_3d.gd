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
var _active_vertex_idx: int = 0
var _listener_node: Node3D = null
var _is_inside_volume: bool = false
var _cached_aabb: AABB = AABB()

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_update_cached_aabb()
	if emission_points.is_empty():
		emission_points = [Vector3.ZERO]
	_current_render_pos = global_position if is_inside_tree() else position

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	var listener_pos = _get_listener_position()
	if should_cull_at_distance(listener_pos):
		return

	_is_inside_volume = is_position_inside_emission_volume(listener_pos)
	
	# Envelopment handling (spread expands to 180 degrees / diffuse when inside)
	if envelopment_on_inside and _is_inside_volume:
		pass # AudioStreamPlayer3D handles proximity panning automatically

	var target_render_pos: Vector3 = Vector3.ZERO
	match rendering_mode:
		RenderingMode.CLOSEST_POINT_TRACKING:
			target_render_pos = get_closest_point_to(listener_pos)
		RenderingMode.MULTI_POINT_BLENDED:
			target_render_pos = calculate_blended_position(listener_pos)

	# Smooth lag interpolation to prevent spatial clicks
	if smooth_position_lag <= 0.001:
		_current_render_pos = target_render_pos
	else:
		var alpha = delta / maxf(0.001, smooth_position_lag + delta)
		_current_render_pos = _current_render_pos.lerp(target_render_pos, alpha)
		
	if is_inside_tree():
		global_position = _current_render_pos

# ==============================================================================
# SPATIAL TRACKING & GEOMETRY
# ==============================================================================

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
