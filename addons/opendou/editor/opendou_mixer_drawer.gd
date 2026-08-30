@tool
class_name OpenDouMixerDrawer
extends PanelContainer

## Retractable HDR Mixing Console and Multi-Bus Snapshot Manager with Channel Strips, HDR Window Visualizer, and Interactive Multi-Bus Audio Ducking Matrix.

signal closed_requested
signal snapshot_triggered(snapshot_name: StringName, blend_time: float)
signal bus_volume_changed(bus_name: StringName, volume_db: float)
signal ducking_rule_changed(source_bus: StringName, target_bus: StringName, attenuation_db: float)

const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

var snapshot_manager: AudioMixSnapshotManager
var hdr_engine: AudioHDREngine
var ducking_matrix: AudioDuckingMatrix

var channel_faders: Dictionary = {}
var channel_labels: Dictionary = {}
var channel_meters: Dictionary = {}
var hdr_window_lbl: Label
var ducking_status_lbl: Label
var snapshot_tree: Tree
var blend_time_spinbox: SpinBox

# Ducking Matrix UI Controls
var duck_tab_container: TabContainer
var duck_grid_container: GridContainer
var duck_cell_buttons: Dictionary = {} # Key: "Source_Target" -> Button
var duck_rule_editor_box: HBoxContainer
var duck_edit_src_lbl: Label
var duck_edit_tgt_lbl: Label
var duck_atten_spinbox: SpinBox
var duck_attack_spinbox: SpinBox
var duck_release_spinbox: SpinBox
var duck_enable_check: CheckBox
var current_editing_src: StringName = &""
var current_editing_tgt: StringName = &""

const BUSES = [&"Master", &"Music", &"SFX", &"Voice", &"Ambient"]
const DUCK_BUSES = [&"Voice", &"SFX", &"Music", &"Ambient"]

func _init() -> void:
	ducking_matrix = AudioDuckingMatrixClass.new()
	snapshot_manager = AudioMixSnapshotManagerClass.new()
	custom_minimum_size = Vector2(0, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)
	
	# Header
	var header_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "🎚️ Global HDR Mixing Console, Snapshots & Ducking Matrix"
	title_lbl.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	var btn_close = Button.new()
	btn_close.text = "✖ Close Drawer"
	btn_close.pressed.connect(func(): closed_requested.emit())
	header_hbox.add_child(btn_close)
	main_vbox.add_child(header_hbox)
	
	# Content Columns (HSplitContainer)
	var content_hsplit = HSplitContainer.new()
	content_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hsplit.split_offset = 320
	main_vbox.add_child(content_hsplit)
	
	# 1. Bus Channel Strips
	var channels_box = HBoxContainer.new()
	channels_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channels_box.add_theme_constant_override("separation", 10)
	
	for bus in BUSES:
		var strip = _create_channel_strip(bus)
		channels_box.add_child(strip)
	content_hsplit.add_child(channels_box)
	
	# 2. Right Side: TabContainer for Snapshots/HDR & Ducking Matrix
	duck_tab_container = TabContainer.new()
	duck_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duck_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hsplit.add_child(duck_tab_container)
	
	# Tab 1: Snapshots & HDR Dynamic Window
	var snap_tab = HSplitContainer.new()
	snap_tab.name = "📸 Snapshots & HDR"
	snap_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# HDR Dynamic Window Visualizer
	var hdr_box = VBoxContainer.new()
	hdr_box.custom_minimum_size = Vector2(170, 0)
	hdr_box.add_theme_constant_override("separation", 4)
	
	var hdr_title = Label.new()
	hdr_title.text = "📊 HDR Dynamic Window"
	hdr_title.add_theme_font_size_override("font_size", 11)
	hdr_box.add_child(hdr_title)
	
	hdr_window_lbl = Label.new()
	hdr_window_lbl.text = "Top: +0.0 dB\nRange: 40.0 dB\nFloor: -40.0 dB\nCompression: 0.0 dB"
	hdr_window_lbl.add_theme_font_size_override("font_size", 10)
	hdr_box.add_child(hdr_window_lbl)
	
	var duck_title = Label.new()
	duck_title.text = "🦆 Active Sidechain Levels"
	duck_title.add_theme_font_size_override("font_size", 11)
	hdr_box.add_child(duck_title)
	
	ducking_status_lbl = Label.new()
	ducking_status_lbl.text = "Voice → Music: 0.0 dB\nSFX → Ambient: 0.0 dB"
	ducking_status_lbl.add_theme_font_size_override("font_size", 10)
	hdr_box.add_child(ducking_status_lbl)
	
	snap_tab.add_child(hdr_box)
	
	# Snapshots Bank
	var snap_box = VBoxContainer.new()
	snap_box.custom_minimum_size = Vector2(180, 0)
	snap_box.add_theme_constant_override("separation", 4)
	
	var snap_title = Label.new()
	snap_title.text = "📸 Mix Snapshots"
	snap_title.add_theme_font_size_override("font_size", 11)
	snap_box.add_child(snap_title)
	
	snapshot_tree = Tree.new()
	snapshot_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	snapshot_tree.columns = 1
	snapshot_tree.set_column_title(0, "Snapshot Profile")
	snapshot_tree.column_titles_visible = true
	var root = snapshot_tree.create_item()
	
	var snapshots = [&"Default", &"Tinnitus_Explosion", &"Pause_Menu", &"Underwater"]
	for s in snapshots:
		var item = snapshot_tree.create_item(root)
		item.set_text(0, "🎚️ " + str(s))
		item.set_metadata(0, s)
	snap_box.add_child(snapshot_tree)
	
	var snap_ctrl_hbox = HBoxContainer.new()
	var blend_lbl = Label.new()
	blend_lbl.text = "Blend:"
	blend_lbl.add_theme_font_size_override("font_size", 10)
	snap_ctrl_hbox.add_child(blend_lbl)
	
	blend_time_spinbox = SpinBox.new()
	blend_time_spinbox.min_value = 0.0
	blend_time_spinbox.max_value = 5.0
	blend_time_spinbox.step = 0.1
	blend_time_spinbox.value = 0.5
	blend_time_spinbox.custom_minimum_size = Vector2(55, 0)
	snap_ctrl_hbox.add_child(blend_time_spinbox)
	
	var btn_apply = Button.new()
	btn_apply.text = "▶ Apply"
	btn_apply.tooltip_text = "Smoothly transition to selected snapshot"
	btn_apply.pressed.connect(_on_apply_snapshot_pressed)
	snap_ctrl_hbox.add_child(btn_apply)
	
	snap_box.add_child(snap_ctrl_hbox)
	snap_tab.add_child(snap_box)
	
	duck_tab_container.add_child(snap_tab)
	
	# Tab 2: Interactive Ducking Matrix
	var matrix_tab = VBoxContainer.new()
	matrix_tab.name = "🦆 Ducking Matrix"
	matrix_tab.add_theme_constant_override("separation", 6)
	
	var m_desc = Label.new()
	m_desc.text = "Sidechain priority grid: Sender bus (Rows) ducks Target bus (Columns)"
	m_desc.add_theme_font_size_override("font_size", 9)
	m_desc.modulate = Color(0.7, 0.8, 0.9)
	matrix_tab.add_child(m_desc)
	
	# Matrix Grid (5x5: 1 header row/col + 4 buses)
	var scroll_grid = ScrollContainer.new()
	scroll_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	duck_grid_container = GridContainer.new()
	duck_grid_container.columns = DUCK_BUSES.size() + 1
	duck_grid_container.add_theme_constant_override("h_separation", 4)
	duck_grid_container.add_theme_constant_override("v_separation", 4)
	
	# Top Left empty corner
	var corner_lbl = Label.new()
	corner_lbl.text = "Src \\ Tgt"
	corner_lbl.add_theme_font_size_override("font_size", 9)
	corner_lbl.custom_minimum_size = Vector2(55, 20)
	duck_grid_container.add_child(corner_lbl)
	
	# Column Headers (Target Buses)
	for tgt in DUCK_BUSES:
		var th = Label.new()
		th.text = "→ " + str(tgt)
		th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		th.add_theme_font_size_override("font_size", 9)
		th.custom_minimum_size = Vector2(70, 20)
		duck_grid_container.add_child(th)
		
	# Grid Rows (Source Buses)
	for src in DUCK_BUSES:
		var rh = Label.new()
		rh.text = str(src) + " 🔊"
		rh.add_theme_font_size_override("font_size", 9)
		rh.custom_minimum_size = Vector2(55, 22)
		duck_grid_container.add_child(rh)
		
		for tgt in DUCK_BUSES:
			if src == tgt:
				var disabled_lbl = Label.new()
				disabled_lbl.text = "—"
				disabled_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				disabled_lbl.add_theme_font_size_override("font_size", 9)
				disabled_lbl.modulate = Color(0.4, 0.4, 0.4)
				duck_grid_container.add_child(disabled_lbl)
			else:
				var cell_btn = Button.new()
				cell_btn.custom_minimum_size = Vector2(70, 22)
				cell_btn.add_theme_font_size_override("font_size", 8)
				var rule = _find_ducking_rule(src, tgt)
				if rule:
					cell_btn.text = "%.0fdB" % rule.attenuation_db
					cell_btn.modulate = Color(0.4, 0.9, 1.0)
				else:
					cell_btn.text = "Off"
					cell_btn.modulate = Color(0.6, 0.6, 0.6)
				cell_btn.pressed.connect(func(): _open_duck_cell_editor(src, tgt))
				var key = "%s_%s" % [src, tgt]
				duck_cell_buttons[key] = cell_btn
				duck_grid_container.add_child(cell_btn)
				
	scroll_grid.add_child(duck_grid_container)
	matrix_tab.add_child(scroll_grid)
	
	# Sub-editor row for selected cell
	duck_rule_editor_box = HBoxContainer.new()
	duck_rule_editor_box.add_theme_constant_override("separation", 6)
	
	duck_edit_src_lbl = Label.new()
	duck_edit_src_lbl.text = "Rule: Voice → Music"
	duck_edit_src_lbl.add_theme_font_size_override("font_size", 9)
	duck_rule_editor_box.add_child(duck_edit_src_lbl)
	
	duck_enable_check = CheckBox.new()
	duck_enable_check.text = "Active"
	duck_enable_check.button_pressed = true
	duck_enable_check.toggled.connect(_on_duck_enable_toggled)
	duck_rule_editor_box.add_child(duck_enable_check)
	
	var att_lbl = Label.new()
	att_lbl.text = "Atten:"
	att_lbl.add_theme_font_size_override("font_size", 9)
	duck_rule_editor_box.add_child(att_lbl)
	
	duck_atten_spinbox = SpinBox.new()
	duck_atten_spinbox.min_value = -48.0
	duck_atten_spinbox.max_value = -1.0
	duck_atten_spinbox.step = 1.0
	duck_atten_spinbox.value = -12.0
	duck_atten_spinbox.suffix = "dB"
	duck_atten_spinbox.custom_minimum_size = Vector2(75, 0)
	duck_atten_spinbox.value_changed.connect(_on_duck_param_changed)
	duck_rule_editor_box.add_child(duck_atten_spinbox)
	
	var atk_lbl = Label.new()
	atk_lbl.text = "Atk:"
	atk_lbl.add_theme_font_size_override("font_size", 9)
	duck_rule_editor_box.add_child(atk_lbl)
	
	duck_attack_spinbox = SpinBox.new()
	duck_attack_spinbox.min_value = 0.01
	duck_attack_spinbox.max_value = 1.0
	duck_attack_spinbox.step = 0.01
	duck_attack_spinbox.value = 0.04
	duck_attack_spinbox.suffix = "s"
	duck_attack_spinbox.custom_minimum_size = Vector2(65, 0)
	duck_attack_spinbox.value_changed.connect(_on_duck_param_changed)
	duck_rule_editor_box.add_child(duck_attack_spinbox)
	
	var rel_lbl = Label.new()
	rel_lbl.text = "Rel:"
	rel_lbl.add_theme_font_size_override("font_size", 9)
	duck_rule_editor_box.add_child(rel_lbl)
	
	duck_release_spinbox = SpinBox.new()
	duck_release_spinbox.min_value = 0.05
	duck_release_spinbox.max_value = 2.0
	duck_release_spinbox.step = 0.05
	duck_release_spinbox.value = 0.35
	duck_release_spinbox.suffix = "s"
	duck_release_spinbox.custom_minimum_size = Vector2(65, 0)
	duck_release_spinbox.value_changed.connect(_on_duck_param_changed)
	duck_rule_editor_box.add_child(duck_release_spinbox)
	
	matrix_tab.add_child(duck_rule_editor_box)
	_open_duck_cell_editor(&"Voice", &"Music")
	
	duck_tab_container.add_child(matrix_tab)

func _find_ducking_rule(src: StringName, tgt: StringName) -> AudioDuckingMatrix.DuckingRule:
	if not ducking_matrix:
		return null
	for r in ducking_matrix.rules:
		if r.source_bus == src and r.target_bus == tgt:
			return r
	return null

func _open_duck_cell_editor(src: StringName, tgt: StringName) -> void:
	current_editing_src = src
	current_editing_tgt = tgt
	if duck_edit_src_lbl:
		duck_edit_src_lbl.text = "Rule: %s → %s" % [src, tgt]
	var r = _find_ducking_rule(src, tgt)
	if r:
		if duck_enable_check: duck_enable_check.set_pressed_no_signal(true)
		if duck_atten_spinbox: duck_atten_spinbox.set_value_no_signal(r.attenuation_db)
		if duck_attack_spinbox: duck_attack_spinbox.set_value_no_signal(r.attack_time_sec)
		if duck_release_spinbox: duck_release_spinbox.set_value_no_signal(r.release_time_sec)
	else:
		if duck_enable_check: duck_enable_check.set_pressed_no_signal(false)
		if duck_atten_spinbox: duck_atten_spinbox.set_value_no_signal(-10.0)

func _on_duck_enable_toggled(is_enabled: bool) -> void:
	if current_editing_src.is_empty() or current_editing_tgt.is_empty():
		return
	var key = "%s_%s" % [current_editing_src, current_editing_tgt]
	var btn = duck_cell_buttons.get(key)
	var r = _find_ducking_rule(current_editing_src, current_editing_tgt)
	if is_enabled:
		var att = duck_atten_spinbox.value
		var atk = duck_attack_spinbox.value
		var rel = duck_release_spinbox.value
		if not r:
			ducking_matrix.add_rule(current_editing_src, current_editing_tgt, att, atk, rel)
		else:
			r.attenuation_db = att
			r.attack_time_sec = atk
			r.release_time_sec = rel
		if btn:
			btn.text = "%.0fdB" % att
			btn.modulate = Color(0.4, 0.9, 1.0)
		ducking_rule_changed.emit(current_editing_src, current_editing_tgt, att)
	else:
		if r:
			ducking_matrix.rules.erase(r)
		if btn:
			btn.text = "Off"
			btn.modulate = Color(0.6, 0.6, 0.6)
		ducking_rule_changed.emit(current_editing_src, current_editing_tgt, 0.0)

func _on_duck_param_changed(_val: float) -> void:
	if not duck_enable_check or not duck_enable_check.button_pressed:
		return
	var r = _find_ducking_rule(current_editing_src, current_editing_tgt)
	var att = duck_atten_spinbox.value
	var atk = duck_attack_spinbox.value
	var rel = duck_release_spinbox.value
	if r:
		r.attenuation_db = att
		r.attack_time_sec = atk
		r.release_time_sec = rel
	else:
		ducking_matrix.add_rule(current_editing_src, current_editing_tgt, att, atk, rel)
	var key = "%s_%s" % [current_editing_src, current_editing_tgt]
	var btn = duck_cell_buttons.get(key)
	if btn:
		btn.text = "%.0fdB" % att
	ducking_rule_changed.emit(current_editing_src, current_editing_tgt, att)

func _create_channel_strip(bus_name: StringName) -> Control:
	var strip_vbox = VBoxContainer.new()
	strip_vbox.custom_minimum_size = Vector2(58, 0)
	strip_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	strip_vbox.add_theme_constant_override("separation", 2)
	
	var bus_lbl = Label.new()
	bus_lbl.text = str(bus_name)
	bus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bus_lbl.add_theme_font_size_override("font_size", 10)
	strip_vbox.add_child(bus_lbl)
	
	var fader_meter_hbox = HBoxContainer.new()
	fader_meter_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fader_meter_hbox.add_theme_constant_override("separation", 4)
	
	var fader = VSlider.new()
	fader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fader.min_value = -60.0
	fader.max_value = 6.0
	fader.value = 0.0
	fader.step = 0.5
	fader.custom_minimum_size = Vector2(0, 95)
	fader_meter_hbox.add_child(fader)
	
	# Gain Reduction & Level Meter Rect
	var meter = Control.new()
	meter.custom_minimum_size = Vector2(6, 95)
	meter.draw.connect(func():
		var s = meter.size
		meter.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.12, 0.15, 1.0))
		var duck_db = ducking_matrix.get_ducking_attenuation_db(bus_name) if ducking_matrix else 0.0
		if absf(duck_db) > 0.1:
			var duck_ratio = clampf(absf(duck_db) / 24.0, 0.0, 1.0)
			var duck_h = s.y * duck_ratio
			meter.draw_rect(Rect2(Vector2(0, 0), Vector2(s.x, duck_h)), Color(0.95, 0.3, 0.3, 0.85))
	)
	channel_meters[bus_name] = meter
	fader_meter_hbox.add_child(meter)
	
	strip_vbox.add_child(fader_meter_hbox)
	
	var val_lbl = Label.new()
	val_lbl.text = "0.0 dB"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 9)
	
	fader.value_changed.connect(func(v):
		val_lbl.text = ("+%.1f" % v if v > 0.0 else "%.1f" % v) + " dB"
		bus_volume_changed.emit(bus_name, v)
	)
	
	strip_vbox.add_child(val_lbl)
	
	var btn_mute = Button.new()
	btn_mute.text = "M"
	btn_mute.toggle_mode = true
	btn_mute.custom_minimum_size = Vector2(24, 18)
	btn_mute.add_theme_font_size_override("font_size", 9)
	strip_vbox.add_child(btn_mute)
	
	channel_faders[bus_name] = fader
	channel_labels[bus_name] = val_lbl
	return strip_vbox

func _on_apply_snapshot_pressed() -> void:
	var selected = snapshot_tree.get_selected()
	if selected:
		var snap_name: StringName = selected.get_metadata(0)
		var blend_time = blend_time_spinbox.value
		snapshot_triggered.emit(snap_name, blend_time)

## Sets the dynamic HDR and Ducking data from the engine for real-time visualization.
func update_telemetry(window_top_db: float, window_range_db: float, duck_voice_music_db: float, duck_sfx_ambient_db: float) -> void:
	if hdr_window_lbl:
		hdr_window_lbl.text = "Top: %+.1f dB\nRange: %.1f dB\nFloor: %.1f dB\nComp: -%.1f dB" % [
			window_top_db,
			window_range_db,
			window_top_db - window_range_db,
			maxf(window_top_db, 0.0)
		]
	if ducking_status_lbl:
		ducking_status_lbl.text = "Voice → Music: %.1f dB\nSFX → Ambient: %.1f dB" % [
			duck_voice_music_db,
			duck_sfx_ambient_db
		]
	for b in channel_meters:
		if channel_meters[b]:
			channel_meters[b].queue_redraw()
