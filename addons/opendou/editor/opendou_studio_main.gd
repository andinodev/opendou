@tool
class_name OpenDouStudioMain
extends Control

## Master container for OpenDou Studio authoring suite with Workspace Switching (Audio Graph, Music DAW, Dialogue Grid), Slide-Out HDR Mixer Drawer, Collapsible Sidebars, 100% Elastic Floating Windows, and Dynamic Attach/Detach state.

const OpenDouGraphEditorClass = preload("res://addons/opendou/editor/opendou_graph_editor.gd")
const OpenDouMusicTimelineClass = preload("res://addons/opendou/editor/opendou_music_timeline.gd")
const OpenDouDialogueGridClass = preload("res://addons/opendou/editor/opendou_dialogue_grid.gd")
const OpenDouMixerDrawerClass = preload("res://addons/opendou/editor/opendou_mixer_drawer.gd")
const OpenDouBankPanelClass = preload("res://addons/opendou/editor/opendou_bank_panel.gd")
const OpenDouTransportBarClass = preload("res://addons/opendou/editor/opendou_transport_bar.gd")
const OpenDouGameSyncsPanelClass = preload("res://addons/opendou/editor/opendou_game_syncs_panel.gd")
const OpenDouProfilerPanelClass = preload("res://addons/opendou/editor/opendou_profiler_panel.gd")
const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")

enum WorkspaceMode {
	MODE_GRAPH,
	MODE_MUSIC_DAW,
	MODE_DIALOGUE_GRID
}

var current_workspace: WorkspaceMode = WorkspaceMode.MODE_GRAPH

var is_detached: bool = false
var detached_window: Window = null
var content_container: VBoxContainer
var snapshot_manager: AudioMixSnapshotManager

# Top Toolbar Controls
var header_panel: PanelContainer
var header_bar: HBoxContainer
var btn_toggle_syncs: Button
var btn_toggle_profiler: Button
var btn_toggle_mixer: Button
var btn_mode_graph: Button
var btn_mode_music: Button
var btn_mode_dialogue: Button
var event_selector: OptionButton
var locale_selector: OptionButton
var snap_selector: OptionButton
var tcp_status_btn: Button
var detach_btn: Button

# Layout containers
var main_hsplit: HSplitContainer
var center_right_hsplit: HSplitContainer
var center_workspace_box: Control

# Center Workspaces
var graph_editor: OpenDouGraphEditor
var music_timeline: OpenDouMusicTimeline
var dialogue_grid: OpenDouDialogueGrid

# Drawers and Panels
var game_syncs_panel: OpenDouGameSyncsPanel
var right_tabs: TabContainer
var profiler_panel: OpenDouProfilerPanel
var bank_panel: OpenDouBankPanel
var mixer_drawer: OpenDouMixerDrawer
var transport_bar: OpenDouTransportBar

const PRESET_EVENTS = [
	&"Battlefield_Gunfire.tres",
	&"Vehicle_Engine_RPM.tres",
	&"Footstep_Surface.tres"
]

func _init() -> void:
	snapshot_manager = AudioMixSnapshotManagerClass.new()
	anchors_preset = Control.PRESET_FULL_RECT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 0)
	_build_ui()

func _build_ui() -> void:
	content_container = VBoxContainer.new()
	content_container.anchors_preset = Control.PRESET_FULL_RECT
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 2)
	add_child(content_container)
	
	# 1. Structured Header Toolbar (PanelContainer)
	header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 8)
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_right", 8)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_panel.add_child(header_margin)
	
	header_bar = HBoxContainer.new()
	header_bar.add_theme_constant_override("separation", 8)
	header_margin.add_child(header_bar)
	
	# Left Panel Toggle (Accordion)
	btn_toggle_syncs = Button.new()
	btn_toggle_syncs.text = "◀ Syncs"
	btn_toggle_syncs.tooltip_text = "Toggle Game Syncs Sidebar (Left)"
	btn_toggle_syncs.toggle_mode = true
	btn_toggle_syncs.button_pressed = true
	btn_toggle_syncs.toggled.connect(_on_toggle_syncs_toggled)
	btn_toggle_syncs.custom_minimum_size = Vector2(62, 24)
	header_bar.add_child(btn_toggle_syncs)
	
	var title_lbl = Label.new()
	title_lbl.text = " 🎧 OpenDou"
	title_lbl.add_theme_font_size_override("font_size", 12)
	header_bar.add_child(title_lbl)
	
	header_bar.add_child(VSeparator.new())
	
	# Workspace Mode Buttons (Exclusive Radio Group)
	var ws_group = ButtonGroup.new()
	
	btn_mode_graph = Button.new()
	btn_mode_graph.text = "🌐 Graph"
	btn_mode_graph.tooltip_text = "Logic Node Graph Editor Workspace"
	btn_mode_graph.toggle_mode = true
	btn_mode_graph.button_pressed = true
	btn_mode_graph.button_group = ws_group
	btn_mode_graph.pressed.connect(func(): set_workspace_mode(WorkspaceMode.MODE_GRAPH))
	header_bar.add_child(btn_mode_graph)
	
	btn_mode_music = Button.new()
	btn_mode_music.text = "🎼 Music DAW"
	btn_mode_music.tooltip_text = "Interactive Music Timeline & Sequencer"
	btn_mode_music.toggle_mode = true
	btn_mode_music.button_group = ws_group
	btn_mode_music.pressed.connect(func(): set_workspace_mode(WorkspaceMode.MODE_MUSIC_DAW))
	header_bar.add_child(btn_mode_music)
	
	btn_mode_dialogue = Button.new()
	btn_mode_dialogue.text = "🗣️ Dialogues"
	btn_mode_dialogue.tooltip_text = "Voice-Over & Localization Spreadsheet Table"
	btn_mode_dialogue.toggle_mode = true
	btn_mode_dialogue.button_group = ws_group
	btn_mode_dialogue.pressed.connect(func(): set_workspace_mode(WorkspaceMode.MODE_DIALOGUE_GRID))
	header_bar.add_child(btn_mode_dialogue)
	
	header_bar.add_child(VSeparator.new())
	
	# HDR Mixer Drawer Toggle
	btn_toggle_mixer = Button.new()
	btn_toggle_mixer.text = "🎚️ HDR Mixer"
	btn_toggle_mixer.tooltip_text = "Toggle Global HDR Mixing Console Drawer"
	btn_toggle_mixer.toggle_mode = true
	btn_toggle_mixer.button_pressed = false
	btn_toggle_mixer.toggled.connect(_on_toggle_mixer_toggled)
	header_bar.add_child(btn_toggle_mixer)
	
	header_bar.add_child(VSeparator.new())
	
	# Event Selector
	event_selector = OptionButton.new()
	event_selector.add_item("🎯 Battlefield_Gunfire.tres", 0)
	event_selector.add_item("🎯 Vehicle_Engine_RPM.tres", 1)
	event_selector.add_item("🎯 Footstep_Surface.tres", 2)
	event_selector.item_selected.connect(_on_event_preset_selected)
	event_selector.custom_minimum_size = Vector2(165, 24)
	header_bar.add_child(event_selector)
	
	# Locale Selector
	locale_selector = OptionButton.new()
	locale_selector.add_item("🇺🇸 EN", 0)
	locale_selector.add_item("🇪🇸 ES", 1)
	locale_selector.add_item("🇯🇵 JA", 2)
	locale_selector.add_item("🇨🇳 ZH", 3)
	locale_selector.item_selected.connect(_on_locale_selected)
	locale_selector.custom_minimum_size = Vector2(80, 24)
	header_bar.add_child(locale_selector)
	
	# Snapshot Mix Profile Selector
	snap_selector = OptionButton.new()
	snap_selector.add_item("📸 Default", 0)
	snap_selector.add_item("📸 Tinnitus", 1)
	snap_selector.add_item("📸 Pause", 2)
	snap_selector.add_item("📸 Underwater", 3)
	snap_selector.item_selected.connect(_on_snapshot_selected)
	snap_selector.custom_minimum_size = Vector2(100, 24)
	header_bar.add_child(snap_selector)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)
	
	# Compact TCP Badge
	tcp_status_btn = Button.new()
	tcp_status_btn.text = "⚡ TCP: 3016"
	tcp_status_btn.tooltip_text = "Hot-connect to game session on localhost:3016"
	tcp_status_btn.toggle_mode = true
	tcp_status_btn.toggled.connect(_on_tcp_toggled)
	tcp_status_btn.custom_minimum_size = Vector2(80, 24)
	header_bar.add_child(tcp_status_btn)
	
	# Detach / Attach Button
	detach_btn = Button.new()
	detach_btn.text = "🗗 Detach"
	detach_btn.tooltip_text = "Detach Studio to floating multi-monitor window"
	detach_btn.pressed.connect(toggle_detach_window)
	detach_btn.custom_minimum_size = Vector2(68, 24)
	header_bar.add_child(detach_btn)
	
	# Right Panel Toggle (Accordion)
	btn_toggle_profiler = Button.new()
	btn_toggle_profiler.text = "Profiler ▶"
	btn_toggle_profiler.tooltip_text = "Toggle Profiler & SoundBanks Panel (Right)"
	btn_toggle_profiler.toggle_mode = true
	btn_toggle_profiler.button_pressed = true
	btn_toggle_profiler.toggled.connect(_on_toggle_profiler_toggled)
	btn_toggle_profiler.custom_minimum_size = Vector2(74, 24)
	header_bar.add_child(btn_toggle_profiler)
	
	content_container.add_child(header_panel)
	
	# 2. Main 3-Column Resizable Layout with Zero Minimums
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.split_offset = 200
	content_container.add_child(main_hsplit)
	
	# Column 1: Game Syncs Manager (Left Collapsible)
	game_syncs_panel = OpenDouGameSyncsPanelClass.new()
	game_syncs_panel.custom_minimum_size = Vector2(0, 0)
	main_hsplit.add_child(game_syncs_panel)
	
	# Splitter for Center (Canvas) and Right (Profiler/Banks)
	center_right_hsplit = HSplitContainer.new()
	center_right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_right_hsplit.split_offset = 640
	main_hsplit.add_child(center_right_hsplit)
	
	# Column 2: Center Workspaces Container Stack
	center_workspace_box = PanelContainer.new()
	center_workspace_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_workspace_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_right_hsplit.add_child(center_workspace_box)
	
	# 2a. Graph Editor Canvas
	graph_editor = OpenDouGraphEditorClass.new()
	graph_editor.custom_minimum_size = Vector2(0, 0)
	center_workspace_box.add_child(graph_editor)
	
	# 2b. Interactive Music DAW Timeline
	music_timeline = OpenDouMusicTimelineClass.new()
	music_timeline.custom_minimum_size = Vector2(0, 0)
	music_timeline.visible = false
	center_workspace_box.add_child(music_timeline)
	
	# 2c. Dialogue Localization Grid
	dialogue_grid = OpenDouDialogueGridClass.new()
	dialogue_grid.custom_minimum_size = Vector2(0, 0)
	dialogue_grid.visible = false
	center_workspace_box.add_child(dialogue_grid)
	
	# Column 3: Right Inspector & Profiler Tabs (Right Collapsible)
	right_tabs = TabContainer.new()
	right_tabs.custom_minimum_size = Vector2(0, 0)
	right_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_right_hsplit.add_child(right_tabs)
	
	# Tab 3a: Live Profiler
	profiler_panel = OpenDouProfilerPanelClass.new()
	profiler_panel.name = "📊 Live Profiler"
	right_tabs.add_child(profiler_panel)
	
	# Tab 3b: SoundBank Compiler
	bank_panel = OpenDouBankPanelClass.new()
	bank_panel.name = "📦 SoundBanks"
	right_tabs.add_child(bank_panel)
	
	# 3. Slide-Out HDR Mixer Drawer (Bottom)
	mixer_drawer = OpenDouMixerDrawerClass.new()
	mixer_drawer.visible = false
	mixer_drawer.closed_requested.connect(func():
		mixer_drawer.visible = false
		btn_toggle_mixer.button_pressed = false
	)
	content_container.add_child(mixer_drawer)
	
	# 4. Compact Bottom Audition Transport Bar
	transport_bar = OpenDouTransportBarClass.new()
	content_container.add_child(transport_bar)
	
	# Initialize default state
	_on_event_preset_selected(0)

## Switches between Graph Editor, Music DAW, and Dialogue Grid workspaces.
func set_workspace_mode(mode: WorkspaceMode) -> void:
	current_workspace = mode
	if graph_editor:
		graph_editor.visible = (mode == WorkspaceMode.MODE_GRAPH)
	if music_timeline:
		music_timeline.visible = (mode == WorkspaceMode.MODE_MUSIC_DAW)
	if dialogue_grid:
		dialogue_grid.visible = (mode == WorkspaceMode.MODE_DIALOGUE_GRID)

func _on_toggle_syncs_toggled(is_open: bool) -> void:
	if game_syncs_panel:
		game_syncs_panel.visible = is_open
	btn_toggle_syncs.text = "◀ Syncs" if is_open else "▶ Syncs"

func _on_toggle_profiler_toggled(is_open: bool) -> void:
	if right_tabs:
		right_tabs.visible = is_open
	btn_toggle_profiler.text = "Profiler ▶" if is_open else "◀ Profiler"

func _on_toggle_mixer_toggled(is_open: bool) -> void:
	if mixer_drawer:
		mixer_drawer.visible = is_open

func _on_event_preset_selected(idx: int) -> void:
	if idx >= 0 and idx < PRESET_EVENTS.size():
		var ev_name = PRESET_EVENTS[idx]
		if graph_editor:
			graph_editor.load_event_preset(idx)
		if transport_bar:
			transport_bar.set_audition_event(ev_name)

func _on_locale_selected(idx: int) -> void:
	var locales = ["en", "es", "ja", "zh"]
	if idx >= 0 and idx < locales.size():
		var loc = locales[idx]
		if dialogue_grid and dialogue_grid.dialogue_manager:
			dialogue_grid.dialogue_manager.set_language(loc)

func _on_snapshot_selected(idx: int) -> void:
	match idx:
		0: if snapshot_manager: snapshot_manager.transition_to(&"Default", 0.5)
		1: if snapshot_manager: snapshot_manager.transition_to(&"Tinnitus_Explosion", 0.3)
		2: if snapshot_manager: snapshot_manager.transition_to(&"Pause_Menu", 0.4)
		3: if snapshot_manager: snapshot_manager.transition_to(&"Underwater", 0.6)

func _on_tcp_toggled(is_on: bool) -> void:
	if is_on:
		tcp_status_btn.text = "🟢 TCP 3016"
		if profiler_panel:
			profiler_panel.is_connected = true
	else:
		tcp_status_btn.text = "⚡ TCP: 3016"
		if profiler_panel:
			profiler_panel.is_connected = false

## Toggles between docked bottom panel and floating multi-monitor window with 100% elastic resizing.
func toggle_detach_window() -> void:
	if not is_detached:
		is_detached = true
		content_container.reparent(get_tree().root)
		
		detached_window = Window.new()
		detached_window.title = "OpenDou Audio Studio (Godot 4.7+)"
		detached_window.size = Vector2i(1100, 680)
		detached_window.wrap_controls = false
		detached_window.close_requested.connect(toggle_detach_window)
		
		get_tree().root.add_child(detached_window)
		content_container.reparent(detached_window)
		
		# Set full rect stretch inside Window
		content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
		content_container.size = detached_window.size
		detached_window.size_changed.connect(func():
			if content_container:
				content_container.size = detached_window.size
		)
		
		detach_btn.text = "📥 Attach"
		detach_btn.tooltip_text = "Dock Studio back into Godot Editor"
		
		detached_window.popup_centered()
	else:
		is_detached = false
		if detached_window:
			content_container.reparent(self)
			content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
			detached_window.queue_free()
			detached_window = null
		detach_btn.text = "🗗 Detach"
		detach_btn.tooltip_text = "Detach Studio to floating multi-monitor window"
