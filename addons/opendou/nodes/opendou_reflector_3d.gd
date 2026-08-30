@icon("res://addons/opendou/icons/icon_room.svg")
@tool
class_name OpenDouReflector3D
extends Node3D

## Declarative Acoustic Reflector Node for OpenDou.
## Defines a planar reflective surface in 3D space to simulate 1st order specular early reflections.

const AcousticReflectorClass = preload("res://addons/opendou/core/spatial/acoustic_reflector.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Acoustic Reflector")
@export var reflector_name: StringName = &"Reflector"
@export var plane_normal: Vector3 = Vector3.FORWARD
@export_range(0.0, 1.0, 0.01) var absorption: float = 0.1

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var _acoustics_manager: SpatialAcousticsManager = null

func _ready() -> void:
	register_in_manager()

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Calculates the virtual mirror image source position across this reflector's plane.
func get_reflected_point(source_point: Vector3) -> Vector3:
	var plane_pos: Vector3 = global_position if is_inside_tree() else position
	var n: Vector3 = plane_normal.normalized() if not plane_normal.is_zero_approx() else Vector3.UP
	var dist: float = (source_point - plane_pos).dot(n)
	return source_point - 2.0 * dist * n

## Explicitly injects a SpatialAcousticsManager for isolated testing.
func set_acoustics_manager(manager: SpatialAcousticsManager) -> void:
	_acoustics_manager = manager

## Registers this reflector inside the spatial acoustics manager if supported.
func register_in_manager(manager: SpatialAcousticsManager = null) -> void:
	var mgr: SpatialAcousticsManager = manager if manager != null else _get_acoustics_manager()
	if mgr != null and mgr.has_method("register_reflector"):
		mgr.register_reflector(self)

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _get_acoustics_manager() -> SpatialAcousticsManager:
	if _acoustics_manager != null and is_instance_valid(_acoustics_manager):
		return _acoustics_manager
	if is_inside_tree():
		var root: Window = get_tree().root
		if root != null and root.has_node("OpenDou"):
			var node = root.get_node("OpenDou")
			if "spatial_acoustics" in node and node.spatial_acoustics != null:
				return node.spatial_acoustics
	if Engine.has_singleton("OpenDou"):
		var s = Engine.get_singleton("OpenDou")
		if "spatial_acoustics" in s and s.spatial_acoustics != null:
			return s.spatial_acoustics
	return null
