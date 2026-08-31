@tool
class_name RoomCouplingEngine
extends RefCounted

## Inter-Room Reverb Coupling & Portal Sound Spread Engine.
## Couples reverberation decay tails between interconnected architectural rooms through portals,
## and scales sound spread angular perceived width from narrow point-source to full wrap.

const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

## Calculates the acoustic energy transmitted from an excited source room into an adjacent connected room.
## [param source_room_energy]: Reverb energy in source room.
## [param portal_area]: Surface aperture of portal in square meters.
## [param room_surface_area]: Total surface area of source room.
## [param portal_open_ratio]: Normalized portal aperture opening [0.0 = closed, 1.0 = fully open].
func calculate_coupled_energy(source_room_energy: float, portal_area: float, room_surface_area: float, portal_open_ratio: float) -> float:
	var safe_portal = maxf(0.1, portal_area)
	var safe_room = maxf(1.0, room_surface_area)
	var safe_open = clampf(portal_open_ratio, 0.0, 1.0)
	
	var coupling_ratio = clampf((safe_portal / safe_room) * safe_open, 0.0, 1.0)
	return source_room_energy * coupling_ratio

## Calculates dynamic sound spread in degrees (15.0 deg to 180.0 deg) based on listener proximity to portal.
func calculate_portal_sound_spread(listener_pos: Vector3, portal_pos: Vector3, portal_radius: float = 2.0, max_spread_dist: float = 15.0) -> float:
	var dist = listener_pos.distance_to(portal_pos)
	if dist <= portal_radius:
		return 180.0
	if dist >= max_spread_dist:
		return 15.0
	
	var t = clampf(1.0 - ((dist - portal_radius) / maxf(0.1, max_spread_dist - portal_radius)), 0.0, 1.0)
	return lerpf(15.0, 180.0, t)

## Evaluates inter-room reverb coupling across an AudioPortal.
func evaluate_room_coupling(source_room: AudioRoom, portal: AudioPortal, listener_pos: Vector3) -> Dictionary:
	var open_ratio = portal.open_state if portal != null else 1.0
	var portal_pos = portal.position if portal != null else Vector3.ZERO
	var source_rt60 = source_room.rt60 if source_room != null else 1.2
	
	var coupled_energy = calculate_coupled_energy(source_rt60, 4.0, 100.0, open_ratio)
	var spread_deg = calculate_portal_sound_spread(listener_pos, portal_pos)
	var portal_lpf = portal.get_current_lpf() if portal != null else 20000.0
	
	return {
		"coupled_rt60": coupled_energy,
		"sound_spread_degrees": spread_deg,
		"portal_lpf": portal_lpf,
		"portal_gain": clampf(open_ratio, 0.0, 1.0)
	}
