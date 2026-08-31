@tool
class_name OpenDouSplineEmitter3D
extends AudioStreamPlayer3D

## Continuous volumetric 3D spline audio emitter (for rivers, powerlines, wide barriers, and roads).
## Projects sound smoothly from the closest point along a Curve3D to the listener in real-time.

const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")

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

## Physics collision mask for acoustic line-of-sight checks.
@export_flags_3d_physics var acoustic_collision_mask: int = 1

var _acoustics_manager: SpatialAcousticsManager
var _virtual_target_pos: Vector3 = Vector3.ZERO
var _current_air_cutoff: float = 20000.0
var _prev_listener_pos: Vector3 = Vector3.ZERO
var _prev_emitter_pos: Vector3 = Vector3.ZERO

func _init() -> void:
	_acoustics_manager = SpatialAcousticsManagerClass.new()
	if sound_spread_curve == null:
		sound_spread_curve = Curve.new()
		sound_spread_curve.add_point(Vector2(0.0, 0.0))  # Far: 0 spread
		sound_spread_curve.add_point(Vector2(1.0, 1.0))  # Near: 180 deg spread

func _ready() -> void:
	_virtual_target_pos = global_position
	_prev_emitter_pos = global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if curve == null or curve.point_count < 2:
		warnings.append("OpenDouSplineEmitter3D requires a Curve3D with at least 2 points to project volumetric sound.")
	return warnings

## Calculates the closest 3D world coordinate along the spline relative to a given listener position.
func get_closest_virtual_point(listener_pos: Vector3) -> Vector3:
	if curve == null or curve.point_count < 2:
		return global_position if is_inside_tree() else position
	var local_listener = to_local(listener_pos) if is_inside_tree() else (listener_pos - position)
	var closest_local = curve.get_closest_point(local_listener)
	return to_global(closest_local) if is_inside_tree() else (position + closest_local)

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
	
	# Smoothly position virtual emitter at closest point
	global_position = global_position.lerp(_virtual_target_pos, clampf(delta * 20.0, 0.0, 1.0))
	
	# Atmospheric Air Absorption
	if enable_air_absorption:
		_current_air_cutoff = _acoustics_manager.calculate_air_absorption(dist_to_closest)
	else:
		_current_air_cutoff = 20000.0
	
	# Doppler frequency modulation
	if enable_doppler:
		var emitter_vel = (global_position - _prev_emitter_pos) / maxf(0.001, delta)
		var rel_pos = listener_pos - global_position
		var doppler_factor = _acoustics_manager.calculate_doppler_pitch(emitter_vel, listener_vel, rel_pos)
		pitch_scale = base_pitch_scale * doppler_factor
		_prev_emitter_pos = global_position

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Retrieve active listener
	var viewport = get_viewport()
	if viewport != null:
		var camera = viewport.get_camera_3d()
		if camera != null:
			var listener_pos = camera.global_position
			var listener_vel = (listener_pos - _prev_listener_pos) / maxf(0.001, delta)
			_prev_listener_pos = listener_pos
			update_spline_acoustics(listener_pos, listener_vel, delta)
