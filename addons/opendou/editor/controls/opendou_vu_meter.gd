@tool
class_name OpenDouVUMeter
extends Control

## OpenDouVUMeter - High precision stereo segmented LED VU meter with peak clipping hold.
## Supports customizable dB scale, color zones (Green, Yellow, Red), and clip latch.

var db_left: float = -80.0
var db_right: float = -80.0
var clipped_left: bool = false
var clipped_right: bool = false

@export var min_db: float = -60.0:
	set(v):
		min_db = v
		queue_redraw()

@export var max_db: float = 6.0:
	set(v):
		max_db = v
		queue_redraw()

@export var segments: int = 18:
	set(v):
		segments = maxi(4, v)
		queue_redraw()

@export var is_vertical: bool = true:
	set(v):
		is_vertical = v
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(24, 100) if is_vertical else Vector2(100, 24)

func set_level(l_db: float, r_db: float) -> void:
	db_left = l_db
	db_right = r_db
	if db_left >= 0.0:
		clipped_left = true
	if db_right >= 0.0:
		clipped_right = true
	queue_redraw()

func reset_clip() -> void:
	clipped_left = false
	clipped_right = false
	queue_redraw()

func _draw() -> void:
	# Background
	var bg_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.06, 0.08, 0.11, 1.0))
	draw_rect(bg_rect, Color(0.18, 0.22, 0.28, 0.8), false, 1.0)

	if is_vertical:
		_draw_vertical_meter()
	else:
		_draw_horizontal_meter()

func _get_db_for_segment(seg_index: int, total_segs: int) -> float:
	var fraction: float = float(seg_index) / float(total_segs - 1)
	return min_db + fraction * (max_db - min_db)

func _get_color_for_db(db_val: float) -> Color:
	if db_val >= 0.0:
		return Color(1.0, 0.2, 0.25, 1.0) # Clip / Red
	elif db_val >= -6.0:
		return Color(1.0, 0.82, 0.15, 1.0) # Warning / Yellow
	else:
		return Color(0.12, 0.85, 0.45, 1.0) # Safe / Green

func _draw_vertical_meter() -> void:
	var margin_x: float = 3.0
	var margin_top: float = 8.0 # Top space for clip LED
	var margin_bot: float = 4.0
	var total_w: float = size.x - margin_x * 2.0
	var ch_w: float = (total_w - 2.0) * 0.5
	var meter_h: float = size.y - margin_top - margin_bot

	# 1. Top Clip LEDs
	var clip_led_size: Vector2 = Vector2(ch_w, 4.0)
	var clip_l_rect: Rect2 = Rect2(Vector2(margin_x, 2.0), clip_led_size)
	var clip_r_rect: Rect2 = Rect2(Vector2(margin_x + ch_w + 2.0, 2.0), clip_led_size)

	var clip_on_color: Color = Color(1.0, 0.15, 0.2, 1.0)
	var clip_off_color: Color = Color(0.25, 0.05, 0.08, 1.0)

	draw_rect(clip_l_rect, clip_on_color if clipped_left else clip_off_color)
	draw_rect(clip_r_rect, clip_on_color if clipped_right else clip_off_color)

	# 2. Segmented Bars
	var seg_h: float = (meter_h - float(segments - 1) * 1.5) / float(segments)
	if seg_h < 1.0:
		seg_h = 1.0

	for s in range(segments):
		# seg 0 is bottom (min_db), seg segments-1 is top (max_db)
		var seg_db: float = _get_db_for_segment(s, segments)
		var seg_color: Color = _get_color_for_db(seg_db)
		var off_color: Color = Color(seg_color.r * 0.18, seg_color.g * 0.18, seg_color.b * 0.18, 0.7)

		var y_pos: float = (size.y - margin_bot) - (float(s + 1) * seg_h + float(s) * 1.5)
		var l_active: bool = (db_left >= seg_db)
		var r_active: bool = (db_right >= seg_db)

		var l_rect: Rect2 = Rect2(Vector2(margin_x, y_pos), Vector2(ch_w, seg_h))
		var r_rect: Rect2 = Rect2(Vector2(margin_x + ch_w + 2.0, y_pos), Vector2(ch_w, seg_h))

		draw_rect(l_rect, seg_color if l_active else off_color)
		draw_rect(r_rect, seg_color if r_active else off_color)

func _draw_horizontal_meter() -> void:
	var margin_y: float = 3.0
	var margin_left: float = 4.0
	var margin_right: float = 8.0 # Right space for clip LED
	var total_h: float = size.y - margin_y * 2.0
	var ch_h: float = (total_h - 2.0) * 0.5
	var meter_w: float = size.x - margin_left - margin_right

	# 1. Right Clip LEDs
	var clip_led_size: Vector2 = Vector2(4.0, ch_h)
	var clip_l_rect: Rect2 = Rect2(Vector2(size.x - 6.0, margin_y), clip_led_size)
	var clip_r_rect: Rect2 = Rect2(Vector2(size.x - 6.0, margin_y + ch_h + 2.0), clip_led_size)

	var clip_on_color: Color = Color(1.0, 0.15, 0.2, 1.0)
	var clip_off_color: Color = Color(0.25, 0.05, 0.08, 1.0)

	draw_rect(clip_l_rect, clip_on_color if clipped_left else clip_off_color)
	draw_rect(clip_r_rect, clip_on_color if clipped_right else clip_off_color)

	# 2. Segmented Bars
	var seg_w: float = (meter_w - float(segments - 1) * 1.5) / float(segments)
	if seg_w < 1.0:
		seg_w = 1.0

	for s in range(segments):
		var seg_db: float = _get_db_for_segment(s, segments)
		var seg_color: Color = _get_color_for_db(seg_db)
		var off_color: Color = Color(seg_color.r * 0.18, seg_color.g * 0.18, seg_color.b * 0.18, 0.7)

		var x_pos: float = margin_left + float(s) * (seg_w + 1.5)
		var l_active: bool = (db_left >= seg_db)
		var r_active: bool = (db_right >= seg_db)

		var l_rect: Rect2 = Rect2(Vector2(x_pos, margin_y), Vector2(seg_w, ch_h))
		var r_rect: Rect2 = Rect2(Vector2(x_pos, margin_y + ch_h + 2.0), Vector2(seg_w, ch_h))

		draw_rect(l_rect, seg_color if l_active else off_color)
		draw_rect(r_rect, seg_color if r_active else off_color)
