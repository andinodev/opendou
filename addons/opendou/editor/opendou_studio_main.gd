@tool
class_name OpenDouStudioMain
extends PanelContainer

## Master Central Studio View integrating GraphEdit canvas, Music DAW timeline, Dialogue localization grid, HDR Mixing Console drawer, Live Profiler, Game Syncs Manager, and SoundBank Compiler into a unified AAA studio interface.

const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const OpenDouGraphEditorClass = preload("res://addons/opendou/editor/opendou_graph_editor.gd")
const OpenDouMusicTimelineClass = preload("res://addons/opendou/editor/opendou_music_timeline.gd")
const OpenDouDialogueGridClass = preload("res://addons/opendou/editor/opendou_dialogue_grid.gd")
const OpenDouGameSyncsPanelClass = preload("res://addons/opendou/editor/opendou_game_syncs_panel.gd")
const OpenDouProfilerPanelClass = preload("res://addons/opendou/editor/opendou_profiler_panel.gd")
const OpenDouBankPanelClass = preload("res://addons/opendou/editor/opendou_bank_panel.gd")
const OpenDouMixerDrawerClass = preload("res://addons/opendou/editor/opendou_mixer_drawer.gd")
const OpenDouTransportBarClass = preload("res://addons/opendou/editor/opendou_transport_bar.gd")
const OpenDouGraphSerializerClass = preload("res://addons/opendou/editor/opendou_graph_serializer.gd")

enum WorkspaceMode {
	MODE_GRAPH,
	MODE_MUSIC_DAW,
	MODE_DIALOGUE_GRID
}

var current_workspace: WorkspaceMode = WorkspaceMode.MODE_GRAPH
var snapshot_manager: AudioMixSnapshotManager

# Master Header UI Elements
var header_panel: PanelContainer
var header_bar: HBoxContainer
var btn_toggle_syncs: Button
var btn_modal_syncs: Button
var btn_mode_graph: Button
var btn_mode_music: Button
var btn_mode_dialogue: Button
var btn_toggle_mixer: Button
var event_selector: OptionButton
var locale_selector: OptionButton
var snap_selector: OptionButton
var tcp_status_btn: Button
var detach_btn: Button
var btn_toggle_profiler: Button
var btn_modal_profiler: Button
var btn_modal_banks: Button
var btn_save: Button

# Content Containers
var content_container: VBoxContainer
var main_hsplit: HSplitContainer
var center_right_hsplit: HSplitContainer
var center_workspace_box: PanelContainer

# Center Workspaces
var graph_editor: OpenDouGraphEditor
var music_timeline: OpenDouMusicTimeline
var dialogue_grid: OpenDouDialogueGrid

# Drawers and Panels
var game_syncs_panel: OpenDouGameSyncsPanel
var game_syncs_scroll: ScrollContainer
var right_tabs: TabContainer
var right_tabs_scroll: ScrollContainer
var profiler_panel: OpenDouProfilerPanel
var bank_panel: OpenDouBankPanel
var mixer_drawer: OpenDouMixerDrawer
var transport_bar: OpenDouTransportBar

# Modal Floating Windows for Clean Unrestricted Views
var mixer_dialog: Window
var syncs_dialog: Window
var profiler_dialog: Window

const SFX_EVENTS = [
	&"Battlefield_Gunfire.tres",
	&"Vehicle_Engine_RPM.tres",
	&"Footstep_Surface.tres"
]

const MUSIC_EVENTS = [
	&"Dynamic_Combat_Suite.tres",
	&"Exploration_Ambient_Theme.tres",
	&"Boss_Phase_Orchestral.tres"
]

const DIALOGUE_EVENTS = [
	&"Chapter1_Hero_Voices.tres",
	&"NPC_Ambient_Barks.tres",
	&"Boss_Fight_Taunts.tres"
]

func _init() -> void:
	snapshot_manager = AudioMixSnapshotManagerClass.new()
	anchors_preset = Control.PRESET_FULL_RECT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 0)
	_build_ui()

var dock_placeholder: PanelContainer

func _build_ui() -> void:
	# 0. Dock Placeholder View (Shown in bottom dock when window is detached)
	dock_placeholder = PanelContainer.new()
	dock_placeholder.anchors_preset = Control.PRESET_FULL_RECT
	dock_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_placeholder.visible = false
	add_child(dock_placeholder)
	
	var ph_margin = MarginContainer.new()
	ph_margin.add_theme_constant_override("margin_left", 16)
	ph_margin.add_theme_constant_override("margin_top", 12)
	ph_margin.add_theme_constant_override("margin_right", 16)
	ph_margin.add_theme_constant_override("margin_bottom", 12)
	dock_placeholder.add_child(ph_margin)
	
	var ph_hbox = HBoxContainer.new()
	ph_hbox.add_theme_constant_override("separation", 16)
	ph_margin.add_child(ph_hbox)
	
	var ph_lbl = Label.new()
	ph_lbl.text = "🎧 OpenDou Audio Studio is running in a Floating Window."
	ph_lbl.add_theme_font_size_override("font_size", 12)
	ph_hbox.add_child(ph_lbl)
	
	var ph_spacer = Control.new()
	ph_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_hbox.add_child(ph_spacer)
	
	var btn_bring_front = Button.new()
	btn_bring_front.text = "🗗 Bring Window to Front"
	btn_bring_front.pressed.connect(detach_and_maximize)
	ph_hbox.add_child(btn_bring_front)
	
	var btn_dock_back = Button.new()
	btn_dock_back.text = "📥 Dock Back to Editor"
	btn_dock_back.pressed.connect(toggle_detach_window)
	ph_hbox.add_child(btn_dock_back)

	content_container = VBoxContainer.new()
	content_container.anchors_preset = Control.PRESET_FULL_RECT
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.custom_minimum_size = Vector2(0, 0)
	content_container.add_theme_constant_override("separation", 2)
	add_child(content_container)
	
	# 1. Structured Header Toolbar (PanelContainer)
	header_panel = PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 6)
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_right", 6)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_panel.add_child(header_margin)
	
	header_bar = HBoxContainer.new()
	header_bar.add_theme_constant_override("separation", 6)
	header_margin.add_child(header_bar)
	
	# Left Panel Toggle (Accordion + Modal Popout)
	var syncs_btn_group = HBoxContainer.new()
	syncs_btn_group.add_theme_constant_override("separation", 2)
	
	btn_toggle_syncs = Button.new()
	btn_toggle_syncs.text = "◀ Syncs"
	btn_toggle_syncs.tooltip_text = "Toggle Game Syncs Sidebar (Left)"
	btn_toggle_syncs.toggle_mode = true
	btn_toggle_syncs.button_pressed = true
	btn_toggle_syncs.toggled.connect(_on_toggle_syncs_toggled)
	btn_toggle_syncs.custom_minimum_size = Vector2(58, 24)
	syncs_btn_group.add_child(btn_toggle_syncs)
	
	btn_modal_syncs = Button.new()
	btn_modal_syncs.text = "🎮 Syncs"
	btn_modal_syncs.tooltip_text = "Open Game Syncs in an independent Floating Window"
	btn_modal_syncs.custom_minimum_size = Vector2(68, 24)
	btn_modal_syncs.pressed.connect(open_syncs_modal)
	syncs_btn_group.add_child(btn_modal_syncs)
	header_bar.add_child(syncs_btn_group)
	
	var title_lbl = Label.new()
	title_lbl.text = " 🎧 OpenDou"
	title_lbl.add_theme_font_size_override("font_size", 11)
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
	btn_mode_music.text = "🎼 Music"
	btn_mode_music.tooltip_text = "Interactive Music Timeline & Sequencer"
	btn_mode_music.toggle_mode = true
	btn_mode_music.button_group = ws_group
	btn_mode_music.pressed.connect(func(): set_workspace_mode(WorkspaceMode.MODE_MUSIC_DAW))
	header_bar.add_child(btn_mode_music)
	
	btn_mode_dialogue = Button.new()
	btn_mode_dialogue.text = "🗣️ Voice"
	btn_mode_dialogue.tooltip_text = "Voice-Over & Localization Spreadsheet Table"
	btn_mode_dialogue.toggle_mode = true
	btn_mode_dialogue.button_group = ws_group
	btn_mode_dialogue.pressed.connect(func(): set_workspace_mode(WorkspaceMode.MODE_DIALOGUE_GRID))
	header_bar.add_child(btn_mode_dialogue)
	
	header_bar.add_child(VSeparator.new())
	
	# HDR Mixer Modal Button
	btn_toggle_mixer = Button.new()
	btn_toggle_mixer.text = "🎚️ HDR"
	btn_toggle_mixer.tooltip_text = "Open Global HDR Mixing Console & Ducking Matrix Floating Window"
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
	event_selector.custom_minimum_size = Vector2(140, 24)
	header_bar.add_child(event_selector)
	
	# Save Button
	btn_save = Button.new()
	btn_save.text = "💾 Save"
	btn_save.tooltip_text = "Save active suite/event to disk (Ctrl+S)"
	btn_save.custom_minimum_size = Vector2(58, 24)
	btn_save.pressed.connect(_on_save_pressed)
	header_bar.add_child(btn_save)
	
	# Locale Selector
	locale_selector = OptionButton.new()
	locale_selector.add_item("🇺🇸 EN", 0)
	locale_selector.add_item("🇪🇸 ES", 1)
	locale_selector.add_item("🇯🇵 JA", 2)
	locale_selector.add_item("🇨🇳 ZH", 3)
	locale_selector.item_selected.connect(_on_locale_selected)
	locale_selector.custom_minimum_size = Vector2(70, 24)
	header_bar.add_child(locale_selector)
	
	# Snapshot Mix Profile Selector
	snap_selector = OptionButton.new()
	snap_selector.add_item("📸 Default", 0)
	snap_selector.add_item("📸 Tinnitus", 1)
	snap_selector.add_item("📸 Pause", 2)
	snap_selector.add_item("📸 Water", 3)
	snap_selector.item_selected.connect(_on_snapshot_selected)
	snap_selector.custom_minimum_size = Vector2(85, 24)
	header_bar.add_child(snap_selector)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)
	
	# Compact TCP Badge
	tcp_status_btn = Button.new()
	tcp_status_btn.text = "⚡ TCP"
	tcp_status_btn.tooltip_text = "Hot-connect to game session on localhost:3016"
	tcp_status_btn.toggle_mode = true
	tcp_status_btn.toggled.connect(_on_tcp_toggled)
	tcp_status_btn.custom_minimum_size = Vector2(65, 24)
	header_bar.add_child(tcp_status_btn)
	
	# Detach / Attach Button
	detach_btn = Button.new()
	detach_btn.text = "🗗 Detach"
	detach_btn.tooltip_text = "Detach Studio to floating multi-monitor window"
	detach_btn.pressed.connect(toggle_detach_window)
	detach_btn.custom_minimum_size = Vector2(64, 24)
	header_bar.add_child(detach_btn)
	
	# Right Panel Toggle (Accordion + Modal Popout)
	var profiler_btn_group = HBoxContainer.new()
	profiler_btn_group.add_theme_constant_override("separation", 2)
	
	btn_toggle_profiler = Button.new()
	btn_toggle_profiler.text = "Profiler ▶"
	btn_toggle_profiler.tooltip_text = "Toggle Profiler & SoundBanks Panel (Right)"
	btn_toggle_profiler.toggle_mode = true
	btn_toggle_profiler.button_pressed = true
	btn_toggle_profiler.toggled.connect(_on_toggle_profiler_toggled)
	btn_toggle_profiler.custom_minimum_size = Vector2(68, 24)
	profiler_btn_group.add_child(btn_toggle_profiler)
	
	btn_modal_profiler = Button.new()
	btn_modal_profiler.text = "📊 Profiler"
	btn_modal_profiler.tooltip_text = "Open Live Profiler in an independent Floating Window"
	btn_modal_profiler.custom_minimum_size = Vector2(72, 24)
	btn_modal_profiler.pressed.connect(open_profiler_modal)
	profiler_btn_group.add_child(btn_modal_profiler)
	
	btn_modal_banks = Button.new()
	btn_modal_banks.text = "📦 Banks"
	btn_modal_banks.tooltip_text = "Open SoundBank Compiler in an independent Floating Window"
	btn_modal_banks.custom_minimum_size = Vector2(68, 24)
	btn_modal_banks.pressed.connect(open_banks_modal)
	profiler_btn_group.add_child(btn_modal_banks)
	header_bar.add_child(profiler_btn_group)
	
	content_container.add_child(header_panel)
	
	# 2. Main 3-Column Resizable Layout with Zero Minimums
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.split_offset = 180
	content_container.add_child(main_hsplit)
	
	# Column 1: Game Syncs Manager (Left Collapsible inside ScrollContainer)
	game_syncs_scroll = ScrollContainer.new()
	game_syncs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_syncs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_syncs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	game_syncs_panel = OpenDouGameSyncsPanelClass.new()
	game_syncs_panel.custom_minimum_size = Vector2(0, 0)
	game_syncs_scroll.add_child(game_syncs_panel)
	main_hsplit.add_child(game_syncs_scroll)
	
	# Splitter for Center (Canvas) and Right (Profiler/Banks)
	center_right_hsplit = HSplitContainer.new()
	center_right_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_right_hsplit.split_offset = 580
	main_hsplit.add_child(center_right_hsplit)
	
	# Column 2: Center Workspaces Container Stack (Occupies 100% height)
	center_workspace_box = PanelContainer.new()
	center_workspace_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_workspace_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_right_hsplit.add_child(center_workspace_box)
	
	# 2a. Graph Editor Canvas
	graph_editor = OpenDouGraphEditorClass.new()
	graph_editor.custom_minimum_size = Vector2(0, 0)
	graph_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_workspace_box.add_child(graph_editor)
	
	# 2b. Interactive Music DAW Timeline
	music_timeline = OpenDouMusicTimelineClass.new()
	music_timeline.custom_minimum_size = Vector2(0, 0)
	music_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_timeline.visible = false
	center_workspace_box.add_child(music_timeline)
	
	# 2c. Dialogue Localization Grid
	dialogue_grid = OpenDouDialogueGridClass.new()
	dialogue_grid.custom_minimum_size = Vector2(0, 0)
	dialogue_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_grid.visible = false
	center_workspace_box.add_child(dialogue_grid)
	
	# Column 3: Right Inspector & Profiler Tabs (Right Collapsible inside ScrollContainer)
	right_tabs_scroll = ScrollContainer.new()
	right_tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tabs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	right_tabs = TabContainer.new()
	right_tabs.custom_minimum_size = Vector2(0, 0)
	right_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_tabs_scroll.add_child(right_tabs)
	center_right_hsplit.add_child(right_tabs_scroll)
	
	# Tab 3a: Live Profiler
	profiler_panel = OpenDouProfilerPanelClass.new()
	profiler_panel.name = "📊 Live Profiler"
	right_tabs.add_child(profiler_panel)
	
	# Tab 3b: SoundBank Compiler
	bank_panel = OpenDouBankPanelClass.new()
	bank_panel.name = "📦 SoundBanks"
	right_tabs.add_child(bank_panel)
	
	# 4. Context-Aware Bottom Transport Bar
	transport_bar = OpenDouTransportBarClass.new()
	transport_bar.rtpc_changed.connect(_on_transport_rtpc_changed)
	content_container.add_child(transport_bar)
	
	_wire_signals()
	_create_modals()

func _create_modals() -> void:
	# 1. Independent Floating HDR Mixer & Ducking Window
	mixer_dialog = Window.new()
	mixer_dialog.title = "🎚️ OpenDou HDR Mixing Console & Ducking Matrix"
	mixer_dialog.size = Vector2i(780, 460)
	mixer_dialog.visible = false
	mixer_dialog.wrap_controls = false
	mixer_dialog.close_requested.connect(func():
		mixer_dialog.visible = false
		if btn_toggle_mixer:
			btn_toggle_mixer.set_pressed_no_signal(false)
	)
	
	mixer_drawer = OpenDouMixerDrawerClass.new()
	mixer_drawer.anchors_preset = Control.PRESET_FULL_RECT
	mixer_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mixer_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mixer_drawer.custom_minimum_size = Vector2(0, 0)
	mixer_drawer.closed_requested.connect(func():
		mixer_dialog.visible = false
		if btn_toggle_mixer:
			btn_toggle_mixer.set_pressed_no_signal(false)
	)
	mixer_dialog.add_child(mixer_drawer)
	add_child(mixer_dialog)
	
	# 2. Independent Floating Game Syncs Window
	syncs_dialog = Window.new()
	syncs_dialog.title = "🎮 OpenDou Game Syncs Manager"
	syncs_dialog.size = Vector2i(460, 480)
	syncs_dialog.visible = false
	syncs_dialog.wrap_controls = false
	syncs_dialog.close_requested.connect(func(): syncs_dialog.visible = false)
	
	var syncs_scroll = ScrollContainer.new()
	syncs_scroll.anchors_preset = Control.PRESET_FULL_RECT
	syncs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	syncs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	syncs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var modal_syncs = OpenDouGameSyncsPanelClass.new()
	modal_syncs.anchors_preset = Control.PRESET_FULL_RECT
	modal_syncs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_syncs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_syncs.rtpc_value_changed.connect(_on_sync_rtpc_changed)
	modal_syncs.state_changed.connect(_on_sync_state_changed)
	modal_syncs.switch_changed.connect(_on_sync_switch_changed)
	syncs_scroll.add_child(modal_syncs)
	syncs_dialog.add_child(syncs_scroll)
	add_child(syncs_dialog)
	
	# 3. Independent Floating Profiler & SoundBanks Window
	profiler_dialog = Window.new()
	profiler_dialog.title = "📊 OpenDou Live Profiler & SoundBanks"
	profiler_dialog.size = Vector2i(840, 540)
	profiler_dialog.visible = false
	profiler_dialog.wrap_controls = false
	profiler_dialog.close_requested.connect(func(): profiler_dialog.visible = false)
	
	var modal_tabs = TabContainer.new()
	modal_tabs.name = "TabContainer"
	modal_tabs.anchors_preset = Control.PRESET_FULL_RECT
	modal_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var modal_profiler = OpenDouProfilerPanelClass.new()
	modal_profiler.name = "📊 Live Profiler"
	modal_tabs.add_child(modal_profiler)
	
	var modal_bank = OpenDouBankPanelClass.new()
	modal_bank.name = "📦 SoundBanks"
	modal_tabs.add_child(modal_bank)
	
	profiler_dialog.add_child(modal_tabs)
	add_child(profiler_dialog)

func open_hdr_mixer_modal() -> void:
	if not mixer_dialog:
		return
	mixer_dialog.popup_centered(Vector2i(780, 460))
	mixer_dialog.visible = true
	if mixer_drawer:
		mixer_drawer.visible = true
	if btn_toggle_mixer:
		btn_toggle_mixer.set_pressed_no_signal(true)

func open_syncs_modal() -> void:
	if not syncs_dialog:
		return
	syncs_dialog.popup_centered(Vector2i(460, 480))
	syncs_dialog.visible = true

func open_profiler_modal() -> void:
	if not profiler_dialog:
		return
	profiler_dialog.popup_centered(Vector2i(840, 540))
	profiler_dialog.visible = true
	var tabs = profiler_dialog.get_node_or_null("TabContainer")
	if tabs and tabs is TabContainer:
		tabs.current_tab = 0

func open_banks_modal() -> void:
	if not profiler_dialog:
		return
	profiler_dialog.popup_centered(Vector2i(840, 540))
	profiler_dialog.visible = true
	var tabs = profiler_dialog.get_node_or_null("TabContainer")
	if tabs and tabs is TabContainer:
		tabs.current_tab = 1

func _wire_signals() -> void:
	if music_timeline:
		music_timeline.dirty_changed.connect(_on_daw_dirty_changed)
		music_timeline.bpm_changed.connect(func(_b): _on_daw_dirty_changed(true))
		music_timeline.intensity_changed.connect(func(_i): _on_daw_dirty_changed(true))
	if game_syncs_panel:
		game_syncs_panel.rtpc_value_changed.connect(_on_sync_rtpc_changed)
		game_syncs_panel.state_changed.connect(_on_sync_state_changed)
		game_syncs_panel.switch_changed.connect(_on_sync_switch_changed)

func _on_daw_dirty_changed(dirty: bool) -> void:
	_update_preset_selector_text(dirty)
	if btn_save:
		btn_save.modulate = Color(1.0, 0.9, 0.3) if dirty else Color.WHITE

func _update_preset_selector_text(is_dirty: bool) -> void:
	if not event_selector:
		return
	var cur_idx = event_selector.selected
	if cur_idx < 0:
		return
	var clean_text = event_selector.get_item_text(cur_idx).replace(" *", "")
	if is_dirty:
		event_selector.set_item_text(cur_idx, clean_text + " *")
	else:
		event_selector.set_item_text(cur_idx, clean_text)

func set_workspace_mode(mode: WorkspaceMode) -> void:
	current_workspace = mode
	
	# Update workspace visibility
	if graph_editor: graph_editor.visible = (mode == WorkspaceMode.MODE_GRAPH)
	if music_timeline: music_timeline.visible = (mode == WorkspaceMode.MODE_MUSIC_DAW)
	if dialogue_grid: dialogue_grid.visible = (mode == WorkspaceMode.MODE_DIALOGUE_GRID)
	
	# Update button states
	if btn_mode_graph: btn_mode_graph.button_pressed = (mode == WorkspaceMode.MODE_GRAPH)
	if btn_mode_music: btn_mode_music.button_pressed = (mode == WorkspaceMode.MODE_MUSIC_DAW)
	if btn_mode_dialogue: btn_mode_dialogue.button_pressed = (mode == WorkspaceMode.MODE_DIALOGUE_GRID)
	
	# Context-aware bottom transport bar adaptation
	if transport_bar:
		transport_bar.set_workspace_context(int(mode))
	
	# Update event selector items & auto-collapse sidebars for full-width DAW and Voice views
	event_selector.clear()
	match mode:
		WorkspaceMode.MODE_GRAPH:
			for i in range(SFX_EVENTS.size()):
				event_selector.add_item("🎯 " + str(SFX_EVENTS[i]), i)
			btn_toggle_syncs.button_pressed = true
			if game_syncs_scroll: game_syncs_scroll.visible = true
			if right_tabs_scroll: right_tabs_scroll.visible = true
			btn_toggle_profiler.button_pressed = true
			transport_bar.set_audition_event(SFX_EVENTS[0])
		WorkspaceMode.MODE_MUSIC_DAW:
			for i in range(MUSIC_EVENTS.size()):
				var dirty_marker = " *" if music_timeline and music_timeline.is_dirty else ""
				event_selector.add_item("🎼 " + str(MUSIC_EVENTS[i]) + dirty_marker, i)
			# Auto-collapse sidebars to give 100% width to Music Timeline
			btn_toggle_syncs.button_pressed = false
			if game_syncs_scroll: game_syncs_scroll.visible = false
			if right_tabs_scroll: right_tabs_scroll.visible = false
			btn_toggle_profiler.button_pressed = false
			transport_bar.set_audition_event(MUSIC_EVENTS[0])
		WorkspaceMode.MODE_DIALOGUE_GRID:
			for i in range(DIALOGUE_EVENTS.size()):
				event_selector.add_item("🗣️ " + str(DIALOGUE_EVENTS[i]), i)
			# Auto-collapse sidebars to give 100% width to Localization Table
			btn_toggle_syncs.button_pressed = false
			if game_syncs_scroll: game_syncs_scroll.visible = false
			if right_tabs_scroll: right_tabs_scroll.visible = false
			btn_toggle_profiler.button_pressed = false
			transport_bar.set_audition_event(DIALOGUE_EVENTS[0])

func _on_transport_rtpc_changed(rtpc_name: StringName, value: float) -> void:
	if game_syncs_panel:
		game_syncs_panel.simulate_rtpc_override(rtpc_name, value)
	if music_timeline and rtpc_name == &"CombatIntensity":
		music_timeline.intensity_slider.value = value

func _on_sync_rtpc_changed(rtpc_name: StringName, value: float) -> void:
	if transport_bar and transport_bar.master_vol_slider:
		pass
	if music_timeline and rtpc_name == &"CombatIntensity":
		music_timeline.intensity_slider.value = value

func _on_sync_state_changed(group: StringName, state: StringName) -> void:
	if transport_bar:
		transport_bar.set_status_log("State: %s → %s" % [group, state])

func _on_sync_switch_changed(group: StringName, sw: StringName) -> void:
	if transport_bar:
		transport_bar.set_status_log("Switch: %s → %s" % [group, sw])

func _on_save_pressed() -> void:
	if current_workspace == WorkspaceMode.MODE_MUSIC_DAW and music_timeline:
		music_timeline.save_to_disk()
	_update_preset_selector_text(false)
	if btn_save:
		btn_save.modulate = Color.WHITE

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
			_on_save_pressed()
			get_viewport().set_input_as_handled()

func _on_toggle_syncs_toggled(is_open: bool) -> void:
	if game_syncs_scroll:
		game_syncs_scroll.visible = is_open
	btn_toggle_syncs.text = "◀ Syncs" if is_open else "▶ Syncs"

func _on_toggle_profiler_toggled(is_open: bool) -> void:
	if right_tabs_scroll:
		right_tabs_scroll.visible = is_open
	btn_toggle_profiler.text = "Profiler ▶" if is_open else "◀ Profiler"

func _on_toggle_mixer_toggled(is_open: bool) -> void:
	if is_open:
		open_hdr_mixer_modal()
	else:
		if mixer_dialog:
			mixer_dialog.visible = false
	if mixer_drawer:
		mixer_drawer.visible = is_open

func _on_event_preset_selected(idx: int) -> void:
	var ev_list = SFX_EVENTS
	match current_workspace:
		WorkspaceMode.MODE_MUSIC_DAW: ev_list = MUSIC_EVENTS
		WorkspaceMode.MODE_DIALOGUE_GRID: ev_list = DIALOGUE_EVENTS
		
	if idx >= 0 and idx < ev_list.size():
		var ev_name = ev_list[idx]
		if current_workspace == WorkspaceMode.MODE_GRAPH and graph_editor:
			graph_editor.load_event_preset(idx)
		elif current_workspace == WorkspaceMode.MODE_MUSIC_DAW and music_timeline:
			music_timeline.load_music_suite(idx)
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
		tcp_status_btn.text = "🟢 TCP"
		if profiler_panel:
			profiler_panel.is_connected = true
	else:
		tcp_status_btn.text = "⚡ TCP"
		if profiler_panel:
			profiler_panel.is_connected = false

func get_editor_root_node() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root:
		return ml.root
	return null

var is_detached: bool = false
var detached_window: Window

## Toggles between docked bottom panel and floating multi-monitor window with 100% elastic resizing.
func toggle_detach_window() -> void:
	if is_detached:
		reattach_to_dock()
	else:
		detach_and_maximize()

func detach_and_maximize() -> void:
	if is_detached:
		if detached_window:
			detached_window.mode = Window.MODE_MAXIMIZED
			detached_window.grab_focus()
		return
		
	var root = get_editor_root_node()
	if not root:
		return
		
	is_detached = true
	if dock_placeholder:
		dock_placeholder.visible = true
	if content_container:
		remove_child(content_container)
		
	detached_window = Window.new()
	detached_window.title = "🎧 OpenDou Audio Studio Suite (Maximized)"
	detached_window.min_size = Vector2i(1000, 600)
	detached_window.wrap_controls = false
	detached_window.close_requested.connect(reattach_to_dock)
	
	content_container.anchors_preset = Control.PRESET_FULL_RECT
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.custom_minimum_size = Vector2(0, 0)
	detached_window.add_child(content_container)
	root.add_child(detached_window)
	
	detached_window.popup_centered()
	detached_window.mode = Window.MODE_MAXIMIZED
	detached_window.grab_focus()
	
	if detach_btn:
		detach_btn.text = "📥 Dock"
		detach_btn.tooltip_text = "Reattach OpenDou Studio back to Godot bottom dock"

func reattach_to_dock() -> void:
	if not is_detached:
		return
		
	is_detached = false
	if detached_window:
		if content_container and content_container.get_parent() == detached_window:
			detached_window.remove_child(content_container)
		detached_window.queue_free()
		detached_window = null
		
	if dock_placeholder:
		dock_placeholder.visible = false
	if content_container:
		add_child(content_container)
		
	if detach_btn:
		detach_btn.text = "🗗 Detach"
		detach_btn.tooltip_text = "Detach Studio to floating multi-monitor window"
