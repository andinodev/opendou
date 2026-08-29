class_name SpatialAcousticsManager
extends RefCounted

## Manages the spatial room-portal acoustic graph and calculates diffraction paths and filtering.

const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AcousticPathClass = preload("res://addons/opendou/runtime/spatial/acoustic_path.gd")

var rooms: Dictionary = {}   # StringName -> AudioRoom
var portals: Dictionary = {} # StringName -> AudioPortal

## Registers a room in the acoustics manager.
func register_room(room: AudioRoom) -> void:
	if room and not room.room_name.is_empty():
		rooms[room.room_name] = room

## Registers a portal in the acoustics manager and links it to both connected rooms.
func register_portal(portal: AudioPortal) -> void:
	if portal and not portal.portal_name.is_empty():
		portals[portal.portal_name] = portal
		if rooms.has(portal.room_a_name):
			rooms[portal.room_a_name].register_portal(portal)
		if rooms.has(portal.room_b_name):
			rooms[portal.room_b_name].register_portal(portal)

## Finds the room containing a 3D coordinate.
func get_room_at_position(pos: Vector3) -> AudioRoom:
	for r_name in rooms:
		var r: AudioRoom = rooms[r_name]
		if r.contains_point(pos):
			return r
	return null

## Calculates acoustic sound propagation between emitter and listener across rooms and portals.
func calculate_acoustic_path(emitter_pos: Vector3, listener_pos: Vector3, emitter_room_name: StringName = &"", listener_room_name: StringName = &"") -> AcousticPath:
	var e_room = emitter_room_name
	var l_room = listener_room_name
	
	if e_room.is_empty():
		var found_e = get_room_at_position(emitter_pos)
		if found_e:
			e_room = found_e.room_name
			
	if l_room.is_empty():
		var found_l = get_room_at_position(listener_pos)
		if found_l:
			l_room = found_l.room_name
			
	# Direct Line of Sight (same room or no enclosures)
	if e_room.is_empty() or l_room.is_empty() or e_room == l_room:
		var direct_dist = emitter_pos.distance_to(listener_pos)
		return AcousticPathClass.new(direct_dist, 20000.0, emitter_pos, true)
		
	# Pathfinding across Portals Graph (Breadth-First / Shortest Path)
	var queue: Array = [] # Array of dicts: {"room": StringName, "path_portals": Array, "total_dist": float, "last_pos": Vector3, "min_lpf": float}
	var visited_rooms: Dictionary = {}
	
	queue.append({
		"room": e_room,
		"path_portals": [],
		"total_dist": 0.0,
		"last_pos": emitter_pos,
		"min_lpf": 20000.0
	})
	visited_rooms[e_room] = true
	
	var best_path: Dictionary = {}
	var min_total_distance: float = 1e9
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var cur_room_name: StringName = current["room"]
		
		if cur_room_name == l_room:
			var final_segment = current["last_pos"].distance_to(listener_pos)
			var total = current["total_dist"] + final_segment
			if total < min_total_distance:
				min_total_distance = total
				best_path = current
				best_path["total_dist"] = total
			continue
			
		if not rooms.has(cur_room_name):
			continue
			
		var cur_room: AudioRoom = rooms[cur_room_name]
		for p in cur_room.connected_portals:
			var portal: AudioPortal = p
			var next_room = portal.get_other_room(cur_room_name)
			if next_room.is_empty() or visited_rooms.has(next_room):
				continue
				
			visited_rooms[next_room] = true
			var seg_dist = current["last_pos"].distance_to(portal.position)
			var new_lpf = minf(current["min_lpf"], portal.get_current_lpf())
			var new_portals = current["path_portals"].duplicate()
			new_portals.append(portal)
			
			queue.append({
				"room": next_room,
				"path_portals": new_portals,
				"total_dist": current["total_dist"] + seg_dist,
				"last_pos": portal.position,
				"min_lpf": new_lpf
			})
			
	if not best_path.is_empty() and not best_path["path_portals"].is_empty():
		var portals_list: Array = best_path["path_portals"]
		# The apparent origin entering the listener's room is the LAST portal in the path
		var exit_portal: AudioPortal = portals_list[portals_list.size() - 1]
		var result = AcousticPathClass.new(best_path["total_dist"], best_path["min_lpf"], exit_portal.position, false)
		result.portals_traversed = portals_list
		return result
		
	# Fallback if no portal path connects rooms (completely occluded)
	var direct_d = emitter_pos.distance_to(listener_pos)
	return AcousticPathClass.new(direct_d, 200.0, emitter_pos, false) # Max wall occlusion LPF (200Hz)
