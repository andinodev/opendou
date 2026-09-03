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

var reverb_mode: int = 0 # 0 = SABINE_RT60, 1 = IR_DERIVED_RT60, 2 = CONVOLUTION (Fase 13)
## Bus de reverb asignado por el pool y envio de la sala (los fija OpenDouRoom3D).
var assigned_reverb_bus: StringName = &""
var reverb_send_amount: float = 0.5
## Fase 15: id del envio nativo del bus de la sala (-1 = enruta Godot por el Area3D).
var send_id: int = -1

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
