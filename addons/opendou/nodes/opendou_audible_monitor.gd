@icon("res://addons/opendou/icons/icon_audible_monitor.svg")
@tool
class_name OpenDouAudibleMonitor
extends CanvasLayer

## Declarative In-Game Debug HUD Overlay for OpenDou.
## Displays real-time audible voice telemetry, effective dB levels, spatial attenuation,
## occlusion, and ducking gain reduction in a cyberpunk HUD overlay.

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

# ==============================================================================
# EXPORT PROPERTIES
# ==============================================================================

@export_group("Audible Monitor Configuration")
@export var enabled: bool = true:
	set(val):
		enabled = val
		if panel_container:
			panel_container.visible = enabled and is_overlay_visible

@export var is_overlay_visible: bool = true:
	set(val):
		is_overlay_visible = val
		if panel_container:
			panel_container.visible = enabled and is_overlay_visible

@export var toggle_key: Key = KEY_F8
@export var max_items_displayed: int = 8
@export var min_db_threshold: float = -55.0
@export_range(0.01, 0.5, 0.01) var poll_interval: float = 0.05
@export var listener_node_path: NodePath = NodePath("")

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var ducking_matrix: AudioDuckingMatrix = null
var poll_timer: float = 0.0
var displayed_voices_count: int = 0

var panel_container: PanelContainer = null
var title_label: Label = null
var badge_count_label: Label = null
var items_vbox: VBoxContainer = null
var empty_label: Label = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	layer = 100
	_build_ui()
	if panel_container:
		panel_container.visible = enabled and is_overlay_visible

func _process(delta: float) -> void:
	if not enabled or not is_overlay_visible:
		return
		
	poll_timer += delta
	if poll_timer >= poll_interval:
		poll_timer = 0.0
		_refresh_monitor()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			toggle_overlay()
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Sets an explicit AudioDuckingMatrix instance for ducking gain reduction lookups.
func set_ducking_matrix(matrix: AudioDuckingMatrix) -> void:
	ducking_matrix = matrix

## Toggles the HUD overlay visibility.
func toggle_overlay() -> void:
	self.is_overlay_visible = not is_overlay_visible

## Forces an immediate refresh of the audible voices HUD telemetry.
func refresh_now() -> void:
	_refresh_monitor()

## Returns the number of audible voices currently displayed in the HUD.
func get_displayed_voices_count() -> int:
	return displayed_voices_count

# ==============================================================================
# UI CONSTRUCTION & THEME
# ==============================================================================

func _build_ui() -> void:
	# Avoid duplicate construction
	if panel_container != null and is_instance_valid(panel_container):
		return
		
	panel_container = PanelContainer.new()
	panel_container.name = "AudibleMonitorPanel"
	
	# Positioning at Top-Right
	panel_container.anchor_left = 1.0
	panel_container.anchor_right = 1.0
	panel_container.anchor_top = 0.0
	panel_container.anchor_bottom = 0.0
	panel_container.offset_left = -390.0
	panel_container.offset_right = -15.0
	panel_container.offset_top = 15.0
	panel_container.offset_bottom = 360.0
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel_container.grow_vertical = Control.GROW_DIRECTION_END
	panel_container.custom_minimum_size = Vector2(375.0, 200.0)
	
	# Dark cyberpunk panel style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	style_box.border_color = Color(0.0, 0.85, 1.0, 0.6)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.content_margin_left = 10.0
	style_box.content_margin_right = 10.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_bottom = 8.0
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_box.shadow_size = 6
	panel_container.add_theme_stylebox_override("panel", style_box)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 6)
	panel_container.add_child(main_vbox)
	
	# Header HBox
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(header_hbox)
	
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🔊 OPENDOU AUDIBLE MONITOR"
	title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)
	
	badge_count_label = Label.new()
	badge_count_label.name = "BadgeCountLabel"
	badge_count_label.text = "[0 voices]"
	badge_count_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5, 1.0))
	badge_count_label.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(badge_count_label)
	
	var key_hint = Label.new()
	key_hint.name = "KeyHintLabel"
	key_hint.text = "[F8]"
	key_hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	key_hint.add_theme_font_size_override("font_size", 10)
	header_hbox.add_child(key_hint)
	
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.0, 0.85, 1.0, 0.3)
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)
	
	# Scroll Container for Voice Items
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	items_vbox = VBoxContainer.new()
	items_vbox.name = "ItemsVBox"
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(items_vbox)
	
	empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "No audible voices above threshold"
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	empty_label.add_theme_font_size_override("font_size", 11)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_vbox.add_child(empty_label)
	
	add_child(panel_container)

# ==============================================================================
# DATA REFRESH & RENDERING
# ==============================================================================

func _find_listener_position() -> Vector3:
	if not listener_node_path.is_empty():
		var target = get_node_or_null(listener_node_path)
		if target is Node3D:
			return target.global_position
		elif target is Node2D:
			return Vector3(target.global_position.x, target.global_position.y, 0.0)
			
	var vp = get_viewport()
	if vp:
		var cam3d = vp.get_camera_3d()
		if cam3d:
			return cam3d.global_position
		var cam2d = vp.get_camera_2d()
		if cam2d:
			return Vector3(cam2d.global_position.x, cam2d.global_position.y, 0.0)
			
	return Vector3.ZERO

func _refresh_monitor() -> void:
	if not is_inside_tree():
		return
	if panel_container == null or items_vbox == null:
		_build_ui()
		if items_vbox == null:
			return
			
	var tree = get_tree()
	var listener_pos = _find_listener_position()
	var voices = AudibleVoiceMonitorClass.collect_audible_voices(tree, listener_pos, ducking_matrix, min_db_threshold)
	
	displayed_voices_count = voices.size()
	
	if badge_count_label:
		badge_count_label.text = "[%d voices]" % displayed_voices_count
		if displayed_voices_count > 0:
			badge_count_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5, 1.0))
		else:
			badge_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.8))
			
	# Clear old children in items_vbox
	for child in items_vbox.get_children():
		child.queue_free()
		
	if voices.is_empty():
		var empty = Label.new()
		empty.text = "No audible voices above threshold"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
		empty.add_theme_font_size_override("font_size", 11)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_vbox.add_child(empty)
		return
		
	var render_count = mini(voices.size(), max_items_displayed)
	for i in range(render_count):
		var v_info = voices[i]
		var row = _create_voice_row(v_info)
		items_vbox.add_child(row)

func _create_voice_row(v_info: RefCounted) -> Control:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.12, 0.20, 0.7)
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_left = 3
	row_style.corner_radius_bottom_right = 3
	row_style.content_margin_left = 6.0
	row_style.content_margin_right = 6.0
	row_style.content_margin_top = 3.0
	row_style.content_margin_bottom = 3.0
	row_panel.add_theme_stylebox_override("panel", row_style)
	
	var row_hbox = HBoxContainer.new()
	row_hbox.add_theme_constant_override("separation", 6)
	row_panel.add_child(row_hbox)
	
	# Category Badge
	var cat_color = _get_category_color(v_info.bus_category)
	var cat_badge = Label.new()
	cat_badge.text = "[%s]" % str(v_info.bus_category)
	cat_badge.add_theme_color_override("font_color", cat_color)
	cat_badge.add_theme_font_size_override("font_size", 10)
	row_hbox.add_child(cat_badge)
	
	# Voice / Emitter Name
	var name_label = Label.new()
	var display_name = str(v_info.event_name)
	if not str(v_info.emitter_name).is_empty() and str(v_info.emitter_name) != "DefaultEmitter":
		display_name = "%s:%s" % [str(v_info.emitter_name), str(v_info.event_name)]
	name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
	row_hbox.add_child(name_label)
	
	# Tags: Distance, Occlusion, Ducking
	var tags_hbox = HBoxContainer.new()
	tags_hbox.add_theme_constant_override("separation", 3)
	row_hbox.add_child(tags_hbox)
	
	if v_info.is_3d and v_info.distance > 0.0:
		var dist_tag = Label.new()
		dist_tag.text = "[%.1fm]" % v_info.distance
		dist_tag.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9, 0.8))
		dist_tag.add_theme_font_size_override("font_size", 9)
		tags_hbox.add_child(dist_tag)
		
	if v_info.occlusion_factor > 0.05:
		var occ_tag = Label.new()
		occ_tag.text = "[🛡️ Occl]"
		occ_tag.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 0.9))
		occ_tag.add_theme_font_size_override("font_size", 9)
		tags_hbox.add_child(occ_tag)
		
	if v_info.ducking_attenuation_db < -0.5:
		var duck_tag = Label.new()
		duck_tag.text = "[🦆 %+.0fdB]" % v_info.ducking_attenuation_db
		duck_tag.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 0.9))
		duck_tag.add_theme_font_size_override("font_size", 9)
		tags_hbox.add_child(duck_tag)
		
	# Level VU Progress Bar (Normalized -60 dB to 0 dB)
	var vu_bar = ProgressBar.new()
	vu_bar.min_value = -60.0
	vu_bar.max_value = 0.0
	vu_bar.value = clampf(v_info.effective_db, -60.0, 0.0)
	vu_bar.show_percentage = false
	vu_bar.custom_minimum_size = Vector2(48.0, 10.0)
	vu_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Bar Styling
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	bg_bar.corner_radius_top_left = 2
	bg_bar.corner_radius_top_right = 2
	bg_bar.corner_radius_bottom_left = 2
	bg_bar.corner_radius_bottom_right = 2
	vu_bar.add_theme_stylebox_override("background", bg_bar)
	
	var fill_bar = StyleBoxFlat.new()
	fill_bar.bg_color = _get_vu_color(v_info.effective_db)
	fill_bar.corner_radius_top_left = 2
	fill_bar.corner_radius_top_right = 2
	fill_bar.corner_radius_bottom_left = 2
	fill_bar.corner_radius_bottom_right = 2
	vu_bar.add_theme_stylebox_override("fill", fill_bar)
	row_hbox.add_child(vu_bar)
	
	# Effective dB Label
	var db_label = Label.new()
	db_label.text = "%+.1f dB" % v_info.effective_db
	db_label.custom_minimum_size = Vector2(50.0, 0.0)
	db_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	db_label.add_theme_font_size_override("font_size", 10)
	db_label.add_theme_color_override("font_color", _get_vu_color(v_info.effective_db))
	row_hbox.add_child(db_label)
	
	return row_panel

func _get_category_color(cat: StringName) -> Color:
	match str(cat):
		"Voice":
			return Color(0.0, 0.85, 1.0)   # Cyan (#00d9ff)
		"SFX":
			return Color(1.0, 0.6, 0.1)    # Orange (#ff991a)
		"Music":
			return Color(0.9, 0.2, 0.8)    # Magenta (#e633cc)
		"Ambience":
			return Color(0.2, 0.9, 0.5)    # Green (#33e680)
		_:
			return Color(0.7, 0.7, 0.8)

func _get_vu_color(effective_db: float) -> Color:
	if effective_db > -6.0:
		return Color(1.0, 0.25, 0.35) # Red / warning
	elif effective_db > -18.0:
		return Color(1.0, 0.75, 0.15) # Yellow / mid
	elif effective_db > -36.0:
		return Color(0.2, 0.9, 0.5)  # Green / good
	else:
		return Color(0.0, 0.7, 0.9)  # Cyan / low
