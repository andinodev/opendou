@tool
class_name OpenDouGizmoPlugin3D
extends EditorNode3DGizmoPlugin

## Viewport 3D Gizmo Renderer for OpenDou Spatial Audio Nodes.
## Renders acoustic volumes, normal vectors, diffraction paths, and multi-point constellations.

const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const OpenDouPortal3DClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")
const OpenDouReflector3DClass = preload("res://addons/opendou/nodes/opendou_reflector_3d.gd")
const OpenDouSplineEmitter3DClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
const OpenDouGranularEmitter3DClass = preload("res://addons/opendou/nodes/opendou_granular_emitter_3d.gd")
const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")
const OpenDouAcousticGeometryBakeClass = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _init() -> void:
	create_material("room_mat", Color(0.3, 0.8, 0.3, 0.9))
	create_material("portal_mat", Color(1.0, 0.7, 0.0, 0.9))
	create_material("reflector_mat", Color(0.0, 0.8, 0.9, 0.9))
	create_material("spline_mat", Color(0.0, 0.9, 1.0, 0.9))
	create_material("granular_mat", Color(0.7, 0.3, 0.8, 0.9))
	create_material("param_area_mat", Color(0.15, 0.7, 0.6, 0.9))
	create_material("multi_pos_mat", Color(0.25, 0.65, 1.0, 0.9))
	create_material("bake_mat", Color(1.0, 0.6, 0.1, 0.9))

func _get_gizmo_name() -> String:
	return "OpenDouSpatialGizmos"

static func is_supported_spatial_node(for_node_3d: Node3D) -> bool:
	if for_node_3d == null:
		return false
	return (for_node_3d is OpenDouRoom3DClass or
		for_node_3d is OpenDouPortal3DClass or
		for_node_3d is OpenDouReflector3DClass or
		for_node_3d is OpenDouSplineEmitter3DClass or
		for_node_3d is OpenDouGranularEmitter3DClass or
		for_node_3d is OpenDouParameterArea3DClass or
		for_node_3d is OpenDouMultiPositionEmitter3DClass or
		for_node_3d is OpenDouAcousticGeometryBakeClass)

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return is_supported_spatial_node(for_node_3d)

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node = gizmo.get_node_3d()
	if node == null:
		return

	if node is OpenDouRoom3DClass:
		_draw_room_gizmo(gizmo, node)
	elif node is OpenDouPortal3DClass:
		_draw_portal_gizmo(gizmo, node)
	elif node is OpenDouReflector3DClass:
		_draw_reflector_gizmo(gizmo, node)
	elif node is OpenDouSplineEmitter3DClass:
		_draw_spline_gizmo(gizmo, node)
	elif node is OpenDouGranularEmitter3DClass:
		_draw_granular_gizmo(gizmo, node)
	elif node is OpenDouParameterArea3DClass:
		_draw_param_area_gizmo(gizmo, node)
	elif node is OpenDouMultiPositionEmitter3DClass:
		_draw_multi_pos_gizmo(gizmo, node)
	elif node is OpenDouAcousticGeometryBakeClass:
		_draw_bake_gizmo(gizmo, node)

# ==============================================================================
# GIZMO DRAWING HELPERS
# ==============================================================================

func _draw_room_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("room_mat", gizmo)
	var extents = Vector3(5, 3, 5)
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null and child.shape is BoxShape3D:
			extents = child.shape.size * 0.5
			break
	var lines = _generate_box_lines(Vector3.ZERO, extents)
	gizmo.add_lines(lines, mat)

func _draw_portal_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("portal_mat", gizmo)
	var half_w = float(node.get("portal_width")) * 0.5 if "portal_width" in node else 1.0
	var half_h = float(node.get("portal_height")) * 0.5 if "portal_height" in node else 1.5
	var lines = PackedVector3Array([
		Vector3(-half_w, -half_h, 0), Vector3(half_w, -half_h, 0),
		Vector3(half_w, -half_h, 0), Vector3(half_w, half_h, 0),
		Vector3(half_w, half_h, 0), Vector3(-half_w, half_h, 0),
		Vector3(-half_w, half_h, 0), Vector3(-half_w, -half_h, 0),
		# Normal direction arrow
		Vector3(0, 0, 0), Vector3(0, 0, 1.0),
		Vector3(0, 0, 1.0), Vector3(0.15, 0, 0.8),
		Vector3(0, 0, 1.0), Vector3(-0.15, 0, 0.8)
	])
	gizmo.add_lines(lines, mat)

func _draw_reflector_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("reflector_mat", gizmo)
	var s = 2.0
	var lines = PackedVector3Array([
		Vector3(-s, -s, 0), Vector3(s, -s, 0),
		Vector3(s, -s, 0), Vector3(s, s, 0),
		Vector3(s, s, 0), Vector3(-s, s, 0),
		Vector3(-s, s, 0), Vector3(-s, -s, 0),
		Vector3(0, 0, 0), Vector3(0, 0, 1.2)
	])
	gizmo.add_lines(lines, mat)

func _draw_spline_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("spline_mat", gizmo)
	var curve: Curve3D = node.get("spline_curve") if "spline_curve" in node else null
	if curve == null or curve.point_count < 2:
		var fallback_lines = PackedVector3Array([Vector3(-2, 0, 0), Vector3(2, 0, 0)])
		gizmo.add_lines(fallback_lines, mat)
		return
	var lines = PackedVector3Array()
	var baked = curve.get_baked_points()
	for i in range(baked.size() - 1):
		lines.append(baked[i])
		lines.append(baked[i + 1])
	gizmo.add_lines(lines, mat)

func _draw_granular_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("granular_mat", gizmo)
	var r = float(node.get("emission_radius")) if "emission_radius" in node else 3.0
	var lines = _generate_circle_lines(Vector3.ZERO, r, Vector3.UP)
	lines.append_array(_generate_circle_lines(Vector3.ZERO, r, Vector3.RIGHT))
	gizmo.add_lines(lines, mat)

func _draw_param_area_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("param_area_mat", gizmo)
	var lines = _generate_circle_lines(Vector3.ZERO, 5.0, Vector3.UP)
	var grad_axis: Vector3 = node.get("gradient_axis") if "gradient_axis" in node else Vector3.UP
	lines.append(Vector3.ZERO)
	lines.append(grad_axis.normalized() * 5.0)
	gizmo.add_lines(lines, mat)

func _draw_multi_pos_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("multi_pos_mat", gizmo)
	var points = node.get("emission_points") if "emission_points" in node else []
	if points is Array and points.size() > 1:
		var lines = PackedVector3Array()
		for i in range(points.size()):
			var p0 = points[i]
			var p1 = points[(i + 1) % points.size()]
			lines.append(p0)
			lines.append(p1)
			# Small cross at each vertex
			lines.append(p0 - Vector3(0.3, 0, 0))
			lines.append(p0 + Vector3(0.3, 0, 0))
			lines.append(p0 - Vector3(0, 0.3, 0))
			lines.append(p0 + Vector3(0, 0.3, 0))
		gizmo.add_lines(lines, mat)

func _draw_bake_gizmo(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var mat = get_material("bake_mat", gizmo)
	var triangles = node.get("baked_triangles") if "baked_triangles" in node else []
	if triangles is Array and not triangles.is_empty():
		var lines = PackedVector3Array()
		var node_xf = node.global_transform.affine_inverse()
		var max_draw = mini(triangles.size(), 300) # Cap viewport lines for smooth fps
		for i in range(max_draw):
			var tri = triangles[i]
			var v0 = node_xf * tri["v0"]
			var v1 = node_xf * tri["v1"]
			var v2 = node_xf * tri["v2"]
			lines.append(v0)
			lines.append(v1)
			lines.append(v1)
			lines.append(v2)
			lines.append(v2)
			lines.append(v0)
		gizmo.add_lines(lines, mat)

# ==============================================================================
# GEOMETRY LINE GENERATION MATH
# ==============================================================================

func _generate_box_lines(center: Vector3, extents: Vector3) -> PackedVector3Array:
	var min_p = center - extents
	var max_p = center + extents
	return PackedVector3Array([
		Vector3(min_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, min_p.y, max_p.z),
		Vector3(max_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, max_p.z),
		Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, min_p.y, min_p.z),

		Vector3(min_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z),
		Vector3(max_p.x, max_p.y, min_p.z), Vector3(max_p.x, max_p.y, max_p.z),
		Vector3(max_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z),
		Vector3(min_p.x, max_p.y, max_p.z), Vector3(min_p.x, max_p.y, min_p.z),

		Vector3(min_p.x, min_p.y, min_p.z), Vector3(min_p.x, max_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, min_p.z), Vector3(max_p.x, max_p.y, min_p.z),
		Vector3(max_p.x, min_p.y, max_p.z), Vector3(max_p.x, max_p.y, max_p.z),
		Vector3(min_p.x, min_p.y, max_p.z), Vector3(min_p.x, max_p.y, max_p.z)
	])

func _generate_circle_lines(center: Vector3, radius: float, normal: Vector3, segments: int = 24) -> PackedVector3Array:
	var lines = PackedVector3Array()
	var u = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var v = normal.cross(u).normalized()
	u = v.cross(normal).normalized()
	var step = TAU / float(segments)
	for i in range(segments):
		var a0 = float(i) * step
		var a1 = float(i + 1) * step
		var p0 = center + (u * cos(a0) + v * sin(a0)) * radius
		var p1 = center + (u * cos(a1) + v * sin(a1)) * radius
		lines.append(p0)
		lines.append(p1)
	return lines
