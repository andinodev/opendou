class_name OpenDouInstanceLimiter
extends RefCounted

## Decide si una instancia nueva de un evento puede EXISTIR, antes de crearla, segun los
## limites de su definicion: por evento, por emisor y por radio. Es distinto del robo de
## voces del pool, que decide cuales SUENAN: una instancia rechazada no gasta canal, ni
## oclusion, ni camino por salas, ni tiempo logico.
##
## Las voces anonimas (sin nodo emisor) no participan del alcance por emisor, y del alcance
## por radio solo si quien postea es un Node3D con posicion.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

## Devuelve {"allow": bool, "steal": EventInstance o null}. `steal` es la instancia que hay
## que detener con fundido antes de crear la nueva.
func check(def: AudioEventDef, caller: Node, position: Vector3, has_position: bool, active: Array, listener_pos: Vector3) -> Dictionary:
	var result: Dictionary = {"allow": true, "steal": null}
	if def == null:
		return result
	if def.max_instances <= 0 and def.max_instances_per_emitter <= 0 and def.max_instances_in_radius <= 0:
		return result
	var caller_id: int = caller.get_instance_id() if caller != null else 0
	var same: Array = []
	var same_emitter: Array = []
	var near: Array = []
	# Una sola pasada: las que estan en fundido de salida no cuentan, o cada robo
	# encadenaria otro.
	for inst in active:
		if inst == null or inst.definition != def or not inst.is_playing() or inst.is_stopping():
			continue
		same.append(inst)
		if caller_id != 0 and inst.caller_id == caller_id:
			same_emitter.append(inst)
		if has_position and inst.has_spatial_position and inst.emitter_position.distance_to(position) <= def.instance_radius_m:
			near.append(inst)
	var full: Array = []
	if def.max_instances > 0 and same.size() >= def.max_instances:
		full = same
	elif def.max_instances_per_emitter > 0 and same_emitter.size() >= def.max_instances_per_emitter:
		full = same_emitter
	elif def.max_instances_in_radius > 0 and near.size() >= def.max_instances_in_radius:
		full = near
	if full.is_empty():
		return result
	if def.limit_policy == AudioEventDefClass.LimitPolicy.REJECT_NEW:
		result["allow"] = false
		return result
	result["steal"] = _pick(full, def.limit_policy, listener_pos)
	return result

func _pick(candidates: Array, policy: int, listener_pos: Vector3):
	var best = candidates[0]
	for inst in candidates:
		match policy:
			AudioEventDefClass.LimitPolicy.STEAL_OLDEST:
				if inst.elapsed_time > best.elapsed_time:
					best = inst
			AudioEventDefClass.LimitPolicy.STEAL_QUIETEST:
				if inst.calculated_volume_db < best.calculated_volume_db:
					best = inst
			AudioEventDefClass.LimitPolicy.STEAL_FARTHEST:
				var d_inst: float = inst.emitter_position.distance_to(listener_pos) if inst.has_spatial_position else 0.0
				var d_best: float = best.emitter_position.distance_to(listener_pos) if best.has_spatial_position else 0.0
				if d_inst > d_best:
					best = inst
	return best
