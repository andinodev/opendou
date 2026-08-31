class_name AudioRoom
extends RefCounted

## Represents an acoustic enclosure with reverberation characteristics and portal links.

const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

var room_name: StringName = &""
var reverb_decay_time: float = 1.5
var reverb_time: float:
	get: return reverb_decay_time
	set(v): reverb_decay_time = maxf(0.01, v)
var rt60: float:
	get: return reverb_decay_time
	set(v): reverb_decay_time = maxf(0.01, v)
var damping: float = 0.5
var reverb_send_level: float = 0.2

var floor_surface: StringName = &"Concrete"
var material_preset: String = "Concrete"

var reverb_mode: int = 0 # 0 = ALGORITHMIC, 1 = CONVOLUTION_IR, 2 = HYBRID
var convolution_wet_db: float = -6.0
var convolution_dry_db: float = 0.0
var ir_kernel: PackedFloat32Array = PackedFloat32Array()

var bounds: AABB = AABB()
var has_bounds: bool = false
var connected_portals: Array = [] # Array of AudioPortal

func _init(p_name: StringName = &"", p_reverb: float = 1.5, p_damping: float = 0.5, p_floor: StringName = &"Concrete") -> void:
	room_name = p_name
	reverb_decay_time = p_reverb
	damping = p_damping
	floor_surface = p_floor
	connected_portals = []

## Links a portal to this room.
func register_portal(portal: RefCounted) -> void:
	if portal and not connected_portals.has(portal):
		connected_portals.append(portal)

## Sets the spatial bounding box for point-in-room detection.
func set_bounds(p_bounds: AABB) -> void:
	bounds = p_bounds
	has_bounds = true

## Checks if a 3D coordinate falls inside this room.
func contains_point(point: Vector3) -> bool:
	if has_bounds:
		return bounds.has_point(point)
	return false
