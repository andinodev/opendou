@tool
class_name AcousticLODController
extends RefCounted

## 4-Tier Acoustic Level of Detail (LOD) & Physics Scalability Governor.
## Manages real-time CPU throttling across 4 distance tiers:
## LOD 0 (0-10m): Full 6x early reflections, mass-law dual raycast, edge diffraction, and Doppler.
## LOD 1 (10-25m): Single-ray occlusion, simplified diffraction, air damping.
## LOD 2 (25-50m): Standard 3D panning and distance attenuation curve (no physics raytracing).
## LOD 3 (>50m): Virtualized voice culling (0 CPU physics overhead).

enum AcousticLOD {
	LOD_0_FULL = 0,
	LOD_1_MEDIUM = 1,
	LOD_2_LOW = 2,
	LOD_3_CULLED = 3
}

## Maximum distance for LOD 0 full physics processing.
var lod_0_max_distance: float = 10.0

## Maximum distance for LOD 1 medium physics processing.
var lod_1_max_distance: float = 25.0

## Maximum distance for LOD 2 low-overhead panning.
var lod_2_max_distance: float = 50.0

## Determines the appropriate Acoustic LOD tier for a given distance in meters.
func get_lod_level(distance: float) -> int:
	var safe_d = maxf(0.0, distance)
	if safe_d <= lod_0_max_distance:
		return AcousticLOD.LOD_0_FULL
	elif safe_d <= lod_1_max_distance:
		return AcousticLOD.LOD_1_MEDIUM
	elif safe_d <= lod_2_max_distance:
		return AcousticLOD.LOD_2_LOW
	else:
		return AcousticLOD.LOD_3_CULLED

## Distancia maxima a la que un LOD todavia pide oclusion por fisica. Se calcula desde las
## tablas de rasgos una vez por llamada, para que el planificador no construya un Dictionary
## por instancia y cuadro (deuda de coste, tras la Fase 10).
func physics_occlusion_max_distance() -> float:
	var best: float = 0.0
	for lod in [AcousticLOD.LOD_0_FULL, AcousticLOD.LOD_1_MEDIUM, AcousticLOD.LOD_2_LOW]:
		if bool(get_lod_features(lod).get("enable_physics_occlusion", false)):
			match lod:
				AcousticLOD.LOD_0_FULL: best = maxf(best, lod_0_max_distance)
				AcousticLOD.LOD_1_MEDIUM: best = maxf(best, lod_1_max_distance)
				AcousticLOD.LOD_2_LOW: best = maxf(best, lod_2_max_distance)
	return best

## Returns the dictionary of active feature flags for a given Acoustic LOD level.
func get_lod_features(lod_level: int) -> Dictionary:
	match lod_level:
		AcousticLOD.LOD_0_FULL:
			return {
				"enable_early_reflections": true,
				"enable_edge_diffraction": true,
				"enable_mass_law_raycast": true,
				"enable_physics_occlusion": true,
				"enable_air_damping": true,
				"enable_doppler": true,
				"is_culled": false
			}
		AcousticLOD.LOD_1_MEDIUM:
			return {
				"enable_early_reflections": false,
				"enable_edge_diffraction": true,
				"enable_mass_law_raycast": false,
				"enable_physics_occlusion": true,
				"enable_air_damping": true,
				"enable_doppler": true,
				"is_culled": false
			}
		AcousticLOD.LOD_2_LOW:
			return {
				"enable_early_reflections": false,
				"enable_edge_diffraction": false,
				"enable_mass_law_raycast": false,
				"enable_physics_occlusion": false,
				"enable_air_damping": true,
				"enable_doppler": false,
				"is_culled": false
			}
		_:
			return {
				"enable_early_reflections": false,
				"enable_edge_diffraction": false,
				"enable_mass_law_raycast": false,
				"enable_physics_occlusion": false,
				"enable_air_damping": false,
				"enable_doppler": false,
				"is_culled": true
			}

## Evaluates emitter LOD relative to listener position.
func evaluate_emitter_lod(emitter_pos: Vector3, listener_pos: Vector3) -> Dictionary:
	var dist = emitter_pos.distance_to(listener_pos)
	var lod = get_lod_level(dist)
	var feats = get_lod_features(lod)
	feats["distance"] = dist
	feats["lod_level"] = lod
	return feats
