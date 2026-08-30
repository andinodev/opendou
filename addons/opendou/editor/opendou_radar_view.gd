@tool
class_name OpenDouRadarView
extends Control

## Real-time 2D canvas control visualizing 3D listener position, sound emitters, acoustic rooms, portals, diffraction angles, and reflection rays.

const COLOR_RADAR_BG: Color = Color(0.06, 0.08, 0.1, 1.0)
const COLOR_GRID_LINE: Color = Color(0.18, 0.25, 0.3, 0.6)
const COLOR_LISTENER: Color = Color(0.2, 0.9, 0.95, 1.0)
const COLOR_VOICE_PHYSICAL: Color = Color(0.98, 0.8, 0.2, 0.9)
const COLOR_VOICE_VIRTUAL: Color = Color(0.5, 0.55, 0.6, 0.5)
const COLOR_DIFFRACTION_RAY: Color = Color(0.3, 0.8, 1.0, 0.7)
const COLOR_ROOM_WALL: Color = Color(0.4, 0.55, 0.75, 0.65)
const COLOR_PORTAL_OPEN: Color = Color(0.2, 0.95, 0.45, 0.9)
const COLOR_PORTAL_CLOSED: Color = Color(0.95, 0.3, 0.3, 0.9)
const COLOR_REFLECTION_RAY: Color = Color(0.95, 0.4, 0.85, 0.5)

var max_view_distance_m: float = 40.0 # Outer ring meters
var listener_position: Vector3 = Vector3.ZERO
var active_voices: Array = [] # Array of dicts or VoiceTelemetryData

# Spatial Rooms & Portals telemetry
var show_portals: bool = true
var show_diffraction: bool = true
var show_reflections: bool = true

var sample_rooms: Array = [
	{ "name": "Armory_Room", "rect": Rect2(-18, -14, 16, 12), "reverb_rt60": 1.2 },
	{ "name": "Corridor_Hall", "rect": Rect2(-2, -8, 22, 16), "reverb_rt60": 2.4 }
]
var sample_portals: Array = [
	{ "p1": Vector2(-2, -6), "p2": Vector2(-2, -2), "is_open": true, "occlusion": 0.1 },
	{ "p1": Vector2(10, 8), "p2": Vector2(14, 8), "is_open": false, "occlusion": 0.85 }
]

# Telemetry stats
var physical_count: int = 4
var virtual_count: int = 128
var dsp_time_ms: float = 0.04
var ram_usage_kb: int = 1420

func _init() -> void:
	custom_minimum_size = Vector2(0, 140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Initial sample voices
	active_voices = [
		{ "event_name": "Enemy_Steps", "world_position": Vector3(-10.0, 0.0, -8.0), "is_virtual": false, "volume_db": -6.0 },
		{ "event_name": "Ambient_Vent", "world_position": Vector3(12.0, 0.0, 4.0), "is_virtual": false, "volume_db": -14.0 },
		{ "event_name": "Dist_Explosion", "world_position": Vector3(25.0, 0.0, -18.0), "is_virtual": true, "volume_db": -24.0 }
	]

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
	var max_radius = minf(center.x, center.y) - 14.0
	if max_radius <= 10.0:
		return
		
	# 1. Dark Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_RADAR_BG)
	
	# 2. Concentric Distance Rings (10m, 20m, 30m, 40m)
	var rings = [0.25, 0.5, 0.75, 1.0]
	for r_factor in rings:
		var r_px = max_radius * r_factor
		draw_arc(center, r_px, 0, TAU, 32, COLOR_GRID_LINE, 1.0)
		var dist_m = max_view_distance_m * r_factor
		draw_string(ThemeDB.fallback_font, Vector2(center.x + r_px - 16, center.y - 2), "%.0fm" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.5, 0.6, 0.7))
		
	# Crosshair grid
	draw_line(Vector2(center.x - max_radius, center.y), Vector2(center.x + max_radius, center.y), COLOR_GRID_LINE, 1.0)
	draw_line(Vector2(center.x, center.y - max_radius), Vector2(center.x, center.y + max_radius), COLOR_GRID_LINE, 1.0)
	
	# 3. Draw Acoustic Rooms & Portals
	if show_portals:
		for rm in sample_rooms:
			var r_rect: Rect2 = rm["rect"]
			var p_min = world_to_radar_pixel(Vector3(r_rect.position.x, 0, r_rect.position.y), center, max_radius)
			var p_max = world_to_radar_pixel(Vector3(r_rect.end.x, 0, r_rect.end.y), center, max_radius)
			var pixel_rect = Rect2(p_min, p_max - p_min)
			draw_rect(pixel_rect, Color(0.2, 0.4, 0.7, 0.1))
			draw_rect(pixel_rect, COLOR_ROOM_WALL, false, 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(pixel_rect.position.x + 4, pixel_rect.position.y + 12), str(rm["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.75, 0.9, 0.7))
			
		for ptl in sample_portals:
			var p1_px = world_to_radar_pixel(Vector3(ptl["p1"].x, 0, ptl["p1"].y), center, max_radius)
			var p2_px = world_to_radar_pixel(Vector3(ptl["p2"].x, 0, ptl["p2"].y), center, max_radius)
			var col = COLOR_PORTAL_OPEN if ptl["is_open"] else COLOR_PORTAL_CLOSED
			draw_line(p1_px, p2_px, col, 3.5)
	
	# 4. Center Listener Icon
	draw_circle(center, 5.0, COLOR_LISTENER)
	draw_line(center, Vector2(center.x, center.y - 12.0), COLOR_LISTENER, 2.0)
	
	# 5. Draw Active Voices & Diffraction / Reflection Rays
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
			
		var pixel_pos = world_to_radar_pixel(pos_3d, center, max_radius)
		var dist_from_center = pixel_pos.distance_to(center)
		if dist_from_center > max_radius:
			pixel_pos = center + (pixel_pos - center).normalized() * max_radius
			
		var col = COLOR_VOICE_VIRTUAL if is_virt else COLOR_VOICE_PHYSICAL
		var base_radius = 4.0 + clampf((vol_db + 60.0) / 10.0, 1.0, 6.0)
		
		draw_circle(pixel_pos, base_radius, col)
		draw_circle(pixel_pos, base_radius + 2.0, col * 0.5, false, 1.0)
		
		# Draw direct or diffracted ray
		if not is_virt:
			if show_diffraction and pos_3d.x < -2.0:
				# Bends through open portal at (-2, -4)
				var portal_px = world_to_radar_pixel(Vector3(-2.0, 0, -4.0), center, max_radius)
				draw_line(pixel_pos, portal_px, COLOR_DIFFRACTION_RAY, 1.5)
				draw_line(portal_px, center, COLOR_DIFFRACTION_RAY, 1.5)
				draw_circle(portal_px, 3.0, COLOR_DIFFRACTION_RAY)
			else:
				draw_line(center, pixel_pos, Color(col.r, col.g, col.b, 0.4), 1.0)
				
			if show_reflections:
				# First-order wall reflection ray
				var wall_refl_px = world_to_radar_pixel(Vector3(pos_3d.x, 0, -14.0), center, max_radius)
				draw_line(pixel_pos, wall_refl_px, COLOR_REFLECTION_RAY, 1.0)
				draw_line(wall_refl_px, center, COLOR_REFLECTION_RAY, 1.0)
				
		draw_string(ThemeDB.fallback_font, Vector2(pixel_pos.x + 6, pixel_pos.y + 3), ev_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.9, 0.95, 0.8))
		
	# 6. Telemetry HUD Overlay
	var hud_text = "Phys: %d | Virt: %d | DSP: %.2fms | RAM: %d KB" % [physical_count, virtual_count, dsp_time_ms, ram_usage_kb]
	draw_string(ThemeDB.fallback_font, Vector2(8, 14), hud_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.9, 0.95, 0.85))
