@tool
class_name OpenDouBinauralGraphNode
extends OpenDouBaseGraphNode

## Graph node for 3D Binaural HRTF spatialization with Head-Shadowing (ILD) and Interaural Time Delay (ITD) radar visualization.

const AudioSpatialBinauralClass = preload("res://addons/opendou/core/spatial/audio_spatial_binaural.gd")

var radar_canvas: Control
var azimuth_spinbox: SpinBox
var elevation_spinbox: SpinBox
var metrics_lbl: Label

var current_azimuth_deg: float = 45.0
var current_elevation_deg: float = 0.0

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_BINAURAL
	title = "🎧 Binaural HRTF 3D"
	custom_minimum_size = Vector2(250, 195)
	
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)
	_build_ui()

func _build_ui() -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	add_child(container)
	
	# Radar Head Compass
	radar_canvas = Control.new()
	radar_canvas.custom_minimum_size = Vector2(0, 48)
	radar_canvas.draw.connect(_on_draw_head_radar)
	container.add_child(radar_canvas)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	
	# Azimuth
	var az_lbl = Label.new()
	az_lbl.text = "Azimuth (°):"
	az_lbl.add_theme_font_size_override("font_size", 10)
	grid.add_child(az_lbl)
	
	azimuth_spinbox = SpinBox.new()
	azimuth_spinbox.min_value = -180.0
	azimuth_spinbox.max_value = 180.0
	azimuth_spinbox.value = 45.0
	azimuth_spinbox.value_changed.connect(_on_azimuth_changed)
	grid.add_child(azimuth_spinbox)
	
	# Elevation
	var el_lbl = Label.new()
	el_lbl.text = "Elevation (°):"
	el_lbl.add_theme_font_size_override("font_size", 10)
	grid.add_child(el_lbl)
	
	elevation_spinbox = SpinBox.new()
	elevation_spinbox.min_value = -90.0
	elevation_spinbox.max_value = 90.0
	elevation_spinbox.value = 0.0
	elevation_spinbox.value_changed.connect(func(v): current_elevation_deg = v)
	grid.add_child(elevation_spinbox)
	
	container.add_child(grid)
	
	metrics_lbl = Label.new()
	metrics_lbl.text = "ITD: 0.46 ms | Shadow: -5.7 dB"
	metrics_lbl.add_theme_font_size_override("font_size", 9)
	metrics_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(metrics_lbl)

func _on_azimuth_changed(val: float) -> void:
	current_azimuth_deg = val
	var az_rad = absf(deg_to_rad(val))
	var itd_ms = ((0.0875 / 343.0) * (sin(az_rad) + az_rad)) * 1000.0
	var shadow_db = -8.0 * sin(az_rad)
	metrics_lbl.text = "ITD: %.2f ms | Shadow: %.1f dB" % [itd_ms, shadow_db]
	if radar_canvas:
		radar_canvas.queue_redraw()

func _on_draw_head_radar() -> void:
	if not radar_canvas:
		return
	var size = radar_canvas.size
	var center = size * 0.5
	
	# Draw Head circle
	radar_canvas.draw_circle(center, 14.0, Color(0.2, 0.25, 0.35, 1.0))
	radar_canvas.draw_arc(center, 14.0, 0, TAU, 32, Color(0.45, 0.55, 0.98), 1.5)
	
	# Nose pointer (Front / UP)
	radar_canvas.draw_line(center, center + Vector2(0, -18), Color(0.45, 0.55, 0.98), 2.0)
	
	# Source position angle
	var rad = deg_to_rad(current_azimuth_deg - 90.0)
	var src_pos = center + Vector2(cos(rad), sin(rad)) * 20.0
	radar_canvas.draw_circle(src_pos, 4.0, Color(0.98, 0.4, 0.4))
