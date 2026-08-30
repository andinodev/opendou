@tool
class_name OpenDouKnob
extends Control

## OpenDouKnob - Interactive rotary knob control for VST synth parameters.
## Supports vertical drag, mouse wheel, double-click reset, and custom vector drawing.

signal value_changed(val: float)

@export var label: String = "":
	set(v):
		label = v
		queue_redraw()

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		set_value(value)
		queue_redraw()

@export var max_value: float = 1.0:
	set(v):
		max_value = v
		set_value(value)
		queue_redraw()

@export var default_value: float = 0.0

@export var step: float = 0.01:
	set(v):
		step = v
		queue_redraw()

@export var suffix: String = "":
	set(v):
		suffix = v
		queue_redraw()

@export var accent_color: Color = Color(0.12, 0.78, 0.95, 1.0):
	set(v):
		accent_color = v
		queue_redraw()

var value: float = 0.0:
	set = set_value

var _dragging: bool = false
var _drag_start_y: float = 0.0
var _drag_start_val: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(60, 72)
	focus_mode = FOCUS_ALL

func set_value(v: float) -> void:
	var clamped: float = clampf(v, min_value, max_value)
	if step > 0.0:
		clamped = snappedf(clamped, step)
		clamped = clampf(clamped, min_value, max_value)

	if is_equal_approx(value, clamped) and is_inside_tree():
		return

	value = clamped
	queue_redraw()
	value_changed.emit(value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					set_value(default_value)
					accept_event()
				else:
					_dragging = true
					_drag_start_y = mb.position.y
					_drag_start_val = value
					accept_event()
			else:
				_dragging = false
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var range_span: float = max_value - min_value
			var delta: float = step if step > 0.0 else maxf(0.01, range_span * 0.02)
			set_value(value + delta)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var range_span: float = max_value - min_value
			var delta: float = step if step > 0.0 else maxf(0.01, range_span * 0.02)
			set_value(value - delta)
			accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta_y: float = -mm.relative.y
		var range_span: float = max_value - min_value
		var change: float = (delta_y / 150.0) * (range_span if range_span > 0.0 else 1.0)
		set_value(value + change)
		accept_event()

func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.38)
	var radius: float = maxf(12.0, minf(size.x * 0.38, size.y * 0.32))

	# Angles in radians: start at 135 deg (bottom-left), sweep 270 deg to 405 deg (bottom-right)
	var start_angle: float = deg_to_rad(135.0)
	var end_angle: float = deg_to_rad(405.0)
	var sweep_angle: float = end_angle - start_angle

	var norm: float = 0.0
	if not is_equal_approx(max_value, min_value):
		norm = clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)

	var current_angle: float = start_angle + norm * sweep_angle

	# Background Knob Body
	draw_circle(center, radius, Color(0.10, 0.12, 0.16, 1.0))
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.18, 0.22, 0.28, 1.0), 1.5, true)

	# Inactive Arc Track
	var track_radius: float = radius * 0.82
	draw_arc(center, track_radius, start_angle, end_angle, 32, Color(0.2, 0.25, 0.32, 0.5), 3.0, true)

	# Active Arc Track
	if norm > 0.005:
		draw_arc(center, track_radius, start_angle, current_angle, 32, Color(accent_color.r, accent_color.g, accent_color.b, 0.25), 5.0, true)
		draw_arc(center, track_radius, start_angle, current_angle, 32, accent_color, 2.5, true)

	# Inner Cap
	draw_circle(center, radius * 0.55, Color(0.06, 0.08, 0.11, 1.0))

	# Needle Indicator
	var needle_dir: Vector2 = Vector2(cos(current_angle), sin(current_angle))
	var needle_start: Vector2 = center + needle_dir * (radius * 0.2)
	var needle_end: Vector2 = center + needle_dir * (radius * 0.72)
	draw_line(needle_start, needle_end, accent_color, 2.0, true)
	draw_circle(needle_end, 1.5, Color.WHITE)

	# Labels and Values
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10

	# Formatted value text
	var val_text: String
	if step >= 1.0 and is_equal_approx(step, roundf(step)):
		val_text = "%d" % int(roundf(value)) + suffix
	elif absf(value) >= 100.0 or step >= 0.1:
		val_text = "%.1f" % value + suffix
	else:
		val_text = "%.2f" % value + suffix

	var val_str_size: Vector2 = font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var val_pos: Vector2 = Vector2((size.x - val_str_size.x) * 0.5, size.y * 0.76)
	draw_string(font, val_pos + Vector2(0, font_size * 0.8), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent_color)

	# Label
	if label != "":
		var lbl_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size - 1)
		var lbl_pos: Vector2 = Vector2((size.x - lbl_size.x) * 0.5, size.y * 0.94)
		draw_string(font, lbl_pos + Vector2(0, (font_size - 1) * 0.8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, Color(0.7, 0.75, 0.85, 0.8))
