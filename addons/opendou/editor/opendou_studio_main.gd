class_name OpenDouStudioMain
extends Control

## Master container for OpenDou Studio authoring suite, supporting Main Screen, Bottom Dock, and Detachable Floating Windows.

const OpenDouGraphEditorClass = preload("res://addons/opendou/editor/opendou_graph_editor.gd")
const OpenDouRadarViewClass = preload("res://addons/opendou/editor/opendou_radar_view.gd")
const OpenDouBankPanelClass = preload("res://addons/opendou/editor/opendou_bank_panel.gd")
const OpenDouTransportBarClass = preload("res://addons/opendou/editor/opendou_transport_bar.gd")

var is_detached: bool = false
var detached_window: Window = null
var content_container: VBoxContainer

var header_bar: HBoxContainer
var tab_container: TabContainer
var graph_editor: OpenDouGraphEditor
var radar_view: OpenDouRadarView
var bank_panel: OpenDouBankPanel
var transport_bar: OpenDouTransportBar

func _init() -> void:
	custom_minimum_size = Vector2(400, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content_container)
	
	# 1. Studio Header Bar
	header_bar = HBoxContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 32)
	
	var title_lbl = Label.new()
	title_lbl.text = " 🔊 OpenDou Studio (Godot 4.7+)"
	title_lbl.add_theme_font_size_override("font_size", 13)
	
	var live_status_btn = Button.new()
	live_status_btn.text = "⚡ Connect Live TCP (3016)"
	live_status_btn.toggle_mode = true
	
	var detach_btn = Button.new()
	detach_btn.text = "🗗 Detach Window"
	detach_btn.pressed.connect(toggle_detach_window)
	
	header_bar.add_child(title_lbl)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)
	header_bar.add_child(live_status_btn)
	header_bar.add_child(detach_btn)
	content_container.add_child(header_bar)
	
	# 2. Main Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(tab_container)
	
	# 2a. Tab 1: Audio Logic Graph Editor
	graph_editor = OpenDouGraphEditorClass.new()
	graph_editor.name = "🌐 Audio Logic Graph"
	tab_container.add_child(graph_editor)
	
	# 2b. Tab 2: 3D Acoustic Radar & Telemetry
	radar_view = OpenDouRadarViewClass.new()
	radar_view.name = "📡 3D Acoustic Radar"
	tab_container.add_child(radar_view)
	
	# 2c. Tab 3: SoundBank Compiler
	bank_panel = OpenDouBankPanelClass.new()
	bank_panel.name = "📦 SoundBanks"
	tab_container.add_child(bank_panel)
	
	# 3. Bottom Audition Transport Bar
	transport_bar = OpenDouTransportBarClass.new()
	content_container.add_child(transport_bar)

## Toggles between embedded dock mode and an independent OS floating window.
func toggle_detach_window() -> void:
	if not is_detached:
		is_detached = true
		detached_window = Window.new()
		detached_window.title = "OpenDou Audio Studio"
		detached_window.size = Vector2i(1024, 700)
		detached_window.close_requested.connect(toggle_detach_window)
		
		# Move content into floating window
		remove_child(content_container)
		detached_window.add_child(content_container)
		
		add_child(detached_window)
		detached_window.popup_centered()
	else:
		is_detached = false
		if detached_window:
			detached_window.remove_child(content_container)
			add_child(content_container)
			detached_window.queue_free()
			detached_window = null
