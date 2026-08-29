class_name OpenDouRadarView
extends Control

## Real-time 2D canvas control visualizing 3D listener position, sound emitters, attenuation rings, and profiler telemetry.

const COLOR_RADAR_BG: Color = Color(0.08, 0.1, 0.12, 1.0)
const COLOR_GRID_LINE: Color = Color(0.18, 0.25, 0.3, 0.6)
const COLOR_LISTENER: Color = Color(0.2, 0.9, 0.95, 1.0)
const COLOR_VOICE_PHYSICAL: Color = Color(0.95, 0.8, 0.2, 0.9)
const COLOR_VOICE_VIRTUAL: Color = Color(0.5, 0.55, 0.6, 0.5)
const COLOR_DIFFRACTION_RAY: Color = Color(0.3, 0.8, 1.0, 0.7)

var max_view_distance_m: float = 50.0 # Outer ring meters
var listener_position: Vector3 = Vector3.ZERO
var active_voices: Array = [] # Array of dicts or VoiceTelemetryData

# Telemetry stats
var physical_count: int = 0
var virtual_count: int = 0
var dsp_time_ms: float = 0.0
var ram_usage_kb: int = 0

func _init() -> void:
	custom_minimum_size = Vector2(240, 200)

## Updates the array of active voice telemetry data and triggers canvas redraw.
func update_radar_data(voices: Array, listener_pos: Vector3 = Vector3.ZERO) -> void:
	active_voices = voices
	listener_position = listener_pos
	queue_redraw()

## Updates performance telemetry metrics.
func update_telemetry_metrics(phys: int, virt: int, dsp_ms: float, ram_kb: int) -> void:
	physical_count = phys
	virtual_count = virt
	dsp_time_ms = dsp_ms
	ram_usage_kb = ram_kb
	queue_redraw()

## Converts a 3D world position relative to the listener to a 2D radar pixel coordinate.
func world_to_radar_pixel(world_pos: Vector3, center: Vector2, radius_px: float) -> Vector2:
	var rel_x = world_pos.x - listener_position.x
	var rel_z = world_pos.z - listener_position.z
	
	var norm_x = (rel_x / max_view_distance_m) * radius_px
	var norm_y = (rel_z / max_view_distance_m) * radius_px
	
	return Vector2(center.x + norm_x, center.y + norm_y)

func _draw() -> void:
	var center = size * 0.5
	var max_radius = minf(center.x, center.y) - 12.0
	if max_radius <= 10.0:
		return
		
	# 1. Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_RADAR_BG)
	
	# 2. Concentric Distance Rings (e.g. 25%, 50%, 75%, 100%)
	var rings = [0.25, 0.5, 0.75, 1.0]
	for r_factor in rings:
		var r_px = max_radius * r_factor
		draw_arc(center, r_px, 0, TAU, 32, COLOR_GRID_LINE, 1.0)
		
	# Crosshair grid
	draw_line(Vector2(center.x - max_radius, center.y), Vector2(center.x + max_radius, center.y), COLOR_GRID_LINE, 1.0)
	draw_line(Vector2(center.x, center.y - max_radius), Vector2(center.x, center.y + max_radius), COLOR_GRID_LINE, 1.0)
	
	# 3. Center Listener icon
	draw_circle(center, 5.0, COLOR_LISTENER)
	# Direction nose
	draw_line(center, Vector2(center.x, center.y - 10.0), COLOR_LISTENER, 2.0)
	
	# 4. Draw Active Voices
	for v in active_voices:
		var pos_3d: Vector3 = Vector3.ZERO
		var is_virt: bool = false
		var vol_db: float = 0.0
		var ev_name: String = ""
		
		if v is Dictionary:
			pos_3d = v.get("world_position", Vector3.ZERO)
			is_virt = v.get("is_virtual", false)
			vol_db = v.get("volume_db", 0.0)
			ev_name = str(v.get("event_name", ""))
		elif "world_position" in v:
			pos_3d = v.world_position
			is_virt = v.is_virtual
			vol_db = v.volume_db
			ev_name = str(v.event_name)
			
		var pixel_pos = world_to_radar_pixel(pos_3d, center, max_radius)
		
		# Clamp within radar boundary
		var dist_from_center = pixel_pos.distance_to(center)
		if dist_from_center > max_radius:
			pixel_pos = center + (pixel_pos - center).normalized() * max_radius
			
		var col = COLOR_VOICE_VIRTUAL if is_virt else COLOR_VOICE_PHYSICAL
		var base_radius = 4.0 + clampf((vol_db + 60.0) / 10.0, 1.0, 8.0)
		
		draw_circle(pixel_pos, base_radius, col)
		
		# Draw ray from listener to physical voices
		if not is_virt:
			draw_line(center, pixel_pos, Color(col.r, col.g, col.b, 0.35), 1.0)
			
	# 5. Telemetry HUD Overlay in Top-Left Corner
	var font = ThemeDB.fallback_font
	var hud_text = "Phys: %d | Virt: %d | DSP: %.2fms | RAM: %d KB" % [physical_count, virtual_count, dsp_time_ms, ram_usage_kb]
	draw_string(font, Vector2(8, 16), hud_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 0.95, 0.8))
