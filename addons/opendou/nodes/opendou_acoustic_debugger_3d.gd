@icon("res://addons/opendou/icons/icon_acoustic_debugger.svg")
@tool
class_name OpenDouAcousticDebugger3D
extends Node3D

## Declarative 3D Volumetric Acoustic Sound Field Debugger for OpenDou.
## Visualizes dynamic wall-conforming 3D geodesic iso-bubble sound field meshes, portal leakage paths,
## unit_size near-attenuation cores, and emitter-to-listener ray occlusion in real-time.

const SHADER_PATH = "res://addons/opendou/shaders/acoustic_sound_field.gdshader"

enum DisplayMode {
	ONLY_SELECTED = 0,
	ACTIVE_AUDIBLE_ONLY = 1,
	ALL_EMITTERS = 2
}

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

@export var show_in_editor: bool = false
@export_enum("Only_Selected", "Active_Audible_Only", "All_Emitters") var display_mode: int = 0
@export var selected_emitters: Array[NodePath] = []
@export_range(4, 16, 1) var sphere_rings: int = 8
@export_range(6, 32, 2) var sphere_segments: int = 16
@export_range(8, 64, 4) var probe_ray_count: int = 24
@export var show_unit_size_core: bool = true
@export var show_occlusion_rays: bool = true
@export var show_sound_field_mesh: bool = true
## Fase 14: dibuja los segmentos de camino reales de Steam Audio (sondas) en verde. Sin
## extension no dibuja nada y no da error.
@export var show_paths: bool = true:
	set(v):
		show_paths = v
		_sync_path_visualization()
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
var _path_segment_count: int = 0

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_rendering_components()
	set_process(enabled)
	_sync_path_visualization()

func _exit_tree() -> void:
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "set_path_visualization", false)

## El simulador solo acumula segmentos cuando alguien los quiere ver.
func _sync_path_visualization() -> void:
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "set_path_visualization", show_paths and enabled and is_inside_tree())

## Segmentos de camino dibujados en el ultimo cuadro (0 sin extension o sin caminos).
func path_segment_count() -> int:
	return _path_segment_count

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

## Generates a 3D spherical / geodesic distribution of normalized ray probe directions.
## Includes North Pole (0, 1, 0), South Pole (0, -1, 0), and latitude ring samples.
func generate_sphere_probe_directions(rings: int = 8, segments: int = 16) -> Array[Vector3]:
	var dirs: Array[Vector3] = []
	if rings <= 0 or segments <= 0:
		return dirs
		
	# North Pole
	dirs.append(Vector3.UP)
	
	# Intermediate latitude rings (from phi = PI/rings to (rings-1)*PI/rings)
	for r in range(1, rings):
		var phi: float = (float(r) / float(rings)) * PI
		var sin_phi: float = sin(phi)
		var cos_phi: float = cos(phi)
		
		for s in range(segments):
			var theta: float = (float(s) / float(segments)) * TAU
			var dir: Vector3 = Vector3(
				sin_phi * cos(theta),
				cos_phi,
				sin_phi * sin(theta)
			).normalized()
			dirs.append(dir)
			
	# South Pole
	dirs.append(Vector3.DOWN)
	
	return dirs

## Calculates a 3D volumetric iso-bubble mesh with collision ray probing.
## Collisions truncate the mesh surface and color vertices with occluded_color (Orange/Red).
## Returns a Dictionary with "vertices", "normals", "colors", and "indices".
func calculate_spherical_bubble_mesh(
	emitter_pos: Vector3,
	max_dist: float,
	space_state: PhysicsDirectSpaceState3D = null,
	rings: int = 8,
	segments: int = 16
) -> Dictionary:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	
	if rings <= 0 or segments <= 0 or max_dist <= 0.0:
		return {
			"vertices": vertices,
			"normals": normals,
			"colors": colors,
			"indices": indices
		}
		
	var dirs = generate_sphere_probe_directions(rings, segments)
	var dir_count = dirs.size()
	if dir_count == 0:
		return {
			"vertices": vertices,
			"normals": normals,
			"colors": colors,
			"indices": indices
		}
		
	var col_clear: Color = Color(0.1, 0.85, 1.0, 0.45)
	var col_occluded: Color = Color(1.0, 0.35, 0.1, 0.45)
	
	# Compute vertex positions, normals and colors
	for dir in dirs:
		var target_pos: Vector3 = emitter_pos + dir * max_dist
		var final_pos: Vector3 = target_pos
		var vert_col: Color = col_clear
		
		if space_state != null:
			var query = PhysicsRayQueryParameters3D.create(emitter_pos, target_pos, collision_mask)
			query.hit_from_inside = false
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty() and hit.has("position"):
				final_pos = hit["position"]
				vert_col = col_occluded
				
		vertices.append(final_pos)
		normals.append(dir)
		colors.append(vert_col)
		
	# Compute triangular indices connecting the spherical grid
	# Index 0: North Pole
	# Ring r (r in 1..rings-1): starts at 1 + (r - 1) * segments
	# Index dir_count - 1: South Pole
	
	# 1. North Pole cap triangles (r = 1)
	for s in range(segments):
		var s_next = (s + 1) % segments
		var v0 = 0
		var v1 = 1 + s
		var v2 = 1 + s_next
		indices.append(v0)
		indices.append(v2)
		indices.append(v1)
		
	# 2. Intermediate ring quads (r = 1 to rings - 2)
	for r in range(1, rings - 1):
		var r_start = 1 + (r - 1) * segments
		var next_start = 1 + r * segments
		for s in range(segments):
			var s_next = (s + 1) % segments
			var tl = r_start + s
			var tr = r_start + s_next
			var bl = next_start + s
			var br = next_start + s_next
			
			# Triangle 1
			indices.append(tl)
			indices.append(br)
			indices.append(tr)
			
			# Triangle 2
			indices.append(tl)
			indices.append(bl)
			indices.append(br)
			
	# 3. South Pole cap triangles (r = rings - 1)
	var bot_idx = dir_count - 1
	var last_ring_start = 1 + (rings - 2) * segments
	for s in range(segments):
		var s_next = (s + 1) % segments
		var v1 = last_ring_start + s
		var v2 = last_ring_start + s_next
		indices.append(bot_idx)
		indices.append(v1)
		indices.append(v2)
		
	return {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices
	}

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
	_render_paths()
	
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
	var emitters = _get_emitters_to_render()
	if emitters.is_empty():
		return
		
	var self_xform_inv: Transform3D = global_transform.affine_inverse()
	
	# Render 3D volumetric sound field bubble meshes
	if show_sound_field_mesh:
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _shader_material)
		for emitter in emitters:
			if not is_instance_valid(emitter) or not emitter.is_inside_tree():
				continue
			var e_pos = emitter.global_position
			var max_dist = float(emitter.get("max_distance")) if "max_distance" in emitter else 20.0
			max_dist = maxf(max_dist, 5.0)
			
			var bubble = calculate_spherical_bubble_mesh(e_pos, max_dist, space_state, sphere_rings, sphere_segments)
			var vertices: PackedVector3Array = bubble.get("vertices", PackedVector3Array())
			var normals: PackedVector3Array = bubble.get("normals", PackedVector3Array())
			var colors: PackedColorArray = bubble.get("colors", PackedColorArray())
			var indices: PackedInt32Array = bubble.get("indices", PackedInt32Array())
			
			var vert_count = vertices.size()
			if not indices.is_empty() and vert_count > 0:
				for idx in indices:
					if idx >= 0 and idx < vert_count:
						var local_v: Vector3 = self_xform_inv * vertices[idx]
						var local_n: Vector3 = (self_xform_inv.basis * normals[idx]).normalized() if idx < normals.size() else Vector3.UP
						var c: Color = colors[idx] if idx < colors.size() else Color(0.1, 0.85, 1.0, 0.45)
						
						_immediate_mesh.surface_set_normal(local_n)
						_immediate_mesh.surface_set_color(c)
						_immediate_mesh.surface_add_vertex(local_v)
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

## Caminos de Steam Audio (Fase 14): pares (desde, hasta) en mundo, del ultimo RunPathing.
func _render_paths() -> void:
	_path_segment_count = 0
	if not show_paths or not ClassDB.class_exists("OpenDouSimulator"):
		return
	var segs: PackedVector3Array = ClassDB.class_call_static("OpenDouSimulator", "get_path_segments")
	if segs.size() < 2:
		return
	var inv: Transform3D = global_transform.affine_inverse()
	var col := Color(0.2, 1.0, 0.3, 0.9)
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	for i in range(0, segs.size() - 1, 2):
		_immediate_mesh.surface_set_color(col)
		_immediate_mesh.surface_add_vertex(inv * (segs[i] + Vector3(0, 0.05, 0)))
		_immediate_mesh.surface_set_color(col)
		_immediate_mesh.surface_add_vertex(inv * (segs[i + 1] + Vector3(0, 0.05, 0)))
		_path_segment_count += 1
	_immediate_mesh.surface_end()

## Resolves the list of active AudioStreamPlayer3D emitters to render based on display_mode and selection.
func _get_emitters_to_render() -> Array[Node3D]:
	var result: Array[Node3D] = []
	
	# In editor, if show_in_editor is disabled, return immediately
	if Engine.is_editor_hint() and not show_in_editor:
		return result
		
	var all_emitters = _find_all_scene_emitters()
	if all_emitters.is_empty():
		return result
		
	match display_mode:
		DisplayMode.ONLY_SELECTED: # 0
			var explicit_found: Array[Node3D] = []
			
			# 1. Try selected_emitters NodePaths
			for path in selected_emitters:
				if path.is_empty():
					continue
				var node = get_node_or_null(path)
				if node == null and get_parent() != null and not path.is_absolute():
					node = get_parent().get_node_or_null(path)
				if node == null:
					var p_str = String(path)
					for em in all_emitters:
						if em.name == p_str or String(em.name) == p_str.get_file():
							node = em
							break
				if node is Node3D and node.visible:
					if not explicit_found.has(node):
						explicit_found.append(node)
						
			# 2. In editor, check EditorInterface selection
			if Engine.is_editor_hint() and explicit_found.is_empty():
				if ClassDB.class_exists("EditorInterface"):
					var ei = Engine.get_singleton("EditorInterface") if Engine.has_singleton("EditorInterface") else null
					if ei != null:
						var selection = ei.get_selection()
						if selection != null:
							for sel_node in selection.get_selected_nodes():
								if sel_node is Node3D and all_emitters.has(sel_node):
									if not explicit_found.has(sel_node):
										explicit_found.append(sel_node)
										
			# 3. If in runtime and no explicit selection was provided, fall back to closest playing emitter
			if not Engine.is_editor_hint() and explicit_found.is_empty() and selected_emitters.is_empty():
				var ref_pos = global_position
				if listener_node != null and is_instance_valid(listener_node) and listener_node.is_inside_tree():
					ref_pos = listener_node.global_position
				var closest_emitter: Node3D = null
				var min_dist: float = INF
				for emitter in all_emitters:
					var is_playing = bool(emitter.get("playing")) if "playing" in emitter else false
					if is_playing:
						var d = ref_pos.distance_squared_to(emitter.global_position)
						if d < min_dist:
							min_dist = d
							closest_emitter = emitter
				if closest_emitter != null:
					explicit_found.append(closest_emitter)
				elif not all_emitters.is_empty():
					explicit_found.append(all_emitters[0])
					
			result = explicit_found
			
		DisplayMode.ACTIVE_AUDIBLE_ONLY: # 1
			for emitter in all_emitters:
				if _is_emitter_playing(emitter):
					result.append(emitter)
					
		DisplayMode.ALL_EMITTERS: # 2
			result = all_emitters
			
		_:
			result = all_emitters
			
	if result.size() > max_display_emitters:
		result = result.slice(0, max_display_emitters)
		
	return result

func _is_emitter_playing(emitter: Node3D) -> bool:
	if emitter == null:
		return false
	if emitter.has_meta("playing"):
		return bool(emitter.get_meta("playing"))
	if "playing" in emitter:
		return bool(emitter.get("playing"))
	if emitter.has_method("is_playing"):
		return emitter.call("is_playing")
	return false

func _find_all_scene_emitters() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root: Node = null
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		root = get_tree().current_scene
	elif get_parent() != null:
		root = get_parent()
		
	if root == null:
		return result
		
	var candidates = root.find_children("*", "AudioStreamPlayer3D", true, false)
	for cand in candidates:
		if cand is Node3D and cand.visible:
			result.append(cand)
	return result

func _find_active_emitters() -> Array[Node3D]:
	return _get_emitters_to_render()

