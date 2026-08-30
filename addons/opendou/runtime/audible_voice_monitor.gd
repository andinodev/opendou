class_name AudibleVoiceMonitor
extends RefCounted

## Real-time Audible Voice Monitor and Loudness Calculation Engine for OpenDou.
## Integrates base volume, 3D distance attenuation, physical wall occlusion, and sidechain ducking.

const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

## Data structure representing telemetry and perceived loudness of an active voice.
class AudibleVoiceInfo:
	extends RefCounted
	
	var emitter_name: StringName = &""
	var event_name: StringName = &""
	var bus_category: StringName = &"SFX"
	var effective_db: float = -60.0
	var raw_volume_db: float = 0.0
	var distance_attenuation_db: float = 0.0
	var occlusion_factor: float = 0.0
	var ducking_reduction_db: float = 0.0
	var distance_meters: float = 0.0
	var is_3d: bool = false
	var priority: float = 50.0
	
	# Compatibility aliases
	var distance: float:
		get:
			return distance_meters
		set(val):
			distance_meters = val
			
	var ducking_attenuation_db: float:
		get:
			return ducking_reduction_db
		set(val):
			ducking_reduction_db = val
	
	func _init(
		p_emitter_name: StringName = &"",
		p_event_name: StringName = &"",
		p_bus_category: StringName = &"SFX",
		p_effective_db: float = -60.0,
		p_raw_volume_db: float = 0.0,
		p_distance_attenuation_db: float = 0.0,
		p_occlusion_factor: float = 0.0,
		p_ducking_reduction_db: float = 0.0,
		p_distance_meters: float = 0.0,
		p_is_3d: bool = false,
		p_priority: float = 50.0
	) -> void:
		emitter_name = p_emitter_name
		event_name = p_event_name
		bus_category = p_bus_category
		effective_db = p_effective_db
		raw_volume_db = p_raw_volume_db
		distance_attenuation_db = p_distance_attenuation_db
		occlusion_factor = p_occlusion_factor
		ducking_reduction_db = p_ducking_reduction_db
		distance_meters = p_distance_meters
		is_3d = p_is_3d
		priority = p_priority

## Calculates 3D inverse-distance attenuation in dB according to OpenDou acoustics standards.
static func calculate_distance_attenuation_db(distance: float, unit_size: float = 1.0, max_distance: float = 0.0) -> float:
	if max_distance > 0.0 and distance > max_distance:
		return -100.0
	var safe_dist: float = maxf(distance, 0.1)
	var safe_unit: float = maxf(unit_size, 0.001)
	var ratio: float = safe_unit / safe_dist
	var atten_db: float = linear_to_db(ratio)
	return clampf(atten_db, -60.0, 0.0)

## Calculates volume attenuation in dB based on physical occlusion factor [0.0, 1.0].
static func calculate_occlusion_attenuation_db(occlusion_factor: float) -> float:
	var factor: float = clampf(occlusion_factor, 0.0, 1.0)
	return factor * -6.0

## Collects all actively audible voices at the given listener position and ranks them from loudest to quietest.
static func collect_audible_voices(
	tree: SceneTree,
	listener_pos: Vector3 = Vector3.ZERO,
	ducking_matrix: RefCounted = null,
	min_db_threshold: float = -60.0
) -> Array[AudibleVoiceInfo]:
	var result: Array[AudibleVoiceInfo] = []
	var processed_instances: Dictionary = {}
	var processed_nodes: Dictionary = {}
	
	# 1. Inspect AudioEventManager instances
	var managers: Array[AudioEventManager] = _find_managers(tree)
	for manager in managers:
		for inst in manager.active_instances:
			if not inst or not inst.has_method("is_playing") or not inst.is_playing():
				continue
				
			processed_instances[inst] = true
			
			var caller_node: Node = null
			var emitter_name: StringName = &""
			if inst.caller_node_ref:
				var ref = inst.caller_node_ref.get_ref()
				if ref is Node:
					caller_node = ref
					emitter_name = caller_node.name
					processed_nodes[caller_node] = true
					
			if emitter_name.is_empty():
				emitter_name = inst.definition.event_name if inst.definition else &"EventInstance"
				
			var ev_name: StringName = inst.definition.event_name if inst.definition else &"Unknown"
			var bus_cat: StringName = inst.definition.target_bus if (inst.definition and not inst.definition.target_bus.is_empty()) else &"SFX"
			var raw_vol: float = inst.calculated_volume_db if "calculated_volume_db" in inst else 0.0
			var prio: float = inst.definition.base_priority if inst.definition else 50.0
			var is_3d: bool = inst.has_spatial_position
			
			var dist: float = 0.0
			var dist_atten: float = 0.0
			if is_3d:
				dist = inst.emitter_position.distance_to(listener_pos)
				dist_atten = calculate_distance_attenuation_db(dist, 1.0, inst.max_distance)
				
			var occl_factor: float = 0.0
			if caller_node and caller_node.has_method("get_calculated_occlusion"):
				occl_factor = caller_node.get_calculated_occlusion()
			elif inst.occlusion_attenuation_db != 0.0:
				occl_factor = clampf(inst.occlusion_attenuation_db / -6.0, 0.0, 1.0)
				
			var occl_atten: float = calculate_occlusion_attenuation_db(occl_factor)
			
			var duck_atten: float = 0.0
			if ducking_matrix and ducking_matrix.has_method("get_ducking_attenuation_db"):
				duck_atten = ducking_matrix.get_ducking_attenuation_db(bus_cat)
				
			var eff_db: float = raw_vol + dist_atten + occl_atten + duck_atten
			
			if eff_db >= min_db_threshold:
				result.append(AudibleVoiceInfo.new(
					emitter_name,
					ev_name,
					bus_cat,
					eff_db,
					raw_vol,
					dist_atten,
					occl_factor,
					duck_atten,
					dist,
					is_3d,
					prio
				))
				
	# 2. Inspect active scene tree audio emitter nodes
	if tree != null and tree.root != null:
		var audio_nodes: Array[Node] = []
		_gather_audio_nodes(tree.root, audio_nodes)
		
		for node in audio_nodes:
			if processed_nodes.has(node):
				continue
				
			var is_playing: bool = false
			if node.has_method("is_playing"):
				is_playing = node.is_playing()
			elif "active_instance" in node and node.active_instance != null:
				if processed_instances.has(node.active_instance):
					continue
				is_playing = node.active_instance.is_playing()
			elif "playing" in node:
				is_playing = bool(node.playing)
				
			if not is_playing:
				continue
				
			processed_nodes[node] = true
			
			var emitter_name: StringName = node.name
			var ev_name: StringName = node.name
			if "event_name" in node and not StringName(node.event_name).is_empty():
				ev_name = StringName(node.event_name)
			elif "stream" in node and node.stream != null and not node.stream.resource_path.is_empty():
				ev_name = StringName(node.stream.resource_path.get_file().get_basename())
				
			var bus_cat: StringName = &"SFX"
			if "bus_category" in node and not str(node.bus_category).is_empty():
				bus_cat = StringName(node.bus_category)
			elif "bus" in node and not StringName(node.bus).is_empty():
				bus_cat = StringName(node.bus)
				
			var raw_vol: float = node.volume_db if "volume_db" in node else 0.0
			var prio: float = node.base_priority if "base_priority" in node else 50.0
			var is_3d: bool = (node is Node3D or node is AudioStreamPlayer3D)
			
			var dist: float = 0.0
			var dist_atten: float = 0.0
			if is_3d:
				var node_3d = node as Node3D
				var pos_3d: Vector3 = node_3d.global_position if node_3d and node_3d.is_inside_tree() else (node_3d.position if node_3d else Vector3.ZERO)
				dist = pos_3d.distance_to(listener_pos)
				
				var unit_sz: float = node.unit_size if "unit_size" in node else 1.0
				var max_d: float = node.max_distance if "max_distance" in node else (node.cull_distance if "cull_distance" in node else 0.0)
				dist_atten = calculate_distance_attenuation_db(dist, unit_sz, max_d)
			elif node is Node2D:
				var node_2d = node as Node2D
				var pos_2d: Vector2 = node_2d.global_position if node_2d.is_inside_tree() else node_2d.position
				dist = Vector3(pos_2d.x, pos_2d.y, 0.0).distance_to(listener_pos)
				
			var occl_factor: float = 0.0
			if node.has_method("get_calculated_occlusion"):
				occl_factor = node.get_calculated_occlusion()
			var occl_atten: float = calculate_occlusion_attenuation_db(occl_factor)
			
			var duck_atten: float = 0.0
			if ducking_matrix and ducking_matrix.has_method("get_ducking_attenuation_db"):
				duck_atten = ducking_matrix.get_ducking_attenuation_db(bus_cat)
				
			var eff_db: float = raw_vol + dist_atten + occl_atten + duck_atten
			
			if eff_db >= min_db_threshold:
				result.append(AudibleVoiceInfo.new(
					emitter_name,
					ev_name,
					bus_cat,
					eff_db,
					raw_vol,
					dist_atten,
					occl_factor,
					duck_atten,
					dist,
					is_3d,
					prio
				))
				
	# 3. Sort voices in descending order of effective perceived loudness (highest dB at index 0)
	result.sort_custom(func(a: AudibleVoiceInfo, b: AudibleVoiceInfo) -> bool:
		return a.effective_db > b.effective_db
	)
	
	return result

# ==============================================================================
# INTERNAL RECURSIVE HELPERS
# ==============================================================================

static func _find_managers(tree: SceneTree) -> Array[AudioEventManager]:
	var list: Array[AudioEventManager] = []
	if Engine.has_singleton("OpenDou"):
		var s = Engine.get_singleton("OpenDou")
		if s is AudioEventManager and not list.has(s):
			list.append(s)
			
	if tree != null and tree.root != null:
		if tree.root.has_node("OpenDou"):
			var n = tree.root.get_node("OpenDou")
			if n is AudioEventManager and not list.has(n):
				list.append(n)
		_find_managers_recursive(tree.root, list)
	return list

static func _find_managers_recursive(node: Node, out_list: Array[AudioEventManager]) -> void:
	if not node:
		return
	if node is AudioEventManager and not out_list.has(node):
		out_list.append(node)
	for child in node.get_children():
		_find_managers_recursive(child, out_list)

static func _gather_audio_nodes(node: Node, out_nodes: Array[Node]) -> void:
	if not node:
		return
	if node is AudioStreamPlayer3D or node is AudioStreamPlayer2D or node is AudioStreamPlayer:
		out_nodes.append(node)
	elif node.has_method("play_event") or node.has_method("get_calculated_occlusion"):
		out_nodes.append(node)
		
	for child in node.get_children():
		_gather_audio_nodes(child, out_nodes)
