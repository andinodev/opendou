class_name AudioPortal
extends RefCounted

## Represents an acoustic aperture (doorway, window, arch) connecting two rooms.

var portal_name: StringName = &""
var room_a_name: StringName = &""
var room_b_name: StringName = &""
var position: Vector3 = Vector3.ZERO

# Aperture openness: 0.0 (closed solid wall) to 1.0 (fully open)
var open_factor: float = 1.0
var base_lpf_cutoff: float = 20000.0
var min_lpf_cutoff: float = 200.0

func _init(p_name: StringName = &"", p_room_a: StringName = &"", p_room_b: StringName = &"", p_pos: Vector3 = Vector3.ZERO, p_open: float = 1.0) -> void:
	portal_name = p_name
	room_a_name = p_room_a
	room_b_name = p_room_b
	position = p_pos
	open_factor = clampf(p_open, 0.0, 1.0)

## Calculates current Low-Pass Filter cutoff in Hz based on portal openness.
func get_current_lpf() -> float:
	return lerpf(min_lpf_cutoff, base_lpf_cutoff, open_factor)

## Given one connected room, returns the other room name.
func get_other_room(current_room: StringName) -> StringName:
	if current_room == room_a_name:
		return room_b_name
	elif current_room == room_b_name:
		return room_a_name
	return &""
