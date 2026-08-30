@tool
class_name OpenDouADSREditor
extends Control

## OpenDouADSREditor - Interactive visual ADSR envelope editor for synth workstations.
## Features draggable handles for Attack, Decay, Sustain, and Release with neon curve visualization.

signal adsr_changed(attack: float, decay: float, sustain: float, release: float)

@export var attack: float = 0.05:
	set(v):
		attack = maxf(0.001, v)
		queue_redraw()

@export var decay: float = 0.1:
	set(v):
		decay = maxf(0.001, v)
		queue_redraw()

@export var sustain: float = 0.7:
	set(v):
		sustain = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var release: float = 0.2:
	set(v):
		release = maxf(0.001, v)
		queue_redraw()

@export var max_time: float = 2.0:
	set(v):
		max_time = maxf(0.1, v)
		queue_redraw()

@export var accent_color: Color = Color(0.12, 0.78, 0.95, 1.0):
	set(v):
		accent_color = v
		queue_redraw()

var _active_handle: int = -1 # -1: none, 0: attack, 1: decay/sustain, 2: sustain_hold, 3: release
var _hovered_handle: int = -1

func _init() -> void:
	custom_minimum_size = Vector2(160, 90)
	focus_mode = FOCUS_ALL

func set_adsr(a: float, d: float, s: float, r: float) -> void:
	attack = maxf(0.001, a)
	decay = maxf(0.001, d)
	sustain = clampf(s, 0.0, 1.0)
	release = maxf(0.001, r)
	queue_redraw()
	adsr_changed.emit(attack, decay, sustain, release)

func _get_handle_positions() -> Array[Vector2]:
	var margin_x: float = 12.0
	var margin_y: float = 10.0
	var draw_w: float = maxf(10.0, size.x - margin_x * 2.0)
	var draw_h: float = maxf(10.0, size.y - margin_y * 2.0)

	var hold_dur: float = 0.2 * max_time
	var total_dur: float = maxf(max_time, attack + decay + hold_dur + release)

	# Handle 0: Attack end (A, 1.0)
	var p0: Vector2 = Vector2(
		margin_x + (attack / total_dur) * draw_w,
		margin_y
	)

	# Handle 1: Decay end / Sustain start (A + D, S)
	var p1: Vector2 = Vector2(
		margin_x + ((attack + decay) / total_dur) * draw_w,
		margin_y + (1.0 - sustain) * draw_h
	)

	# Handle 2: Sustain hold end (A + D + Hold, S)
	var p2: Vector2 = Vector2(
		margin_x + ((attack + decay + hold_dur) / total_dur) * draw_w,
		margin_y + (1.0 - sustain) * draw_h
	)

	# Handle 3: Release end (A + D + Hold + R, 0.0)
	var p3: Vector2 = Vector2(
		margin_x + ((attack + decay + hold_dur + release) / total_dur) * draw_w,
		margin_y + draw_h
	)

	return [p0, p1, p2, p3]

func _gui_input(event: InputEvent) -> void:
	var handles: Array[Vector2] = _get_handle_positions()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_active_handle = -1
				for i in range(handles.size()):
					if mb.position.distance_to(handles[i]) <= 14.0:
						_active_handle = i
						break
				if _active_handle != -1:
					accept_event()
			else:
				if _active_handle != -1:
					_active_handle = -1
					accept_event()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _active_handle != -1:
			var margin_x: float = 12.0
			var margin_y: float = 10.0
			var draw_w: float = maxf(10.0, size.x - margin_x * 2.0)
			var draw_h: float = maxf(10.0, size.y - margin_y * 2.0)
			var hold_dur: float = 0.2 * max_time
			var total_dur: float = maxf(max_time, attack + decay + hold_dur + release)

			var clamped_pos: Vector2 = Vector2(
				clampf(mm.position.x, margin_x, size.x - margin_x),
				clampf(mm.position.y, margin_y, size.y - margin_y)
			)

			var norm_t: float = ((clamped_pos.x - margin_x) / draw_w) * total_dur
			var norm_y: float = 1.0 - ((clamped_pos.y - margin_y) / draw_h)

			match _active_handle:
				0: # Attack
					attack = maxf(0.005, norm_t)
				1: # Decay / Sustain
					decay = maxf(0.005, norm_t - attack)
					sustain = clampf(norm_y, 0.0, 1.0)
				2: # Sustain hold / Sustain level
					sustain = clampf(norm_y, 0.0, 1.0)
				3: # Release
					var base_t: float = attack + decay + hold_dur
					release = maxf(0.005, norm_t - base_t)

			queue_redraw()
			adsr_changed.emit(attack, decay, sustain, release)
			accept_event()
		else:
			var prev_hover: int = _hovered_handle
			_hovered_handle = -1
			for i in range(handles.size()):
				if mm.position.distance_to(handles[i]) <= 14.0:
					_hovered_handle = i
					break
			if prev_hover != _hovered_handle:
				queue_redraw()

func _draw() -> void:
	# Background
	var bg_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.07, 0.09, 0.13, 1.0))
	draw_rect(bg_rect, Color(0.18, 0.22, 0.28, 0.8), false, 1.0)

	var margin_x: float = 12.0
	var margin_y: float = 10.0
	var draw_w: float = maxf(10.0, size.x - margin_x * 2.0)
	var draw_h: float = maxf(10.0, size.y - margin_y * 2.0)

	# Grid lines
	var grid_color: Color = Color(0.15, 0.18, 0.25, 0.4)
	for i in range(1, 4):
		var gy: float = margin_y + draw_h * (float(i) / 4.0)
		draw_line(Vector2(margin_x, gy), Vector2(size.x - margin_x, gy), grid_color, 1.0)

	for i in range(1, 6):
		var gx: float = margin_x + draw_w * (float(i) / 6.0)
		draw_line(Vector2(gx, margin_y), Vector2(gx, size.y - margin_y), grid_color, 1.0)

	# Calculate ADSR Points
	var handles: Array[Vector2] = _get_handle_positions()
	var start_pt: Vector2 = Vector2(margin_x, margin_y + draw_h)
	var p0: Vector2 = handles[0] # Attack
	var p1: Vector2 = handles[1] # Decay
	var p2: Vector2 = handles[2] # Sustain hold
	var p3: Vector2 = handles[3] # Release

	# Translucent Filled Polygon under envelope
	var poly_pts: PackedVector2Array = PackedVector2Array([
		start_pt,
		p0,
		p1,
		p2,
		p3,
		Vector2(p3.x, margin_y + draw_h),
		start_pt
	])
	var poly_colors: PackedColorArray = PackedColorArray()
	var fill_color: Color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
	for _p in poly_pts:
		poly_colors.append(fill_color)
	draw_polygon(poly_pts, poly_colors)

	# ADSR Line Envelope
	var curve_pts: PackedVector2Array = PackedVector2Array([start_pt, p0, p1, p2, p3])
	draw_polyline(curve_pts, Color(accent_color.r, accent_color.g, accent_color.b, 0.4), 4.0, true)
	draw_polyline(curve_pts, accent_color, 2.0, true)

	# Draw Draggable Handles
	var handle_names: Array[String] = ["A", "D", "S", "R"]
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 9

	for i in range(handles.size()):
		var h_pos: Vector2 = handles[i]
		var is_highlighted: bool = (i == _active_handle or i == _hovered_handle)
		var h_radius: float = 6.0 if is_highlighted else 4.5

		# Outer glow circle
		if is_highlighted:
			draw_circle(h_pos, h_radius + 3.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.4))

		draw_circle(h_pos, h_radius, Color(0.06, 0.08, 0.12, 1.0))
		draw_arc(h_pos, h_radius, 0.0, TAU, 16, accent_color, 1.5, true)
		draw_circle(h_pos, h_radius * 0.45, Color.WHITE if is_highlighted else accent_color)

		# Small label near handle
		var tag: String = handle_names[i]
		var tag_pos: Vector2 = h_pos + Vector2(-3, -8 if h_pos.y > margin_y + 16 else 14)
		draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.7, 0.8, 0.9, 0.75))
