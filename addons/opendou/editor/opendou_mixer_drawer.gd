@tool
class_name OpenDouMixerDrawer
extends PanelContainer

## Retractable HDR Mixing Console and Multi-Bus Snapshot Manager with Channel Strips, HDR Window Visualizer, and Ducking Sidechain Monitor.

signal closed_requested
signal snapshot_triggered(snapshot_name: StringName, blend_time: float)
signal bus_volume_changed(bus_name: StringName, volume_db: float)

const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")

var snapshot_manager: AudioMixSnapshotManager
var hdr_engine: AudioHDREngine
var ducking_matrix: AudioDuckingMatrix

var channel_faders: Dictionary = {}
var channel_labels: Dictionary = {}
var hdr_window_lbl: Label
var ducking_status_lbl: Label
var snapshot_tree: Tree
var blend_time_spinbox: SpinBox

const BUSES = [&"Master", &"Music", &"SFX", &"Voice", &"Ambient"]

func _init() -> void:
	custom_minimum_size = Vector2(0, 210)
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
	title_lbl.text = "🎚️ Global HDR Mixing Console & Snapshot Manager"
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
	main_vbox.add_child(content_hsplit)
	
	# 1. Bus Channel Strips
	var channels_box = HBoxContainer.new()
	channels_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channels_box.add_theme_constant_override("separation", 12)
	
	for bus in BUSES:
		var strip = _create_channel_strip(bus)
		channels_box.add_child(strip)
	content_hsplit.add_child(channels_box)
	
	# 2. Right Side: HDR Window & Snapshots Bank
	var right_hsplit = HSplitContainer.new()
	right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hsplit.add_child(right_hsplit)
	
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
	duck_title.text = "🦆 Ducking Sidechain"
	duck_title.add_theme_font_size_override("font_size", 11)
	hdr_box.add_child(duck_title)
	
	ducking_status_lbl = Label.new()
	ducking_status_lbl.text = "Voice → Music: 0.0 dB\nSFX → Ambient: 0.0 dB"
	ducking_status_lbl.add_theme_font_size_override("font_size", 10)
	hdr_box.add_child(ducking_status_lbl)
	
	right_hsplit.add_child(hdr_box)
	
	# Snapshots Bank
	var snap_box = VBoxContainer.new()
	snap_box.custom_minimum_size = Vector2(200, 0)
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
	blend_lbl.text = "Blend (s):"
	blend_lbl.add_theme_font_size_override("font_size", 10)
	snap_ctrl_hbox.add_child(blend_lbl)
	
	blend_time_spinbox = SpinBox.new()
	blend_time_spinbox.min_value = 0.0
	blend_time_spinbox.max_value = 5.0
	blend_time_spinbox.step = 0.1
	blend_time_spinbox.value = 0.5
	snap_ctrl_hbox.add_child(blend_time_spinbox)
	
	var btn_apply = Button.new()
	btn_apply.text = "▶ Apply"
	btn_apply.tooltip_text = "Smoothly transition to selected snapshot"
	btn_apply.pressed.connect(_on_apply_snapshot_pressed)
	snap_ctrl_hbox.add_child(btn_apply)
	
	snap_box.add_child(snap_ctrl_hbox)
	right_hsplit.add_child(snap_box)

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
	
	var fader = VSlider.new()
	fader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fader.min_value = -60.0
	fader.max_value = 6.0
	fader.value = 0.0
	fader.step = 0.5
	fader.custom_minimum_size = Vector2(0, 95)
	
	var val_lbl = Label.new()
	val_lbl.text = "0.0 dB"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 9)
	
	fader.value_changed.connect(func(v):
		val_lbl.text = ("+%.1f" % v if v > 0.0 else "%.1f" % v) + " dB"
		bus_volume_changed.emit(bus_name, v)
	)
	
	strip_vbox.add_child(fader)
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
