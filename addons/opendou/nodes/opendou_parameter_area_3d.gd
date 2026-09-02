@icon("res://addons/opendou/icons/icon_parameter_area_3d.svg")
@tool
class_name OpenDouParameterArea3D
extends Area3D

## Declarative 3D Parameter Modulation Volume for OpenDou.
## Continuously modulates RTPC game parameters, master mix snapshots, and auxiliary sends
## based on entity penetration depth, axis gradients, and bounding volumes.

const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

enum InterpolationMode {
	CENTER_RADIAL,
	AXIS_GRADIENT,
	BINARY_TRIGGER
}

enum BlendOperation {
	MAX,
	ADD,
	REPLACE
}

# ==============================================================================
# EXPORTED PROPERTIES
# ==============================================================================

@export_group("RTPC Parameter & Modulation")
@export var parameter_name: StringName = &""
@export var interpolation_mode: InterpolationMode = InterpolationMode.CENTER_RADIAL
@export var modulation_curve: Curve = null
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var gradient_axis: Vector3 = Vector3.UP
@export var ignore_y_axis: bool = false

@export_group("Conflict Resolution & Blending")
@export var rtpc_priority: int = 0
@export var blend_operation: BlendOperation = BlendOperation.MAX

@export_group("Snapshots & Global Mix")
@export var target_snapshot: StringName = &""

@export_group("Transitions & Physics Robustness")
@export var fade_in_time: float = 0.5
@export var fade_out_time: float = 0.8
@export var edge_hysteresis_ms: float = 150.0
@export var affects_emitters_inside: bool = true
@export_flags_3d_physics var target_entity_mask: int = 1

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var _active_targets: Array[Node3D] = []
var _current_interpolated_value: float = 0.0
var _current_raw_penetration: float = 0.0
var _hysteresis_timers: Dictionary = {}
var _is_snapshot_active: bool = false
var _event_manager: AudioEventManager = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		collision_mask = target_entity_mask
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)
		if not area_exited.is_connected(_on_area_exited):
			area_exited.connect(_on_area_exited)

func _exit_tree() -> void:
	_release_snapshot()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	cleanup_invalid_targets()
	if _active_targets.is_empty():
		if _current_interpolated_value > min_value:
			_current_interpolated_value = move_toward(_current_interpolated_value, min_value, (absf(max_value - min_value) / maxf(0.001, fade_out_time)) * delta)
			_apply_parameter_value(_current_interpolated_value)
		return

	# Evaluate deepest penetration among active targets
	var max_pen: float = 0.0
	var area_pos: Vector3 = global_position
	var extents: Vector3 = _get_approx_extents()

	for target in _active_targets:
		if is_instance_valid(target):
			var target_pos = target.global_position
			var pen = calculate_penetration_at(target_pos, area_pos, extents)
			if pen > max_pen:
				max_pen = pen

	_current_raw_penetration = max_pen
	var mapped_target_val = _map_penetration_to_value(max_pen)
	
	# Smooth fade transition
	var speed = (absf(max_value - min_value) / maxf(0.001, fade_in_time))
	_current_interpolated_value = move_toward(_current_interpolated_value, mapped_target_val, speed * delta)
	_apply_parameter_value(_current_interpolated_value)

# ==============================================================================
# MATHEMATICAL EVALUATION & PENETRATION
# ==============================================================================

## Calculates normalized penetration [0.0, 1.0] given entity position, area center, and extents.
func calculate_penetration_at(target_pos: Vector3, center_pos: Vector3, extents: Vector3) -> float:
	match interpolation_mode:
		InterpolationMode.CENTER_RADIAL:
			var delta_pos = target_pos - center_pos
			if ignore_y_axis:
				delta_pos.y = 0.0
			var dist = delta_pos.length()
			var max_r = maxf(extents.x, extents.z) if ignore_y_axis else maxf(extents.x, maxf(extents.y, extents.z))
			if max_r <= 0.001:
				return 1.0
			return clampf(1.0 - (dist / max_r), 0.0, 1.0)
			
		InterpolationMode.AXIS_GRADIENT:
			var delta_pos = target_pos - center_pos
			var axis = gradient_axis.normalized() if not gradient_axis.is_zero_approx() else Vector3.UP
			var proj = delta_pos.dot(axis)
			var half_length = maxf(0.001, absf(extents.dot(axis)))
			return clampf((proj + half_length) / (2.0 * half_length), 0.0, 1.0)
			
		InterpolationMode.BINARY_TRIGGER:
			return 1.0
			
	return 1.0

func _map_penetration_to_value(pen: float) -> float:
	var t = clampf(pen, 0.0, 1.0)
	if modulation_curve != null:
		t = clampf(modulation_curve.sample(t), 0.0, 1.0)
	return lerpf(min_value, max_value, t)

func _get_approx_extents() -> Vector3:
	for child in get_children():
		if child is CollisionShape3D and child.shape != null:
			if child.shape is BoxShape3D:
				return child.shape.size * 0.5 * child.global_transform.basis.get_scale()
			elif child.shape is SphereShape3D:
				var r = child.shape.radius * child.global_transform.basis.get_scale().x
				return Vector3(r, r, r)
			elif child.shape is CylinderShape3D:
				var r = child.shape.radius * child.global_transform.basis.get_scale().x
				var h = child.shape.height * 0.5 * child.global_transform.basis.get_scale().y
				return Vector3(r, h, r)
	return Vector3(10.0, 10.0, 10.0)

# ==============================================================================
# CONFLICT RESOLUTION & BLENDING
# ==============================================================================

## Static resolver for conflict values with specified blend operation.
static func resolve_conflict(values: Array, op: int, min_v: float = 0.0, max_v: float = 1.0) -> float:
	if values.is_empty():
		return min_v
	match op:
		0: # MAX
			var highest = -INF
			for v in values:
				if float(v) > highest:
					highest = float(v)
			return highest
		1: # ADD
			var sum_val = 0.0
			for v in values:
				sum_val += float(v)
			return clampf(sum_val, min_v, max_v)
		2: # REPLACE
			return float(values.back())
	return float(values[0])

## Static resolver for priority entries dictionary: [{"val": float, "prio": int}]
static func resolve_priority_values(entries: Array) -> float:
	if entries.is_empty():
		return 0.0
	var highest_prio = -999999
	var best_val = 0.0
	for entry in entries:
		var prio = int(entry.get("prio", 0))
		if prio >= highest_prio:
			highest_prio = prio
			best_val = float(entry.get("val", 0.0))
	return best_val

# ==============================================================================
# TARGET TRACKING & DEBOUNCING
# ==============================================================================

func register_target_entered(target: Node3D) -> void:
	if target == null or _active_targets.has(target):
		return
	_active_targets.append(target)
	_activate_snapshot()
	
	# Connect to tree_exited to prevent orphaned RTPC/snapshot states on despawn
	if not target.tree_exited.is_connected(_on_target_tree_exited):
		target.tree_exited.connect(_on_target_tree_exited.bind(target))

func register_target_exited(target: Node3D) -> void:
	if target == null:
		return
	_active_targets.erase(target)
	if target.tree_exited.is_connected(_on_target_tree_exited):
		target.tree_exited.disconnect(_on_target_tree_exited)
	if _active_targets.is_empty():
		_release_snapshot()

func has_active_target(target: Node3D) -> bool:
	return _active_targets.has(target)

func get_active_targets_count() -> int:
	return _active_targets.size()

func cleanup_invalid_targets() -> void:
	var valid: Array[Node3D] = []
	for t in _active_targets:
		if is_instance_valid(t):
			valid.append(t)
	_active_targets = valid

func evaluate_hysteresis_debounce(delta: float, target_time_ms: float) -> bool:
	return target_time_ms < edge_hysteresis_ms

func _on_body_entered(body: Node3D) -> void:
	register_target_entered(body)

func _on_body_exited(body: Node3D) -> void:
	register_target_exited(body)

func _on_area_entered(area: Area3D) -> void:
	register_target_entered(area)

func _on_area_exited(area: Area3D) -> void:
	register_target_exited(area)

func _on_target_tree_exited(target: Node3D) -> void:
	register_target_exited(target)

# ==============================================================================
# SNAPSHOT & RTPC DISPATCH
# ==============================================================================

## Sets an explicit AudioEventManager instance for dependency injection or isolated tests.
func set_event_manager(manager: AudioEventManager) -> void:
	_event_manager = manager

func _get_manager() -> AudioEventManager:
	if _event_manager != null and is_instance_valid(_event_manager):
		return _event_manager
	if is_inside_tree() and get_tree() != null:
		var root = get_tree().root
		if root != null and root.has_node("OpenDou"):
			var node = root.get_node("OpenDou")
			if node is AudioEventManager:
				return node
	if Engine.has_singleton("OpenDou"):
		var s = Engine.get_singleton("OpenDou")
		if s is AudioEventManager:
			return s
	return null

func _apply_parameter_value(val: float) -> void:
	if parameter_name.is_empty():
		return
	var mgr: AudioEventManager = _get_manager()
	if mgr != null:
		if mgr.has_method("set_rtpc"):
			mgr.set_rtpc(parameter_name, val)
		elif mgr.has_method("set_rtpc_value"):
			mgr.set_rtpc_value(parameter_name, val)

func _activate_snapshot() -> void:
	if target_snapshot.is_empty() or _is_snapshot_active:
		return
	_is_snapshot_active = true
	var mgr: AudioEventManager = _get_manager()
	if mgr != null:
		mgr.push_snapshot(target_snapshot, fade_in_time)

func _release_snapshot() -> void:
	if not _is_snapshot_active or target_snapshot.is_empty():
		return
	_is_snapshot_active = false
	var mgr: AudioEventManager = _get_manager()
	if mgr != null:
		mgr.pop_snapshot(target_snapshot, fade_out_time)
