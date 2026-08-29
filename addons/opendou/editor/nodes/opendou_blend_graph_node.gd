class_name OpenDouBlendGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a multi-layer RTPC blend crossfade container.

class MiniCurveCanvas extends Control:
	var progress: float = 0.5 # 0.0 to 1.0 live tracking cursor

	func _init() -> void:
		custom_minimum_size = Vector2(160, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Draw dark background
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.14, 0.18, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.3, 0.4, 0.6), false, 1.0)
		
		# Draw crossfade curves
		var points = PackedVector2Array()
		var steps = 16
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var px = t * size.x
			var py = size.y - (sin(t * PI * 0.5) * (size.y - 8.0) + 4.0)
			points.append(Vector2(px, py))
			
		draw_polyline(points, Color(0.3, 0.7, 0.95, 0.9), 2.0)
		
		# Draw live playhead tracking ball
		var cursor_x = progress * size.x
		var cursor_y = size.y - (sin(progress * PI * 0.5) * (size.y - 8.0) + 4.0)
		draw_circle(Vector2(cursor_x, cursor_y), 4.0, Color(1.0, 0.9, 0.2, 1.0))

var rtpc_name: StringName = &"RPM"
var layer_names: Array[String] = ["Idle", "Med", "High"]

var rtpc_edit: LineEdit
var curve_canvas: MiniCurveCanvas
var slots_container: VBoxContainer

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_BLEND
	title = "Blend (RTPC)"
	custom_minimum_size = Vector2(200, 140)
	_build_ui()

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# RTPC parameter line
	var rtpc_hbox = HBoxContainer.new()
	var rtpc_lbl = Label.new()
	rtpc_lbl.text = "RTPC:"
	rtpc_edit = LineEdit.new()
	rtpc_edit.text = str(rtpc_name)
	rtpc_edit.text_changed.connect(func(new_text): rtpc_name = StringName(new_text))
	rtpc_hbox.add_child(rtpc_lbl)
	rtpc_hbox.add_child(rtpc_edit)
	main_vbox.add_child(rtpc_hbox)
	
	# Mini curve canvas
	curve_canvas = MiniCurveCanvas.new()
	main_vbox.add_child(curve_canvas)
	
	# Configure left input port
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, false, 0, Color.WHITE)
	
	# Slots container for output layers
	slots_container = VBoxContainer.new()
	main_vbox.add_child(slots_container)
	_rebuild_layer_slots()

func _rebuild_layer_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	for i in range(layer_names.size()):
		var lbl = Label.new()
		lbl.text = layer_names[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slots_container.add_child(lbl)
		# Enable right output port
		set_slot(i + 1, false, 0, Color.WHITE, true, 0, COLOR_AUDIO_SIGNAL)

## Sets the live playback progress position on the mini-curve.
func set_live_rtpc_progress(prog: float) -> void:
	if curve_canvas:
		curve_canvas.progress = clampf(prog, 0.0, 1.0)
		curve_canvas.queue_redraw()
