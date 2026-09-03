@icon("res://addons/opendou/icons/icon_acoustic_bake.svg")
@tool
class_name OpenDouAcousticGeometryBake
extends Node3D

## Offline Acoustic Geometry Preprocessor and CPU Raycast Engine for OpenDou.
## Pre-scans, simplifies, and bakes scene obstacle geometry into lightweight
## acoustic triangle clusters and AABBs for high-performance physics-free occlusion.

const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

# ==============================================================================
# EXPORTED CONFIGURATION
# ==============================================================================

@export_group("Scanning & Filtering")
@export var target_group: StringName = &"AcousticObstacle"
@export var scan_child_meshes: bool = true
@export var default_acoustic_material: StringName = &"Concrete"

@export_group("Mesh Simplification & BVH")
@export_range(1, 16, 1) var simplification_step: int = 1
@export var generate_bvh: bool = true
@export var auto_bake_on_ready: bool = false
## Alimentar la escena de Steam Audio al terminar el bake (Fase 12). Sin extension no hace nada.
@export var feed_steam_audio: bool = true

@export_group("Probes")
## Sondas de propagacion (Fase 14): separacion y altura sobre el suelo, dentro de probe_bounds
## (vacio = el AABB del bake). El archivo .probes se versiona junto a la escena.
@export_range(0.5, 20.0, 0.1) var probe_spacing_m: float = 2.0
@export_range(0.2, 5.0, 0.1) var probe_height_m: float = 1.5
@export var probe_bounds: AABB = AABB()
@export_file("*.probes") var probes_path: String = ""
@export var auto_load_probes: bool = true

signal probe_bake_progress(fraction: float)

# ==============================================================================
# BAKED DATA STORAGE
# ==============================================================================

var baked_triangles: Array = [] # Array[Dictionary]: v0, v1, v2, normal, center, material, mesh_name
var baked_aabbs: Array[AABB] = []
var stats: Dictionary = {
	"mesh_count": 0,
	"triangle_count": 0,
	"total_volume": 0.0
}

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	if auto_bake_on_ready and not Engine.is_editor_hint():
		bake_geometry()

# ==============================================================================
# BAKING PROCESS
# ==============================================================================

## Pre-scans and bakes all matching MeshInstance3D nodes in the scene or children.
func bake_geometry(root_node: Node = null) -> Dictionary:
	clear_baked_data()
	
	var candidate_meshes: Array[MeshInstance3D] = []
	var scan_root: Node = root_node
	if scan_root == null:
		scan_root = get_tree().current_scene if (is_inside_tree() and get_tree() and get_tree().current_scene) else self

	# 1. Collect from child hierarchy if enabled
	if scan_child_meshes and scan_root != null:
		_collect_child_meshes(scan_root, candidate_meshes)

	# 2. Collect from target group across the scene or subtree
	if not target_group.is_empty():
		if is_inside_tree() and get_tree():
			var group_nodes = get_tree().get_nodes_in_group(target_group)
			for node in group_nodes:
				if node is MeshInstance3D and not candidate_meshes.has(node):
					candidate_meshes.append(node)
				elif node is Node3D:
					_collect_child_meshes(node, candidate_meshes)
		elif scan_root != null:
			_collect_group_meshes(scan_root, target_group, candidate_meshes)

	# 3. Extract and simplify geometry
	var total_triangles: int = 0
	var total_bounds: AABB = AABB()
	var has_first_bound: bool = false

	for mesh_inst in candidate_meshes:
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
			
		var mat_name = default_acoustic_material
		if mesh_inst.has_meta(&"acoustic_material"):
			mat_name = StringName(str(mesh_inst.get_meta(&"acoustic_material")))
		elif mesh_inst.get_parent() and mesh_inst.get_parent().has_meta(&"acoustic_material"):
			mat_name = StringName(str(mesh_inst.get_parent().get_meta(&"acoustic_material")))

		var faces = mesh_inst.mesh.get_faces()
		if faces.is_empty():
			continue

		var mesh_xf = mesh_inst.global_transform if mesh_inst.is_inside_tree() else mesh_inst.transform
		var step = maxi(1, simplification_step) * 3 # Triangles are triplets

		var mesh_aabb = AABB()
		var mesh_has_first: bool = false

		for i in range(0, faces.size(), step):
			if i + 2 < faces.size():
				var v0 = mesh_xf * faces[i]
				var v1 = mesh_xf * faces[i + 1]
				var v2 = mesh_xf * faces[i + 2]
				var normal = (v1 - v0).cross(v2 - v0).normalized()
				var center = (v0 + v1 + v2) / 3.0

				baked_triangles.append({
					"v0": v0,
					"v1": v1,
					"v2": v2,
					"normal": normal,
					"center": center,
					"material": mat_name,
					"mesh_name": mesh_inst.name
				})
				total_triangles += 1

				if not mesh_has_first:
					mesh_aabb = AABB(v0, Vector3.ZERO)
					mesh_has_first = true
				mesh_aabb = mesh_aabb.expand(v0).expand(v1).expand(v2)

		if mesh_has_first:
			baked_aabbs.append(mesh_aabb)
			if not has_first_bound:
				total_bounds = mesh_aabb
				has_first_bound = true
			else:
				total_bounds = total_bounds.merge(mesh_aabb)

	stats["mesh_count"] = candidate_meshes.size()
	stats["triangle_count"] = total_triangles
	stats["total_volume"] = total_bounds.get_volume() if has_first_bound else 0.0

	if feed_steam_audio and total_triangles > 0:
		_fed_native = export_to_native()
		if _fed_native and auto_load_probes and not Engine.is_editor_hint():
			load_probes()
	return stats

func _collect_child_meshes(parent_node: Node, out_list: Array[MeshInstance3D]) -> void:
	for child in parent_node.get_children():
		if child is MeshInstance3D and not out_list.has(child):
			out_list.append(child)
		_collect_child_meshes(child, out_list)

func _collect_group_meshes(parent_node: Node, group: StringName, out_list: Array[MeshInstance3D]) -> void:
	if parent_node.is_in_group(group) and parent_node is MeshInstance3D and not out_list.has(parent_node):
		out_list.append(parent_node)
	for child in parent_node.get_children():
		_collect_group_meshes(child, group, out_list)

## Clears all currently baked geometry data and resets stats.
func clear_baked_data() -> void:
	baked_triangles.clear()
	baked_aabbs.clear()
	stats["mesh_count"] = 0
	stats["triangle_count"] = 0
	stats["total_volume"] = 0.0

## True si este bake alimento la escena nativa: al salir del arbol la limpia. La escena es
## una por proceso; si no, la geometria de una demo seguiria ocluyendo en la siguiente.
var _fed_native: bool = false

func _exit_tree() -> void:
	if _fed_native and ClassDB.class_exists("OpenDouAcousticScene"):
		ClassDB.class_call_static("OpenDouAcousticScene", "clear")
		_fed_native = false

## Ruta por defecto del archivo de sondas: la de la escena, con extension .probes.
func default_probes_path() -> String:
	if not probes_path.is_empty():
		return probes_path
	var scene_path: String = ""
	if is_inside_tree() and get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
		scene_path = get_tree().current_scene.scene_file_path
	elif owner != null and not owner.scene_file_path.is_empty():
		scene_path = owner.scene_file_path
	if scene_path.is_empty():
		return "user://%s.probes" % name
	return scene_path.get_basename() + ".probes"

## AABB del bake en mundo (union de las mallas horneadas).
func get_baked_bounds() -> AABB:
	var b := AABB()
	var first: bool = true
	for aabb in baked_aabbs:
		if first:
			b = aabb
			first = false
		else:
			b = b.merge(aabb)
	return b

## Genera las sondas sobre la escena nativa, precocina los caminos y guarda el .probes.
## Devuelve {probe_count, bytes, path}. Vacio sin extension o sin escena.
func bake_probes() -> Dictionary:
	if not ClassDB.class_exists("OpenDouAcousticScene"):
		return {}
	if not bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")) and not export_to_native():
		return {}
	probe_bake_progress.emit(0.0)
	var bounds: AABB = probe_bounds if probe_bounds.size.length() > 0.0 else get_baked_bounds()
	var n: int = int(ClassDB.class_call_static("OpenDouAcousticScene", "generate_probes", probe_spacing_m, probe_height_m, bounds))
	if n <= 0:
		probe_bake_progress.emit(1.0)
		return {}
	probe_bake_progress.emit(0.3)
	ClassDB.class_call_static("OpenDouAcousticScene", "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1)
	probe_bake_progress.emit(0.9)
	var path: String = default_probes_path()
	var ok: bool = bool(ClassDB.class_call_static("OpenDouAcousticScene", "save_probes", path))
	probe_bake_progress.emit(1.0)
	var bytes: int = FileAccess.get_file_as_bytes(path).size() if ok else 0
	return {"probe_count": n, "bytes": bytes, "path": path}

## Carga el .probes (la ruta dada, probes_path o la de la escena). false si no existe.
func load_probes(path: String = "") -> bool:
	if not ClassDB.class_exists("OpenDouAcousticScene"):
		return false
	var p: String = path if not path.is_empty() else default_probes_path()
	if not FileAccess.file_exists(p):
		return false
	return bool(ClassDB.class_call_static("OpenDouAcousticScene", "load_probes", p))

## Vertices, triangulos e indices de material aplanados, listos para la escena nativa.
func get_flat_geometry() -> Dictionary:
	var vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	var indices := PackedInt32Array()
	var names: Array[StringName] = []
	var name_to_index: Dictionary = {}
	for tri in baked_triangles:
		var mat: StringName = StringName(str(tri.get("material", default_acoustic_material)))
		if not name_to_index.has(mat):
			name_to_index[mat] = names.size()
			names.append(mat)
		for k in ["v0", "v1", "v2"]:
			triangles.append(vertices.size())
			vertices.append(tri[k])
		indices.append(int(name_to_index[mat]))
	return {"vertices": vertices, "triangles": triangles, "material_indices": indices, "material_names": names}

## Construye la escena de Steam Audio con la geometria del bake (Fase 12). false sin extension
## o sin datos. Los materiales salen del registro por banda.
func export_to_native() -> bool:
	if not ClassDB.class_exists("OpenDouAcousticScene"):
		return false
	var g: Dictionary = get_flat_geometry()
	if (g.triangles as PackedInt32Array).is_empty():
		return false
	var registry = AcousticMaterialRegistryClass.get_singleton()
	var materials: Array = []
	for n in g.material_names:
		var m = registry.get_acoustic_material(n) if registry != null else null
		if m == null:
			m = registry.get_acoustic_material(&"Concrete") if registry != null else null
		materials.append(m.to_ipl() if m != null else PackedFloat32Array([0.05, 0.07, 0.08, 0.05, 0.015, 0.002, 0.001]))
	return bool(ClassDB.class_call_static("OpenDouAcousticScene", "build", g.vertices, g.triangles, g.material_indices, materials))

func get_baked_triangle_count() -> int:
	return baked_triangles.size()

func get_baked_triangles() -> Array:
	return baked_triangles

func get_baked_aabbs() -> Array[AABB]:
	return baked_aabbs

# ==============================================================================
# CPU MÖLLER–TRUMBORE RAYCASTING
# ==============================================================================

## Casts a ray against all baked acoustic triangles and returns intersection details.
func raycast_baked_geometry(from: Vector3, to: Vector3) -> Dictionary:
	var ray_vec = to - from
	var ray_len = ray_vec.length()
	if ray_len <= 0.0001:
		return {"hit": false}

	var ray_dir = ray_vec / ray_len
	var closest_hit_dist: float = ray_len
	var hit_record: Dictionary = {"hit": false}

	for tri in baked_triangles:
		var v0: Vector3 = tri["v0"]
		var v1: Vector3 = tri["v1"]
		var v2: Vector3 = tri["v2"]

		var inter_res = _intersect_triangle(from, ray_dir, v0, v1, v2)
		if inter_res.get("hit", false):
			var t: float = inter_res.get("distance", INF)
			if t >= 0.0 and t < closest_hit_dist:
				closest_hit_dist = t
				hit_record = {
					"hit": true,
					"position": from + ray_dir * t,
					"normal": tri["normal"],
					"distance": t,
					"material": tri["material"],
					"mesh_name": tri["mesh_name"]
				}

	return hit_record

## Möller–Trumbore ray-triangle intersection.
func _intersect_triangle(orig: Vector3, dir: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> Dictionary:
	var epsilon = 0.000001
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var pvec = dir.cross(edge2)
	var det = edge1.dot(pvec)

	if absf(det) < epsilon:
		return {"hit": false}

	var inv_det = 1.0 / det
	var tvec = orig - v0
	var u = tvec.dot(pvec) * inv_det
	if u < 0.0 or u > 1.0:
		return {"hit": false}

	var qvec = tvec.cross(edge1)
	var v = dir.dot(qvec) * inv_det
	if v < 0.0 or u + v > 1.0:
		return {"hit": false}

	var t = edge2.dot(qvec) * inv_det
	if t > epsilon:
		return {"hit": true, "distance": t}

	return {"hit": false}

# ==============================================================================
# SERIALIZATION & EXPORT
# ==============================================================================

## Exports the baked triangle and volume data to a JSON dictionary.
func export_to_dict() -> Dictionary:
	return {
		"stats": stats,
		"triangles": baked_triangles,
		"aabbs": baked_aabbs
	}
