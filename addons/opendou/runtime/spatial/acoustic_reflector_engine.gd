@tool
class_name AcousticReflectorEngine
extends RefCounted

## 6x Image-Source Early Reflections Raytracer & Physical Slapback Engine.
## Probes 6 orthogonal axes (+X, -X, +Y, -Y, +Z, -Z) to simulate room acoustics, surface echo delays, and material absorption.

const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

## Speed of sound in standard atmosphere (meters / second).
var speed_of_sound: float = 343.0

## Maximum reflection search radius in meters.
var max_reflection_distance: float = 30.0

## Returns 6 orthogonal unit probe directions.
func get_orthogonal_probe_directions() -> Array[Vector3]:
	return [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.UP,
		Vector3.DOWN,
		Vector3.FORWARD,
		Vector3.BACK
	]

## Calculates the arrival time delay in seconds for an acoustic path hitting a surface and reaching the listener.
func calculate_reflection_delay(emitter_pos: Vector3, hit_pos: Vector3, listener_pos: Vector3) -> float:
	var d1: float = emitter_pos.distance_to(hit_pos)
	var d2: float = hit_pos.distance_to(listener_pos)
	return (d1 + d2) / maxf(1.0, speed_of_sound)

## Calculates the virtual mirror image source position reflected across a boundary plane.
func calculate_image_source_position(emitter_pos: Vector3, hit_pos: Vector3, hit_normal: Vector3) -> Vector3:
	var norm = hit_normal.normalized()
	var v = emitter_pos - hit_pos
	var v_proj = norm * v.dot(norm)
	return emitter_pos - (2.0 * v_proj)

## Calculates reflection gain and lowpass filter cutoff based on surface material physical properties and distance.
func calculate_surface_reflection_response(material_name: StringName, total_distance: float) -> Dictionary:
	var registry = AcousticMaterialRegistryClass.get_singleton()
	var mat = registry.get_material(material_name)
	var absorption: float = float(mat.get("absorption", 0.05))
	var res_lpf: float = float(mat.get("resonance_lpf", 350.0))
	
	var safe_dist: float = maxf(0.0, total_distance)
	var gain: float = clampf((1.0 - absorption) / sqrt(1.0 + (safe_dist / 5.0)), 0.0, 1.0)
	var dist_ratio: float = clampf(safe_dist / 20.0, 0.0, 1.0)
	var cutoff_lpf: float = lerpf(20000.0, res_lpf, dist_ratio)
	
	return {
		"gain": gain,
		"cutoff_lpf": cutoff_lpf,
		"absorption": absorption,
		"resonance_lpf": res_lpf
	}

## Executes 6-axis raytracing against the 3D physics world and returns active early reflection data.
func trace_early_reflections(emitter_pos: Vector3, listener_pos: Vector3, world_3d: World3D, collision_mask: int = 1) -> Array[Dictionary]:
	var reflections: Array[Dictionary] = []
	if world_3d == null:
		return reflections
	
	var space_state = world_3d.direct_space_state
	var dirs = get_orthogonal_probe_directions()
	
	for dir in dirs:
		var target = emitter_pos + (dir * max_reflection_distance)
		var query = PhysicsRayQueryParameters3D.create(emitter_pos, target)
		query.collision_mask = collision_mask
		query.hit_from_inside = false
		
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos: Vector3 = result["position"]
			var hit_normal: Vector3 = result["normal"]
			var mat_name: StringName = &"Concrete"
			
			if result.has("collider"):
				var col = result["collider"]
				if col.has_meta("acoustic_material"):
					mat_name = StringName(str(col.get_meta("acoustic_material")))
				elif col.has_meta("surface_type"):
					mat_name = StringName(str(col.get_meta("surface_type")))
			
			var image_pos = calculate_image_source_position(emitter_pos, hit_pos, hit_normal)
			var delay = calculate_reflection_delay(emitter_pos, hit_pos, listener_pos)
			var total_dist = emitter_pos.distance_to(hit_pos) + hit_pos.distance_to(listener_pos)
			var response = calculate_surface_reflection_response(mat_name, total_dist)
			
			reflections.append({
				"direction": dir,
				"hit_pos": hit_pos,
				"hit_normal": hit_normal,
				"image_source_pos": image_pos,
				"delay_seconds": delay,
				"gain": response["gain"],
				"cutoff_lpf": response["cutoff_lpf"],
				"material": mat_name
			})
	
	return reflections
