@tool
class_name OpenDouAcousticGeometryBakeInspectorPlugin
extends EditorInspectorPlugin

## Custom Inspector Plugin for OpenDouAcousticGeometryBake.
## Injects Bake / Clear actions and live statistics into the Godot Inspector.

const OpenDouAcousticGeometryBakeClass = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func is_supported_bake_node(object: Object) -> bool:
	return object is OpenDouAcousticGeometryBakeClass or (object is Node3D and object.get_script() == OpenDouAcousticGeometryBakeClass)

func _can_handle(object: Object) -> bool:
	return is_supported_bake_node(object)

func _parse_begin(object: Object) -> void:
	var bake_node = object as Node3D
	if bake_node == null:
		return

	var panel = PanelContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title Banner
	var lbl_title = Label.new()
	lbl_title.text = "⚡ OpenDou Acoustic Geometry Baker"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	vbox.add_child(lbl_title)

	# Stats readout
	var lbl_stats = Label.new()
	var stats: Dictionary = bake_node.get("stats") if "stats" in bake_node else {}
	lbl_stats.text = "Meshes: %d | Triangles: %d | Vol: %.1f m³" % [
		stats.get("mesh_count", 0),
		stats.get("triangle_count", 0),
		stats.get("total_volume", 0.0)
	]
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats.add_theme_font_size_override("font_size", 11)
	lbl_stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(lbl_stats)

	# Button Rack
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	var btn_probes = Button.new()
	btn_probes.text = "◎ Bake Probes"
	btn_probes.tooltip_text = "Genera las sondas de propagacion sobre la escena de Steam Audio y guarda el .probes junto a la escena (Fase 14)"
	btn_probes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_probes.pressed.connect(func():
		var r: Dictionary = bake_node.bake_probes() if bake_node.has_method("bake_probes") else {}
		lbl_stats.text = "Sondas: %d | %d bytes | %s" % [int(r.get("probe_count", 0)), int(r.get("bytes", 0)), str(r.get("path", "sin extension o sin bake"))]
	)
	var btn_bake = Button.new()
	btn_bake.text = "⚡ Bake Geometry"
	btn_bake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bake.pressed.connect(func():
		if bake_node.has_method("bake_geometry"):
			var res = bake_node.bake_geometry()
			lbl_stats.text = "Meshes: %d | Triangles: %d | Vol: %.1f m³" % [
				res.get("mesh_count", 0),
				res.get("triangle_count", 0),
				res.get("total_volume", 0.0)
			]
	)
	hbox.add_child(btn_bake)
	hbox.add_child(btn_probes)

	var btn_clear = Button.new()
	btn_clear.text = "🗑️ Clear"
	btn_clear.pressed.connect(func():
		if bake_node.has_method("clear_baked_data"):
			bake_node.clear_baked_data()
			lbl_stats.text = "Meshes: 0 | Triangles: 0 | Vol: 0.0 m³"
	)
	hbox.add_child(btn_clear)

	add_custom_control(panel)
