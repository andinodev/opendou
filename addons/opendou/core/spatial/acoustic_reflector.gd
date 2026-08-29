@tool
class_name AcousticReflector
extends RefCounted

## Calculates 1st and 2nd order specular early reflections off 3D room geometries.

const SPEED_OF_SOUND: float = 343.0 # meters / second

class ReflectionPath:
	var order: int = 1
	var surface_normal: Vector3
	var hit_point: Vector3
	var virtual_source_pos: Vector3
	var total_distance: float = 0.0
	var delay_sec: float = 0.0
	var delay_ms: float = 0.0
	var gain_linear: float = 1.0
	var gain_db: float = 0.0
	var direction_to_listener: Vector3
	var lpf_cutoff_hz: float = 20000.0

## Calculates specular reflection paths from a source position to a listener within a bounding room box.
static func calculate_box_reflections(source_pos: Vector3, listener_pos: Vector3, room_min: Vector3, room_max: Vector3, wall_absorption: float = 0.15) -> Array[ReflectionPath]:
	var direct_dist = source_pos.distance_to(listener_pos)
	var paths: Array[ReflectionPath] = []
	
	# 6 Primary Wall Planes (Left, Right, Floor, Ceiling, Front, Back)
	var planes = [
		{ "normal": Vector3(1, 0, 0), "point": Vector3(room_min.x, source_pos.y, source_pos.z) },  # -X (Left)
		{ "normal": Vector3(-1, 0, 0), "point": Vector3(room_max.x, source_pos.y, source_pos.z) }, # +X (Right)
		{ "normal": Vector3(0, 1, 0), "point": Vector3(source_pos.x, room_min.y, source_pos.z) },  # -Y (Floor)
		{ "normal": Vector3(0, -1, 0), "point": Vector3(source_pos.x, room_max.y, source_pos.z) }, # +Y (Ceiling)
		{ "normal": Vector3(0, 0, 1), "point": Vector3(source_pos.x, source_pos.y, room_min.z) },  # -Z (Back)
		{ "normal": Vector3(0, 0, -1), "point": Vector3(source_pos.x, source_pos.y, room_max.z) }  # +Z (Front)
	]
	
	for p in planes:
		var n: Vector3 = p["normal"]
		var pt: Vector3 = p["point"]
		
		# Compute image source position mirrored across plane
		var dist_to_plane = (source_pos - pt).dot(n)
		var image_source = source_pos - 2.0 * dist_to_plane * n
		
		# Reflection ray from image source to listener
		var refl_dist = image_source.distance_to(listener_pos)
		if refl_dist > direct_dist and refl_dist <= 80.0:
			var path = ReflectionPath.new()
			path.order = 1
			path.surface_normal = n
			path.virtual_source_pos = image_source
			path.total_distance = refl_dist
			
			# Delay relative to direct sound arrival
			path.delay_sec = maxf((refl_dist - direct_dist) / SPEED_OF_SOUND, 0.0)
			path.delay_ms = path.delay_sec * 1000.0
			
			# Energy decay (1/distance + surface absorption loss)
			var dist_atten = direct_dist / maxf(refl_dist, 0.1)
			path.gain_linear = clampf(dist_atten * (1.0 - wall_absorption), 0.0, 1.0)
			path.gain_db = linear_to_db(maxf(path.gain_linear, 0.0001))
			
			path.direction_to_listener = (listener_pos - image_source).normalized()
			path.lpf_cutoff_hz = lerpf(20000.0, 4000.0, wall_absorption)
			
			paths.append(path)
			
	# Sort by arrival time (earliest reflections first)
	paths.sort_custom(func(a, b): return a.delay_sec < b.delay_sec)
	return paths
