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

## Corte del filtro con el portal cerrado, en Hz.
const MIN_DIFFRACTION_LPF_HZ: float = 300.0

## Corte del filtro con una apertura de referencia completamente abierta, en Hz.
const MAX_DIFFRACTION_LPF_HZ: float = 20000.0

## Area de apertura de referencia, en metros cuadrados: una puerta de 2 x 3 m.
## Una apertura de este tamano abierta del todo no filtra nada, lo que conserva
## el comportamiento anterior para el portal_size por defecto.
const REFERENCE_APERTURE_AREA_M2: float = 6.0

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Portal Configuration")
@export var portal_name: StringName = &"Portal"
@export_node_path("Area3D") var room_a: NodePath
@export_node_path("Area3D") var room_b: NodePath
@export var room_a_name: StringName = &""
@export var room_b_name: StringName = &""
## Apertura del portal, de 0 (cerrado) a 1 (completamente abierto).
##
## Va con setter porque asignarlo es la forma natural de animarlo desde un tween
## o un AnimationPlayer, y antes ese camino no actualizaba el portal en runtime:
## habia que acordarse de llamar set_open_factor(). Room3D ya usaba setters para
## sus propiedades, asi que los dos nodos hermanos se comportaban distinto ante la
## misma operacion.
@export_range(0.0, 1.0, 0.01) var open_factor: float = 1.0:
	set(val):
		open_factor = clampf(val, 0.0, 1.0)
		if runtime_portal != null:
			runtime_portal.open_factor = open_factor
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

## Corte del filtro paso-bajo de difraccion, en Hz.
##
## Depende de la apertura EFECTIVA, no solo de open_factor: portal_size estaba
## expuesto y no se leia en ninguna parte, asi que una gatera y un porton abierto
## difractaban igual. Fisicamente, cuanto menor es la apertura frente a la
## longitud de onda, mas difracta y mas agudos pierde.
func get_diffraction_lpf() -> float:
	var area: float = maxf(0.0, portal_size.x) * maxf(0.0, portal_size.y)
	var effective: float = clampf(open_factor, 0.0, 1.0) * (area / REFERENCE_APERTURE_AREA_M2)
	return lerpf(MIN_DIFFRACTION_LPF_HZ, MAX_DIFFRACTION_LPF_HZ, clampf(effective, 0.0, 1.0))

## Actualiza la apertura del portal.
##
## Se conserva como API publica; asignar open_factor directamente hace lo mismo.
func set_open_factor(p_factor: float) -> void:
	open_factor = p_factor

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
