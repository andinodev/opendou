@tool
class_name EdgeDiffractionEngine
extends RefCounted

## Huygens-Fresnel Obstacle Edge Diffraction & Acoustic Bending Engine.
## Calculates the acoustic shadow angle, shifts perceived virtual sound origin towards free edges,
## and applies smooth high-frequency diffraction filtering around columns, barriers, and corners.

## Calculates the diffraction shadow bending angle in radians around a geometric edge.
## [param emitter_pos]: 3D origin of sound source.
## [param edge_pos]: 3D coordinate of the nearest obstacle edge.
## [param listener_pos]: 3D coordinate of the listener.
## [returns]: Shadow angle in radians [0.0 = straight line, PI = complete fold-back].
func calculate_shadow_angle(emitter_pos: Vector3, edge_pos: Vector3, listener_pos: Vector3) -> float:
	var v_in: Vector3 = (edge_pos - emitter_pos)
	var v_out: Vector3 = (listener_pos - edge_pos)
	
	if v_in.length_squared() < 0.0001 or v_out.length_squared() < 0.0001:
		return 0.0
	
	var dir_in = v_in.normalized()
	var dir_out = v_out.normalized()
	var dot_val = clampf(dir_in.dot(dir_out), -1.0, 1.0)
	return acos(dot_val)

## Calculates the diffraction lowpass filter cutoff frequency and gain multiplier using the Huygens-Fresnel model.
## [param shadow_angle_rad]: Angle in radians.
## [returns]: Dictionary with cutoff_lpf (Hz), gain (0.1 to 1.0), and shadow_angle_deg.
func calculate_diffraction_filter(shadow_angle_rad: float) -> Dictionary:
	var safe_angle: float = clampf(shadow_angle_rad, 0.0, PI)
	var half_cos: float = cos(safe_angle * 0.5)
	
	# Frequency Cutoff: f(theta) = 20000 * cos^2(theta / 2)
	var cutoff_lpf: float = clampf(20000.0 * (half_cos * half_cos), 400.0, 20000.0)
	var gain: float = clampf(half_cos, 0.1, 1.0)
	
	return {
		"cutoff_lpf": cutoff_lpf,
		"gain": gain,
		"shadow_angle_deg": rad_to_deg(safe_angle)
	}

## Finds the optimal diffraction edge on an obstacle bounding volume that minimizes detour path distance.
func find_diffraction_edge(emitter_pos: Vector3, listener_pos: Vector3, obstacle_center: Vector3, obstacle_extents: Vector3) -> Vector3:
	var sight_dir = (listener_pos - emitter_pos).normalized()
	
	# Evaluate bounding box corner vertices and lateral extremities
	var candidates: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				candidates.append(obstacle_center + Vector3(sx * obstacle_extents.x, sy * obstacle_extents.y, sz * obstacle_extents.z))
	
	# Add lateral extremities
	candidates.append(obstacle_center + Vector3(obstacle_extents.x, 0, 0))
	candidates.append(obstacle_center + Vector3(-obstacle_extents.x, 0, 0))
	candidates.append(obstacle_center + Vector3(0, obstacle_extents.y, 0))
	candidates.append(obstacle_center + Vector3(0, -obstacle_extents.y, 0))
	
	var best_edge: Vector3 = candidates[0]
	var min_detour: float = INF
	
	for cand in candidates:
		# Exclude candidates that lie directly on the front/back face along sightline
		var rel = (cand - obstacle_center)
		if rel.length_squared() > 0.001 and sight_dir.length_squared() > 0.001:
			var align = absf(rel.normalized().dot(sight_dir))
			if align > 0.9: # Axis-aligned with sightline
				continue
		
		var detour = emitter_pos.distance_to(cand) + cand.distance_to(listener_pos)
		if detour < min_detour:
			min_detour = detour
			best_edge = cand
			
	return best_edge

## Fully evaluates edge diffraction around an obstacle returning virtual perceived origin and DSP filter settings.
func evaluate_edge_diffraction(emitter_pos: Vector3, listener_pos: Vector3, obstacle_center: Vector3, obstacle_extents: Vector3) -> Dictionary:
	var edge_pos = find_diffraction_edge(emitter_pos, listener_pos, obstacle_center, obstacle_extents)
	var angle_rad = calculate_shadow_angle(emitter_pos, edge_pos, listener_pos)
	var filter = calculate_diffraction_filter(angle_rad)
	
	return {
		"edge_pos": edge_pos,
		"virtual_origin": edge_pos,
		"shadow_angle_rad": angle_rad,
		"cutoff_lpf": filter["cutoff_lpf"],
		"gain": filter["gain"],
		"shadow_angle_deg": filter["shadow_angle_deg"]
	}
