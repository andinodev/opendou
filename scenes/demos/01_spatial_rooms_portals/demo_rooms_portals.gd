class_name DemoRoomsPortals
extends Node3D

## Demo 01: Macro-Acoustics & Acoustic Pathfinding (Rooms, Portals & Diffraction)

const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

var acoustics: SpatialAcousticsManager
var room_a: AudioRoom
var room_b: AudioRoom
var portal: AudioPortal

var emitter_pos: Vector3 = Vector3(0.0, 0.0, 0.0)
var listener_pos: Vector3 = Vector3(20.0, 0.0, 0.0)
var door_open_factor: float = 1.0

# Current calculated acoustic path result
var calculated_path = null

func _ready() -> void:
	setup_acoustics()

func setup_acoustics() -> void:
	acoustics = SpatialAcousticsManagerClass.new()
	
	room_a = AudioRoomClass.new(&"Machine_Room", 0.8, 0.3)
	room_b = AudioRoomClass.new(&"Echo_Hall", 3.2, 0.7)
	
	# Portal at (10, 0, 0) connecting Room A and Room B
	portal = AudioPortalClass.new(&"Heavy_Door", &"Machine_Room", &"Echo_Hall", Vector3(10.0, 0.0, 0.0), door_open_factor)
	
	acoustics.register_room(room_a)
	acoustics.register_room(room_b)
	acoustics.register_portal(portal)
	
	update_path()

## Sets the door openness (0.0 = Closed solid door, 1.0 = Fully open aperture).
func set_door_open_factor(factor: float) -> void:
	door_open_factor = clampf(factor, 0.0, 1.0)
	if portal:
		portal.open_factor = door_open_factor
	update_path()

## Updates listener position in 3D space.
func set_listener_pos(pos: Vector3) -> void:
	listener_pos = pos
	update_path()

func update_path() -> void:
	if acoustics:
		calculated_path = acoustics.calculate_acoustic_path(emitter_pos, listener_pos, &"Machine_Room", &"Echo_Hall")
