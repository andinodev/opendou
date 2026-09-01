@tool
class_name OpenDouBlendGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a multi-layer RTPC blend crossfade container with curve visualization.

class MiniCurveCanvas extends Control:
	var progress: float = 0.45 # 0.0 to 1.0 live tracking cursor

	func _init() -> void:
		custom_minimum_size = Vector2(210, 65)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Dark Slate Background
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.12, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.3, 0.4, 0.6), false, 1.0)
		
		# Draw 3 Layer Crossfade Curves (Idle, Mid, High)
		var steps = 24
		
		# Layer 1: Fade out (Cyan)
		var pts_idle = PackedVector2Array()
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var py = size.y - (cos(t * PI * 0.5) * (size.y - 10.0) + 5.0)
			pts_idle.append(Vector2(px, py))
		draw_polyline(pts_idle, Color(0.2, 0.75, 0.95, 0.8), 2.0)
		
		# Layer 2: Bell curve (Amber)
		var pts_mid = PackedVector2Array()
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var py = size.y - (sin(t * PI) * (size.y - 10.0) + 5.0)
			pts_mid.append(Vector2(px, py))
		draw_polyline(pts_mid, Color(0.98, 0.75, 0.14, 0.9), 2.0)
		
		# Layer 3: Fade in (Magenta)
		var pts_high = PackedVector2Array()
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var py = size.y - (sin(t * PI * 0.5) * (size.y - 10.0) + 5.0)
			pts_high.append(Vector2(px, py))
		draw_polyline(pts_high, Color(0.85, 0.4, 0.95, 0.8), 2.0)
		
		# Live RTPC cursor indicator
		var cur_x = progress * size.x
		draw_line(Vector2(cur_x, 0), Vector2(cur_x, size.y), Color(1.0, 1.0, 1.0, 0.85), 1.5)
		draw_circle(Vector2(cur_x, size.y * 0.5), 4.0, Color(1.0, 0.9, 0.2, 1.0))

var rtpc_name: StringName = &"RPM"
var layer_names: Array[String] = ["Idle (0-2k)", "Mid (1.5-5k)", "High (4.5-8k)"]

var rtpc_edit: LineEdit
var curve_canvas: MiniCurveCanvas

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_BLEND
	title = "📈 Blend (RTPC Multilayer)"
	custom_minimum_size = Vector2(260, 185)
	_build_ui()

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)
	
	# RTPC parameter line
	var rtpc_hbox = HBoxContainer.new()
	rtpc_hbox.add_theme_constant_override("separation", 8)
	var rtpc_lbl = Label.new()
	rtpc_lbl.text = "Bound RTPC:"
	rtpc_edit = LineEdit.new()
	rtpc_edit.text = str(rtpc_name)
	rtpc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtpc_edit.text_changed.connect(func(new_text): rtpc_name = StringName(new_text))
	rtpc_hbox.add_child(rtpc_lbl)
	rtpc_hbox.add_child(rtpc_edit)
	main_vbox.add_child(rtpc_hbox)
	
	# Crossfade Curve Canvas
	curve_canvas = MiniCurveCanvas.new()
	main_vbox.add_child(curve_canvas)
	
	# Layer Labels / Slots
	var layers_lbl = Label.new()
	layers_lbl.text = "Layers: Idle (Ch0) • Mid (Ch1) • High (Ch2)"
	layers_lbl.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(layers_lbl)
	
	# Slot 0: Input logic, Output signal
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, true, 0, COLOR_AUDIO_SIGNAL)

## Fija la posicion normalizada [0,1] del cursor de RTPC en vivo sobre la mini
## curva de crossfade. Lo llama el editor cuando el servidor de Live Update
## reporta un cambio de parametro.
func set_live_rtpc_progress(progress: float) -> void:
	if curve_canvas == null:
		return
	curve_canvas.progress = clampf(progress, 0.0, 1.0)
	curve_canvas.queue_redraw()

## Posicion actual del cursor de RTPC en vivo.
func get_live_rtpc_progress() -> float:
	if curve_canvas == null:
		return 0.0
	return curve_canvas.progress
