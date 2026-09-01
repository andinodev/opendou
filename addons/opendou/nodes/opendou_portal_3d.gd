@icon("res://addons/opendou/icons/icon_portal.svg")
@tool
class_name OpenDouPortal3D
extends Node3D

## Declarative 3D Acoustic Portal Node for OpenDou.
## Connects two OpenDouRoom3D enclosures and modulates acoustic diffraction and low-pass filtering
## based on aperture open factor (0.0 = closed/occluded, 1.0 = wide open).

const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Portal Configuration")
@export var portal_name: StringName = &"Portal"
@export_node_path("Area3D") var room_a: NodePath
@export_node_path("Area3D") var room_b: NodePath
@export var room_a_name: StringName = &""
@export var room_b_name: StringName = &""
@export_range(0.0, 1.0, 0.01) var open_factor: float = 1.0
@export var portal_size: Vector2 = Vector2(2.0, 3.0)

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var runtime_portal: AudioPortal = null
var _acoustics_manager: SpatialAcousticsManager = null

func _ready() -> void:
	register_in_manager()

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Calculates Low-Pass Filter cutoff frequency in Hz based on portal openness.
func get_diffraction_lpf() -> float:
	return lerpf(300.0, 20000.0, clampf(open_factor, 0.0, 1.0))

## Updates the portal openness factor dynamically at runtime.
func set_open_factor(p_factor: float) -> void:
	open_factor = clampf(p_factor, 0.0, 1.0)
	if runtime_portal != null:
		runtime_portal.open_factor = open_factor

## Explicitly injects a SpatialAcousticsManager for isolated testing.
func set_acoustics_manager(manager: SpatialAcousticsManager) -> void:
	_acoustics_manager = manager

## Registers or updates this portal inside the spatial acoustics manager.
func register_in_manager(manager: SpatialAcousticsManager = null) -> AudioPortal:
	var mgr: SpatialAcousticsManager = manager if manager != null else _get_acoustics_manager()
	var r_a: StringName = _resolve_room_name(room_a, room_a_name)
	var r_b: StringName = _resolve_room_name(room_b, room_b_name)
	var pos: Vector3 = TransformUtilsClass.world_position_of(self)

	if runtime_portal == null:
		runtime_portal = AudioPortalClass.new(portal_name, r_a, r_b, pos, open_factor)
		runtime_portal.base_lpf_cutoff = 20000.0
		runtime_portal.min_lpf_cutoff = 300.0
	else:
		runtime_portal.portal_name = portal_name
		runtime_portal.room_a_name = r_a
		runtime_portal.room_b_name = r_b
		runtime_portal.position = pos
		runtime_portal.open_factor = open_factor

	if mgr != null:
		mgr.register_portal(runtime_portal)

	return runtime_portal

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _resolve_room_name(target_path: NodePath, direct_name: StringName) -> StringName:
	if not direct_name.is_empty():
		return direct_name
	if not target_path.is_empty():
		var node = get_node_or_null(target_path)
		if node != null:
			if "room_name" in node and not str(node.room_name).is_empty():
				return node.room_name
			return StringName(node.name)
	return &""

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
