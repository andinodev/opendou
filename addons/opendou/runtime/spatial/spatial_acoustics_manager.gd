class_name SpatialAcousticsManager
extends RefCounted

## Manages the spatial room-portal acoustic graph and calculates diffraction paths and filtering.

const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const AcousticPathClass = preload("res://addons/opendou/runtime/spatial/acoustic_path.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")
const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const AcousticLODControllerClass = preload("res://addons/opendou/runtime/spatial/acoustic_lod_controller.gd")
const ReverbBusPoolClass = preload("res://addons/opendou/runtime/spatial/reverb_bus_pool.gd")

var rooms: Dictionary = {}   # StringName -> AudioRoom
var portals: Dictionary = {} # StringName -> AudioPortal
var reflectors: Dictionary = {} # StringName -> RefCounted/Node3D

# Phase 1 & 2 Spatial Engines
var material_registry: RefCounted
var reflector_engine: RefCounted
var lod_controller: RefCounted

## Pool compartido de buses de reverb, agrupados por RT60.
##
## Sustituye a la convolucion en GDScript: el reverb lo aplica Godot en C++ sobre
## un bus compartido en lugar de calcularse como 512 taps por muestra.
var reverb_bus_pool: OpenDouReverbBusPool = null
## Velocidad del sonido del medio (Fase 10): la usa el doppler.
var speed_of_sound: float = 343.0
## Volumenes de entorno con superficie pintada (Fase 10); los asigna el AudioEventManager.
var surface_volumes: Array = []
## Fase 13: solo el backend steam_audio puede poner convolucion en un bus de reverb. Los buses
## del pool son compartidos y sobreviven al manager: una sala en godot los devuelve a Sabine.
var convolution_allowed: bool = false
## Fase 15: el backend steam_audio con extension manda el reverb por envio propio, no por el Area3D.
var native_send_allowed: bool = false

func _init() -> void:
	material_registry = AcousticMaterialRegistryClass.new()
	reflector_engine = AcousticReflectorEngineClass.new()
	lod_controller = AcousticLODControllerClass.new()
	reverb_bus_pool = ReverbBusPoolClass.new()

## Registers a room in the acoustics manager.
## Sube cada vez que el conjunto de salas o portales cambia. El despachador de caminos la
## compara para vaciar su cache: el digest de aperturas no ve una sala nueva, y un camino
## cacheado antes de que se registrara un portal seguiria valiendo (observacion 43).
var graph_generation: int = 0

func register_room(room: AudioRoom) -> void:
	if room and not room.room_name.is_empty():
		rooms[room.room_name] = room
		graph_generation += 1

## Registers a portal in the acoustics manager and links it to both connected rooms.
func register_portal(portal: AudioPortal) -> void:
	if portal and not portal.portal_name.is_empty():
		portals[portal.portal_name] = portal
		graph_generation += 1
		if rooms.has(portal.room_a_name):
			rooms[portal.room_a_name].register_portal(portal)
		if rooms.has(portal.room_b_name):
			rooms[portal.room_b_name].register_portal(portal)

## Da de baja una sala del grafo, y con ella los portales que solo la tocaban a ella.
##
## Existe porque rooms y portals solo CRECIAN: ni OpenDouRoom3D ni OpenDouPortal3D se
## daban de baja al salir del arbol, asi que un juego que carga y descarga niveles
## acumulaba salas muertas para siempre. Y una sala muerta que envuelva el nivel nuevo
## TAPA todas sus salas, porque get_room_at_position() elige por contencion.
## Observacion 38.
func unregister_room(room_name: StringName) -> void:
	if not rooms.has(room_name):
		return
	var room: AudioRoom = rooms[room_name]
	rooms.erase(room_name)
	graph_generation += 1
	# Los portales que apuntaban a esta sala quedan colgando: se retiran de la otra sala
	# y del registro, porque un portal a ninguna parte falsea los caminos del grafo.
	for portal_name in portals.keys():
		var portal: AudioPortal = portals[portal_name]
		if portal.room_a_name != room_name and portal.room_b_name != room_name:
			continue
		var other: StringName = portal.get_other_room(room_name)
		if rooms.has(other):
			rooms[other].connected_portals.erase(portal)
		portals.erase(portal_name)
	room.connected_portals.clear()

## Da de baja un portal del grafo y lo desengancha de sus dos salas.
func unregister_portal(portal_name: StringName) -> void:
	if not portals.has(portal_name):
		return
	var portal: AudioPortal = portals[portal_name]
	graph_generation += 1
	for room_name in [portal.room_a_name, portal.room_b_name]:
		if rooms.has(room_name):
			rooms[room_name].connected_portals.erase(portal)
	portals.erase(portal_name)

## Registers an acoustic reflector in the acoustics manager.
func register_reflector(reflector) -> void:
	if reflector:
		var r_name: StringName = reflector.reflector_name if "reflector_name" in reflector else StringName(str(reflector))
		if not r_name.is_empty():
			reflectors[r_name] = reflector

## Finds the room containing a 3D coordinate.
## La sala que contiene el punto, y de las que lo contengan, la MAS PEQUENA.
##
## Antes devolvia la primera que encontrara recorriendo el diccionario, asi que con salas
## anidadas o solapadas -un hangar que contiene oficinas, que es una forma legitima de
## autorar- el resultado dependia del orden de insercion. Observacion 39.
##
## La mas pequena es la mas especifica: si estas en una oficina dentro de un hangar,
## estas en la oficina.
func get_room_at_position(pos: Vector3) -> AudioRoom:
	var best: AudioRoom = null
	var best_volume: float = INF
	for r_name in rooms:
		var r: AudioRoom = rooms[r_name]
		if not r.contains_point(pos):
			continue
		var volume: float = r.bounds.size.x * r.bounds.size.y * r.bounds.size.z
		if volume < best_volume:
			best_volume = volume
			best = r
	return best

## Detects the physical ground surface at a 3D position using a 3-tier hierarchy.
## Priority 1: Physics raycast downward checking metadata/material.
## Priority 2: Enclosing AudioRoom.floor_surface.
## Priority 3: Fallback &"Concrete".
func detect_surface_at(pos: Vector3, world_3d: World3D = null) -> StringName:
	# Prioridad 0 (Fase 10): superficie pintada por un OpenDouAcousticVolume3D.
	var best_name: StringName = &""
	var best_prio: int = -2147483648
	for v in surface_volumes:
		if v == null or not is_instance_valid(v) or v.environment == null or not v.environment.surface_enabled:
			continue
		if v.environment.surface_priority > best_prio and v.contains_point(pos):
			best_prio = v.environment.surface_priority
			best_name = v.environment.surface_type
	if best_name != &"":
		return best_name
	# Priority 1: Physics Raycast downward (if world_3d provided)
	if world_3d != null:
		var space_state = world_3d.direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			pos + Vector3(0, 0.5, 0),
			pos + Vector3(0, -1.5, 0)
		)
		query.hit_from_inside = false
		var result = space_state.intersect_ray(query)
		if not result.is_empty() and result.has("collider"):
			var col = result["collider"]
			# Check metadata "surface_type"
			if col.has_meta("surface_type"):
				return col.get_meta("surface_type") as StringName
			# Check physics material resource name
			if col is StaticBody3D or col is CharacterBody3D or col is RigidBody3D:
				if col.get("physics_material_override") != null:
					var mat_name: String = col.physics_material_override.resource_name
					if not mat_name.is_empty():
						return StringName(mat_name)
			# Check collider name keywords
			var col_name: String = col.name.to_lower()
			for surf in ["metal", "water", "wood", "glass", "concrete", "tile", "foliage", "stone", "mud", "asphalt", "grass"]:
				if surf in col_name:
					return StringName(surf.capitalize())

	# Priority 2: AudioRoom.floor_surface
	var room: AudioRoom = get_room_at_position(pos)
	if room != null and not room.floor_surface.is_empty():
		return room.floor_surface

	# Priority 3: Fallback
	return &"Concrete"

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

		# Entre varios portales hacia la MISMA sala vecina, gana el mas AUDIBLE, no el
		# primero que se itere ni el mas cercano.
		#
		# Antes se marcaba la sala vecina como visitada con el primer portal del array,
		# asi que entre una puerta cerrada y una ventana abierta hacia la misma sala
		# ganaba el orden de insercion: la musica "salia" por la puerta cerrada.
		# Observacion 41. El coste pondera la distancia por el cierre: un portal cerrado
		# del todo cuenta como 16 veces su distancia, que son unos 24 dB, lo que
		# atenua una puerta corriente.
		var best_by_room: Dictionary = {} # StringName -> {portal, cost}
		for p in cur_room.connected_portals:
			var portal: AudioPortal = p
			var next_room = portal.get_other_room(cur_room_name)
			if next_room.is_empty() or visited_rooms.has(next_room):
				continue
			var seg_dist: float = current["last_pos"].distance_to(portal.position)
			var closure: float = 1.0 - clampf(portal.open_factor, 0.0, 1.0)
			var cost: float = seg_dist * (1.0 + 15.0 * closure)
			if not best_by_room.has(next_room) or cost < float(best_by_room[next_room]["cost"]):
				best_by_room[next_room] = {"portal": portal, "cost": cost, "dist": seg_dist}

		for next_room in best_by_room:
			var chosen: Dictionary = best_by_room[next_room]
			var portal: AudioPortal = chosen["portal"]
			visited_rooms[next_room] = true
			var new_lpf = minf(current["min_lpf"], portal.get_current_lpf())
			var new_portals = current["path_portals"].duplicate()
			new_portals.append(portal)

			queue.append({
				"room": next_room,
				"path_portals": new_portals,
				"total_dist": current["total_dist"] + float(chosen["dist"]),
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

## Calculates atmospheric air absorption high-frequency cutoff over distance.
## Uses exponential decay: cutoff = clamp(20000 * exp(-0.015 * distance), 800, 20000)
func calculate_air_absorption(distance: float) -> float:
	var safe_d: float = maxf(0.0, distance)
	return clampf(20000.0 * exp(-0.015 * safe_d), 800.0, 20000.0)

## Calculates stabilized Doppler pitch factor based on relative velocity vectors.
## Clamped to safe range [0.5, 2.0].
func calculate_doppler_pitch(emitter_vel: Vector3, listener_vel: Vector3, rel_pos: Vector3, smoothing_alpha: float = 0.15) -> float:
	if rel_pos.length_squared() < 0.001:
		return 1.0
	var unit_dir: Vector3 = rel_pos.normalized() # Vector from emitter to listener
	var v_l: float = listener_vel.dot(unit_dir)
	var v_e: float = emitter_vel.dot(unit_dir)
	
	var num: float = speed_of_sound - v_l
	var denom: float = speed_of_sound - v_e
	if is_zero_approx(denom):
		denom = 0.001
	var pitch_factor: float = num / denom
	return clampf(pitch_factor, 0.5, 2.0)

## Rigorous evaluation separating Obstrucción (same room partial block, direct LPF only)
## from Oclusión (inter-room / sealed barrier, mass law + reverb damping).
func evaluate_acoustic_path(emitter_pos: Vector3, listener_pos: Vector3, emitter_room: StringName, listener_room: StringName, world_3d: World3D = null, collision_mask: int = 1) -> Dictionary:
	var mat_registry = AcousticMaterialRegistryClass.get_singleton()
	var is_same_room: bool = (emitter_room == listener_room) and not emitter_room.is_empty()
	var direct_dist: float = emitter_pos.distance_to(listener_pos)
	
	# Raycast check if world_3d is available
	var hit_obstacle: bool = false
	var obstacle_thickness: float = 0.2
	var obstacle_mat: StringName = &"Concrete"
	
	if world_3d != null:
		var space_state = world_3d.direct_space_state
		var query_fwd = PhysicsRayQueryParameters3D.create(emitter_pos, listener_pos)
		query_fwd.collision_mask = collision_mask
		query_fwd.hit_from_inside = false
		var res_fwd = space_state.intersect_ray(query_fwd)
		
		if not res_fwd.is_empty():
			hit_obstacle = true
			var hit_pos1: Vector3 = res_fwd["position"]
			if res_fwd.has("collider"):
				var col = res_fwd["collider"]
				if col.has_meta("acoustic_material"):
					obstacle_mat = StringName(str(col.get_meta("acoustic_material")))
				elif col.has_meta("surface_type"):
					obstacle_mat = StringName(str(col.get_meta("surface_type")))
			
			# Reverse raycast for thickness measurement
			var query_rev = PhysicsRayQueryParameters3D.create(listener_pos, emitter_pos)
			query_rev.collision_mask = collision_mask
			query_rev.hit_from_inside = false
			var res_rev = space_state.intersect_ray(query_rev)
			if not res_rev.is_empty():
				var hit_pos2: Vector3 = res_rev["position"]
				obstacle_thickness = maxf(0.05, hit_pos1.distance_to(hit_pos2))
	
	var loss_data = {"attenuation_db": 0.0, "cutoff_lpf": 20000.0}
	if mat_registry != null:
		loss_data = mat_registry.calculate_transmission_loss(obstacle_mat, obstacle_thickness)
	
	if is_same_room:
		if hit_obstacle:
			# OBSTRUCTION: Partial block in same room.
			# Direct sound is filtered with LPF, but room reverb is 100% untouched.
			return {
				"obstruction_factor": 0.6,
				"occlusion_factor": 0.0,
				"thickness_meters": obstacle_thickness,
				"material_name": obstacle_mat,
				"transmission_loss_db": loss_data["attenuation_db"] * 0.5,
				"direct_lpf_cutoff": minf(5000.0, loss_data["cutoff_lpf"]),
				"reverb_send_factor": 1.0 # 100% reverb intact!
			}
		else:
			# Direct line of sight
			return {
				"obstruction_factor": 0.0,
				"occlusion_factor": 0.0,
				"thickness_meters": 0.0,
				"material_name": &"None",
				"transmission_loss_db": 0.0,
				"direct_lpf_cutoff": 20000.0,
				"reverb_send_factor": 1.0
			}
	else:
		# OCCLUSION: Between different rooms or sealed.
		# Mass law attenuation applies to both direct sound and room reverb.
		var occl_factor: float = clampf(loss_data["attenuation_db"] / 24.0, 0.4, 1.0)
		var reverb_factor: float = clampf(1.0 - (loss_data["attenuation_db"] / 36.0), 0.05, 0.7)
		return {
			"obstruction_factor": 0.0,
			"occlusion_factor": occl_factor,
			"thickness_meters": obstacle_thickness,
			"material_name": obstacle_mat,
			"transmission_loss_db": loss_data["attenuation_db"],
			"direct_lpf_cutoff": loss_data["cutoff_lpf"],
			"reverb_send_factor": reverb_factor
		}
