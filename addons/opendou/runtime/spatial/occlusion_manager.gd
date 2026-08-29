class_name OcclusionManager
extends RefCounted

## Manages dynamic physical raycast occlusion queries and target LPF filtering.

class OcclusionResult:
	var occlusion_factor: float = 0.0 # 0.0 (Unobstructed) to 1.0 (Fully Occluded)
	var target_lpf: float = 20000.0
	var volume_attenuation_db: float = 0.0

	func _init(p_factor: float = 0.0, p_lpf: float = 20000.0, p_atten_db: float = 0.0) -> void:
		occlusion_factor = p_factor
		target_lpf = p_lpf
		volume_attenuation_db = p_atten_db

var fully_occluded_lpf: float = 1500.0
var unoccluded_lpf: float = 20000.0
var max_occlusion_attenuation_db: float = -6.0
var collision_mask: int = 1

## Evaluates occlusion based on direct line-of-sight raycast hits.
## ray_hits is an array of booleans representing test ray collision results (e.g. Center, Left, Right).
func evaluate_occlusion(_emitter_pos: Vector3, _listener_pos: Vector3, ray_hits: Array[bool] = [false]) -> OcclusionResult:
	if ray_hits.is_empty():
		return OcclusionResult.new(0.0, unoccluded_lpf, 0.0)
		
	var hits_count: int = 0
	for hit in ray_hits:
		if hit:
			hits_count += 1
			
	var factor: float = float(hits_count) / float(ray_hits.size())
	var lpf: float = lerpf(unoccluded_lpf, fully_occluded_lpf, factor)
	var atten_db: float = factor * max_occlusion_attenuation_db
	
	return OcclusionResult.new(factor, lpf, atten_db)
