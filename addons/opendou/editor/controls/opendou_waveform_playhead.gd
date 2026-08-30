@tool
class_name OpenDouWaveformPlayhead
extends Control

## OpenDouWaveformPlayhead - Visual audio waveform display with real-time playhead and ADSR envelope overlay.

var waveform_samples: PackedFloat32Array = PackedFloat32Array()
var playhead_progress: float = -1.0 # Negative indicates playhead is inactive/hidden
var adsr_overlay: Dictionary = {
	"enabled": false,
	"attack": 0.0,
	"decay": 0.0,
	"sustain": 1.0,
	"release": 0.0,
	"total_duration": 1.0
}

@export var waveform_color: Color = Color(0.12, 0.78, 0.95, 0.85):
	set(v):
		waveform_color = v
		queue_redraw()

@export var playhead_color: Color = Color(1.0, 0.85, 0.2, 0.95):
	set(v):
		playhead_color = v
		queue_redraw()

@export var envelope_color: Color = Color(1.0, 0.35, 0.65, 0.35):
	set(v):
		envelope_color = v
		queue_redraw()

@export var bg_color: Color = Color(0.06, 0.08, 0.12, 1.0):
	set(v):
		bg_color = v
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(160, 64)

func set_waveform(samples: PackedFloat32Array) -> void:
	waveform_samples = samples
	queue_redraw()

func set_playhead(progress: float) -> void:
	if progress >= 0.0:
		playhead_progress = clampf(progress, 0.0, 1.0)
	else:
		playhead_progress = -1.0
	queue_redraw()

func set_adsr_overlay(a: float, d: float, s: float, r: float, total_dur: float = 1.0) -> void:
	adsr_overlay = {
		"enabled": true,
		"attack": maxf(0.0, a),
		"decay": maxf(0.0, d),
		"sustain": clampf(s, 0.0, 1.0),
		"release": maxf(0.0, r),
		"total_duration": maxf(0.001, total_dur)
	}
	queue_redraw()

func clear_adsr_overlay() -> void:
	adsr_overlay["enabled"] = false
	queue_redraw()

func _draw() -> void:
	# Background
	var full_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, bg_color)
	draw_rect(full_rect, Color(0.18, 0.22, 0.28, 0.8), false, 1.0)

	var mid_y: float = size.y * 0.5
	# Center Zero-axis line
	draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.2, 0.25, 0.35, 0.5), 1.0)

	# 1. Waveform Rendering
	var n_samples: int = waveform_samples.size()
	if n_samples > 1 and size.x > 1.0:
		var w: float = size.x
		var h_half: float = size.y * 0.45

		if n_samples <= int(w) * 2:
			# Direct polyline rendering for small to medium buffers
			var pts: PackedVector2Array = PackedVector2Array()
			pts.resize(n_samples)
			for i in range(n_samples):
				var px: float = (float(i) / float(n_samples - 1)) * w
				var s_val: float = clampf(waveform_samples[i], -1.0, 1.0)
				var py: float = mid_y - s_val * h_half
				pts[i] = Vector2(px, py)
			draw_polyline(pts, waveform_color, 1.5, true)
		else:
			# Min/Max downsampled column rendering for large audio buffers
			var num_cols: int = int(w)
			for c in range(num_cols):
				var start_idx: int = int(float(c) / float(num_cols) * n_samples)
				var end_idx: int = int(float(c + 1) / float(num_cols) * n_samples)
				end_idx = mini(end_idx, n_samples)
				if start_idx >= end_idx:
					start_idx = maxi(0, end_idx - 1)

				var min_v: float = 0.0
				var max_v: float = 0.0
				for idx in range(start_idx, end_idx):
					var s: float = waveform_samples[idx]
					if s < min_v:
						min_v = s
					if s > max_v:
						max_v = s

				var y_top: float = mid_y - clampf(max_v, -1.0, 1.0) * h_half
				var y_bot: float = mid_y - clampf(min_v, -1.0, 1.0) * h_half
				if absf(y_bot - y_top) < 1.0:
					y_bot = y_top + 1.0
				draw_line(Vector2(float(c), y_top), Vector2(float(c), y_bot), waveform_color, 1.0)

	# 2. ADSR Envelope Overlay (if enabled)
	if adsr_overlay.get("enabled", false):
		var a: float = adsr_overlay.get("attack", 0.0)
		var d: float = adsr_overlay.get("decay", 0.0)
		var s: float = adsr_overlay.get("sustain", 1.0)
		var r: float = adsr_overlay.get("release", 0.0)
		var total_dur: float = adsr_overlay.get("total_duration", 1.0)

		var w_env: float = size.x
		var h_env: float = size.y * 0.9
		var env_bottom: float = size.y * 0.95

		var x0: float = 0.0
		var x_a: float = clampf(a / total_dur, 0.0, 1.0) * w_env
		var x_d: float = clampf((a + d) / total_dur, 0.0, 1.0) * w_env
		var x_r_start: float = maxf(x_d, w_env - clampf(r / total_dur, 0.0, 1.0) * w_env)
		var x_end: float = w_env

		var p_start: Vector2 = Vector2(x0, env_bottom)
		var p_a: Vector2 = Vector2(x_a, env_bottom - h_env)
		var p_d: Vector2 = Vector2(x_d, env_bottom - s * h_env)
		var p_r_start: Vector2 = Vector2(x_r_start, env_bottom - s * h_env)
		var p_end: Vector2 = Vector2(x_end, env_bottom)

		var poly_pts: PackedVector2Array = PackedVector2Array([
			p_start, p_a, p_d, p_r_start, p_end, Vector2(x_end, env_bottom), p_start
		])
		var poly_colors: PackedColorArray = PackedColorArray()
		for _pt in poly_pts:
			poly_colors.append(envelope_color)
		draw_polygon(poly_pts, poly_colors)

		var line_pts: PackedVector2Array = PackedVector2Array([p_start, p_a, p_d, p_r_start, p_end])
		draw_polyline(line_pts, Color(envelope_color.r, envelope_color.g, envelope_color.b, 0.9), 1.5, true)

	# 3. Glowing Playhead Bar
	if playhead_progress >= 0.0 and playhead_progress <= 1.0:
		var px: float = playhead_progress * size.x
		# Soft outer glow
		draw_line(Vector2(px, 0), Vector2(px, size.y), Color(playhead_color.r, playhead_color.g, playhead_color.b, 0.3), 5.0)
		# Core bright line
		draw_line(Vector2(px, 0), Vector2(px, size.y), playhead_color, 2.0)
		# Header marker dot
		draw_circle(Vector2(px, 3.0), 3.0, playhead_color)
