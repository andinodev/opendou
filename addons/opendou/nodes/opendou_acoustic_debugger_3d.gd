@icon("res://addons/opendou/icons/icon_acoustic_debugger.svg")
@tool
class_name OpenDouAcousticDebugger3D
extends Node3D

## Declarative 3D Volumetric Acoustic Sound Field Debugger for OpenDou.
## Visualizes dynamic wall-conforming sound field meshes, portal leakage paths,
## unit_size near-attenuation cores, and emitter-to-listener ray occlusion in real-time.

const SHADER_PATH = "res://addons/opendou/shaders/acoustic_sound_field.gdshader"

# ==============================================================================
# EXPORTED CONFIGURATION
# ==============================================================================

@export_group("Debugger Settings")
@export var enabled: bool = true:
	set(val):
		enabled = val
		if not enabled and _immediate_mesh != null:
			_immediate_mesh.clear_surfaces()
		set_process(enabled)

@export_range(8, 64, 4) var probe_ray_count: int = 24
@export var show_unit_size_core: bool = true
@export var show_occlusion_rays: bool = true
@export var show_sound_field_mesh: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var max_display_emitters: int = 16
@export var listener_node: Node3D = null

# ==============================================================================
# INTERNAL COMPONENTS
# ==============================================================================

var _mesh_instance: MeshInstance3D = null
var _immediate_mesh: ImmediateMesh = null
var _shader_material: ShaderMaterial = null
var _line_material: StandardMaterial3D = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_rendering_components()
	set_process(enabled)

func _setup_rendering_components() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "_AcousticFieldDebugMesh"
		add_child(_mesh_instance)
		
	if _immediate_mesh == null:
		_immediate_mesh = ImmediateMesh.new()
		_mesh_instance.mesh = _immediate_mesh
		
	if _shader_material == null:
		_shader_material = ShaderMaterial.new()
		var shader_res = load(SHADER_PATH)
		if shader_res is Shader:
			_shader_material.shader = shader_res
		_shader_material.set_shader_parameter("base_color", Color(0.1, 0.85, 1.0, 0.45))
		_shader_material.set_shader_parameter("occluded_color", Color(1.0, 0.35, 0.1, 0.45))
		_mesh_instance.material_override = _shader_material
		
	if _line_material == null:
		_line_material = StandardMaterial3D.new()
		_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_material.vertex_color_use_as_albedo = true
		_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Toggles the debugger on/off and returns the new active state.
func toggle_debug() -> bool:
	enabled = not enabled
	return enabled

## Calculates radial ray probe distances from an emitter position outward to max_dist.
## Returns an array of dictionaries: {"dir": Vector3, "dist": float, "is_hit": bool, "hit_pos": Vector3}.
func calculate_starburst_distances(emitter_pos: Vector3, ray_count: int, max_dist: float, space_state: PhysicsDirectSpaceState3D = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if ray_count <= 0:
		return results
		
	for i in range(ray_count):
		var theta: float = (float(i) / float(ray_count)) * TAU
		var dir: Vector3 = Vector3(cos(theta), 0.0, sin(theta)).normalized()
		var target_pos: Vector3 = emitter_pos + dir * max_dist
		
		var is_hit: bool = false
		var hit_dist: float = max_dist
		var final_pos: Vector3 = target_pos
		
		if space_state != null:
			var query = PhysicsRayQueryParameters3D.create(emitter_pos, target_pos, collision_mask)
			query.hit_from_inside = false
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty() and hit.has("position"):
				var h_pos: Vector3 = hit["position"]
				hit_dist = emitter_pos.distance_to(h_pos)
				final_pos = h_pos
				is_hit = true
				
		results.append({
			"dir": dir,
			"dist": hit_dist,
			"is_hit": is_hit,
			"hit_pos": final_pos
		})
		
	return results

## Evaluates direct multi-ray line of sight between an emitter and listener position.
## Returns {"hit_count": int, "color": Color, "occlusion_factor": float}.
func evaluate_listener_occlusion(emitter_pos: Vector3, listener_pos: Vector3, space_state: PhysicsDirectSpaceState3D = null) -> Dictionary:
	var hit_count: int = 0
	var total_rays: int = 3
	
	if space_state != null:
		var right_dir: Vector3 = (listener_pos - emitter_pos).cross(Vector3.UP).normalized() * 0.35
		var origins: Array[Vector3] = [
			emitter_pos,
			emitter_pos + right_dir,
			emitter_pos - right_dir
		]
		
		for orig in origins:
			var query = PhysicsRayQueryParameters3D.create(orig, listener_pos, collision_mask)
			query.hit_from_inside = false
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty():
				hit_count += 1
				
	var occ_factor: float = float(hit_count) / float(total_rays)
	var ray_color: Color = Color(0.2, 1.0, 0.3, 0.8) # Green (Clear)
	if hit_count == 3:
		ray_color = Color(1.0, 0.15, 0.15, 0.7) # Red (Fully occluded)
	elif hit_count > 0:
		ray_color = Color(1.0, 0.8, 0.1, 0.8) # Yellow (Diffracted / partial)
		
	return {
		"hit_count": hit_count,
		"color": ray_color,
		"occlusion_factor": occ_factor
	}

# ==============================================================================
# RENDERING ENGINE
# ==============================================================================

func _process(_delta: float) -> void:
	if not enabled or not is_inside_tree() or _immediate_mesh == null:
		return
		
	_render_acoustic_sound_fields()

func _render_acoustic_sound_fields() -> void:
	_immediate_mesh.clear_surfaces()
	
	var world_3d: World3D = get_world_3d()
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
	
	# Resolve listener position
	var l_pos: Vector3 = Vector3.ZERO
	var has_listener: bool = false
	if listener_node != null and is_instance_valid(listener_node) and listener_node.is_inside_tree():
		l_pos = listener_node.global_position
		has_listener = true
	else:
		var cam = get_viewport().get_camera_3d() if get_viewport() != null else null
		if cam != null and is_instance_valid(cam):
			l_pos = cam.global_position
			has_listener = true
			
	# Discover 3D audio emitters in the scene
	var emitters = _find_active_emitters()
	if emitters.is_empty():
		return
		
	var self_xform_inv: Transform3D = global_transform.affine_inverse()
	
	# Render sound field meshes
	if show_sound_field_mesh:
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _shader_material)
		for emitter in emitters:
			if not is_instance_valid(emitter) or not emitter.is_inside_tree():
				continue
			var e_pos = emitter.global_position
			var max_dist = float(emitter.get("max_distance")) if "max_distance" in emitter else 20.0
			max_dist = maxf(max_dist, 5.0)
			
			var starburst = calculate_starburst_distances(e_pos, probe_ray_count, max_dist, space_state)
			var count = starburst.size()
			if count < 3:
				continue
				
			var center_local: Vector3 = self_xform_inv * (e_pos + Vector3(0, 0.05, 0))
			var center_color: Color = Color(0.1, 0.9, 1.0, 0.5)
			
			for i in range(count):
				var p1 = starburst[i]
				var p2 = starburst[(i + 1) % count]
				
				var v1_local: Vector3 = self_xform_inv * (p1["hit_pos"] + Vector3(0, 0.05, 0))
				var v2_local: Vector3 = self_xform_inv * (p2["hit_pos"] + Vector3(0, 0.05, 0))
				
				var c1: Color = Color(1.0, 0.35, 0.1, 0.45) if p1["is_hit"] else Color(0.1, 0.85, 1.0, 0.45)
				var c2: Color = Color(1.0, 0.35, 0.1, 0.45) if p2["is_hit"] else Color(0.1, 0.85, 1.0, 0.45)
				
				# Triangle: Center -> V1 -> V2
				_immediate_mesh.surface_set_color(center_color)
				_immediate_mesh.surface_set_uv(Vector2(0.5, 0.5))
				_immediate_mesh.surface_add_vertex(center_local)
				
				_immediate_mesh.surface_set_color(c1)
				_immediate_mesh.surface_set_uv(Vector2(0.5 + p1["dir"].x * 0.5, 0.5 + p1["dir"].z * 0.5))
				_immediate_mesh.surface_add_vertex(v1_local)
				
				_immediate_mesh.surface_set_color(c2)
				_immediate_mesh.surface_set_uv(Vector2(0.5 + p2["dir"].x * 0.5, 0.5 + p2["dir"].z * 0.5))
				_immediate_mesh.surface_add_vertex(v2_local)
		_immediate_mesh.surface_end()
		
	# Render unit_size core rings and direct occlusion lines
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	for emitter in emitters:
		if not is_instance_valid(emitter) or not emitter.is_inside_tree():
			continue
		var e_pos = emitter.global_position
		
		# 1. Inner Unit Size Ring (0 dB Core)
		if show_unit_size_core:
			var unit_sz = float(emitter.get("unit_size")) if "unit_size" in emitter else 2.5
			unit_sz = maxf(unit_sz, 0.5)
			var ring_steps: int = 16
			var core_color: Color = Color(1.0, 0.85, 0.2, 0.8) # Gold
			
			for s in range(ring_steps):
				var th1 = (float(s) / float(ring_steps)) * TAU
				var th2 = (float((s + 1) % ring_steps) / float(ring_steps)) * TAU
				var pt1 = self_xform_inv * (e_pos + Vector3(cos(th1) * unit_sz, 0.1, sin(th1) * unit_sz))
				var pt2 = self_xform_inv * (e_pos + Vector3(cos(th2) * unit_sz, 0.1, sin(th2) * unit_sz))
				
				_immediate_mesh.surface_set_color(core_color)
				_immediate_mesh.surface_add_vertex(pt1)
				_immediate_mesh.surface_set_color(core_color)
				_immediate_mesh.surface_add_vertex(pt2)
				
		# 2. Emitter-to-Listener Direct Line of Sight Occlusion Ray
		if show_occlusion_rays and has_listener:
			var occ_eval = evaluate_listener_occlusion(e_pos, l_pos, space_state)
			var line_col: Color = occ_eval["color"]
			var p_start = self_xform_inv * (e_pos + Vector3(0, 0.2, 0))
			var p_end = self_xform_inv * (l_pos + Vector3(0, 0.2, 0))
			
			_immediate_mesh.surface_set_color(line_col)
			_immediate_mesh.surface_add_vertex(p_start)
			_immediate_mesh.surface_set_color(line_col)
			_immediate_mesh.surface_add_vertex(p_end)
	_immediate_mesh.surface_end()

func _find_active_emitters() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else get_parent()
	if root == null:
		return result
		
	var candidates = root.find_children("*", "AudioStreamPlayer3D", true, false)
	for cand in candidates:
		if cand is Node3D and cand.visible:
			result.append(cand)
			if result.size() >= max_display_emitters:
				break
	return result
