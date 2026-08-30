@tool
class_name OpenDouMusicTimeline
extends PanelContainer

## Professional DAW-style interactive music timeline with Rhythmic BPM Grid Ruler, Multi-Track Headers (Mute, Solo, Volume Fader, Audio File Picker, Bus Routing, Automation Curves, Delete, Random Sub-Tracks), Structural Cues (Pre-Entry, Exit), Post-Exit Reverb Tails, Clip Trim Handles, Dynamic Track CRUD ([+ Add Track]), Music Playlist Sequencer & State Hierarchy, Persistent Suite Serialization (JSON / .tres), Metronome, Horizontal Zoom, and Quantized Transition Matrix.

signal bpm_changed(new_bpm: float)
signal intensity_changed(new_intensity: float)
signal transition_requested(target_segment: StringName, sync_mode: int, fade_time: float)
signal stinger_requested(stinger_name: StringName, sync_mode: int)
signal dirty_changed(is_dirty: bool)
signal track_added(track_name: String)
signal track_deleted(track_name: String)
signal playlist_segment_changed(segment_name: StringName)

const MusicClockClass = preload("res://addons/opendou/core/music/music_clock.gd")
const MusicSegmentClass = preload("res://addons/opendou/core/music/music_segment.gd")
const MusicTransitionMatrixClass = preload("res://addons/opendou/core/music/music_transition_matrix.gd")
const MusicStingerQueueClass = preload("res://addons/opendou/core/music/music_stinger_queue.gd")
const MusicPlaylistManagerClass = preload("res://addons/opendou/core/music/music_playlist_manager.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

const MUSIC_SUITES_SAVE_PATH = "res://opendou_music_suites.json"

class TrackLaneData:
	var name: String
	var min_intensity: float
	var max_intensity: float
	var color: Color
	var is_muted: bool = false
	var is_solo: bool = false
	var volume_db: float = 0.0
	var current_gain: float = 0.0
	var audio_file_path: String = ""
	var left_trim_ratio: float = 0.0 # 0.0 to 1.0
	var right_trim_ratio: float = 1.0 # 0.0 to 1.0
	var sub_tracks: Array[Dictionary] = [] # [{"name": "Var 1", "audio_path": "...", "weight": 1.0}]
	var active_sub_index: int = 0
	var is_random_mode: bool = true
	
	# Bus Routing & Automation Curves (TASK-032)
	var bus_name: StringName = &"Master"
	var automation_enabled: bool = false
	var automation_parameter: int = 0 # 0 = Volume, 1 = LPF Cutoff, 2 = RTPC: CombatIntensity
	var automation_points: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.5, 0.6), Vector2(1.0, 1.0)]
	var selected_point_index: int = -1
	
	var row_container: HBoxContainer
	var header_panel: PanelContainer
	var mute_btn: Button
	var solo_btn: Button
	var vol_slider: HSlider
	var auto_btn: Button
	var bus_opt: OptionButton
	var file_btn: Button
	var var_btn: Button
	var delete_btn: Button
	var file_label: Label
	var meter_rect: Control
	var waveform_canvas: Control
	
	# Collapsible Automation Sub-Row
	var auto_row: HBoxContainer
	var auto_param_opt: OptionButton
	var auto_canvas: Control
	
	func evaluate_automation_value(ratio: float) -> float:
		if automation_points.is_empty():
			return 1.0
		if ratio <= automation_points[0].x:
			return automation_points[0].y
		if ratio >= automation_points[automation_points.size() - 1].x:
			return automation_points[automation_points.size() - 1].y
		for i in range(automation_points.size() - 1):
			var p0 = automation_points[i]
			var p1 = automation_points[i + 1]
			if ratio >= p0.x and ratio <= p1.x:
				var span = p1.x - p0.x
				if span <= 0.0001:
					return p0.y
				var t = (ratio - p0.x) / span
				return lerpf(p0.y, p1.y, t)
		return 1.0

var clock: MusicClock
var transition_matrix: MusicTransitionMatrix
var stinger_queue: MusicStingerQueue
var playlist_manager: MusicPlaylistManager

# Toolbar Controls
var play_btn: Button
var pause_btn: Button
var stop_btn: Button
var loop_btn: Button

var bpm_spinbox: SpinBox
var metronome_btn: Button
var snap_selector: OptionButton
var zoom_spinbox: SpinBox
var intensity_slider: HSlider
var intensity_lbl: Label
var beat_counter_lbl: Label
var btn_add_track: Button

# Center Sequencer
var ruler_canvas: Control
var scroll_container: ScrollContainer
var lanes_vbox: VBoxContainer
var tracks: Array[TrackLaneData] = []

# Structural Cues & Post-Exit Tails (Wwise / FMOD Standard)
var entry_cue_bar: float = 0.0 # 0.0 = Bar 1 Beat 1 (can be negative, e.g. -1.0 for pickups/anacrusas)
var exit_cue_bar: float = 8.0 # Bar position where loop cycles or exits
var post_exit_tail_sec: float = 2.0 # Reverb/cymbal decay duration
var dragging_cue_marker: int = 0 # 1 = entry cue, 2 = exit cue

# Right Matrix & Playlist Tabs
var right_tab_container: TabContainer
var transition_target_opt: OptionButton
var sync_mode_opt: OptionButton
var fade_duration_spinbox: SpinBox
var tail_duration_spinbox: SpinBox
var btn_stinger_victory: Button
var btn_stinger_danger: Button

# Playlist Sequencer Controls (TASK-033)
var playlist_item_list: ItemList
var btn_playlist_add: Button
var btn_playlist_up: Button
var btn_playlist_down: Button
var btn_playlist_del: Button
var btn_playlist_loop: Button
var btn_playlist_play: Button
var is_playlist_mode: bool = false

# Playback & Dragging State
var is_playing: bool = false
var is_paused: bool = false
var is_dirty: bool = false
var zoom_factor: float = 1.0 # 0.5 to 3.0
var active_intensity: float = 0.0
var current_playhead_ratio: float = 0.0
var last_reported_beat: int = -1
var active_suite_name: StringName = &"Dynamic_Combat_Suite.tres"

# File Dialog & Trim Handle Dragging
var file_dialog: FileDialog
var pending_file_track_index: int = -1
var dragging_trim_track: TrackLaneData = null
var dragging_trim_handle: int = 0 # 1 = left, 2 = right
var dragging_auto_track: TrackLaneData = null

# Audio Players & Tail Decay Buffers
var metronome_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var stem_players: Array[AudioStreamPlayer] = []
var tail_decay_players: Array[AudioStreamPlayer] = []

func _init() -> void:
	clock = MusicClockClass.new(120.0, 4, 4)
	transition_matrix = MusicTransitionMatrixClass.new()
	stinger_queue = MusicStingerQueueClass.new()
	playlist_manager = MusicPlaylistManagerClass.new()
	
	# Default playlist entries
	playlist_manager.add_item(&"Combat_Intro", 1, 1)
	playlist_manager.add_item(&"Combat_Loop", 2, 4)
	playlist_manager.add_item(&"Boss_Encounter", 1, 2)
	playlist_manager.add_item(&"Victory_Outro", 1, 1)
	
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	load_from_disk(active_suite_name)

func _build_ui() -> void:
	# Audio Players
	metronome_player = AudioStreamPlayer.new()
	add_child(metronome_player)
	
	stinger_player = AudioStreamPlayer.new()
	stinger_player.finished.connect(_on_stinger_finished)
	add_child(stinger_player)
	
	# File Dialog for audio clips
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.wav ; WAV Audio", "*.ogg ; OGG Vorbis"]
	file_dialog.file_selected.connect(_on_audio_file_selected)
	add_child(file_dialog)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)
	
	# 1. Top Transport & Rhythmic Settings Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	
	var title_lbl = Label.new()
	title_lbl.text = "🎼 Music DAW"
	title_lbl.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(title_lbl)
	
	toolbar.add_child(VSeparator.new())
	
	# Dedicated DAW Transport Controls
	play_btn = Button.new()
	play_btn.text = "▶ Play"
	play_btn.tooltip_text = "Start Interactive Music Sequencer"
	play_btn.pressed.connect(_on_music_play_pressed)
	toolbar.add_child(play_btn)
	
	pause_btn = Button.new()
	pause_btn.text = "⏸ Pause"
	pause_btn.tooltip_text = "Pause Sequencer Playhead"
	pause_btn.pressed.connect(_on_music_pause_pressed)
	toolbar.add_child(pause_btn)
	
	stop_btn = Button.new()
	stop_btn.text = "⏹ Stop"
	stop_btn.tooltip_text = "Stop & Rewind to Bar 1 Beat 1"
	stop_btn.pressed.connect(_on_music_stop_pressed)
	toolbar.add_child(stop_btn)
	
	loop_btn = Button.new()
	loop_btn.text = "🔁 Loop"
	loop_btn.tooltip_text = "Loop 8-Bar Segment"
	loop_btn.toggle_mode = true
	loop_btn.button_pressed = true
	toolbar.add_child(loop_btn)
	
	toolbar.add_child(VSeparator.new())
	
	# BPM
	var bpm_lbl = Label.new()
	bpm_lbl.text = "BPM:"
	bpm_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(bpm_lbl)
	
	bpm_spinbox = SpinBox.new()
	bpm_spinbox.min_value = 40.0
	bpm_spinbox.max_value = 240.0
	bpm_spinbox.value = 120.0
	bpm_spinbox.step = 1.0
	bpm_spinbox.value_changed.connect(_on_bpm_changed)
	toolbar.add_child(bpm_spinbox)
	
	# Metronome Toggle
	metronome_btn = Button.new()
	metronome_btn.text = "🔔 Metronome"
	metronome_btn.tooltip_text = "Enable Audible Metronome Click on Beats"
	metronome_btn.toggle_mode = true
	toolbar.add_child(metronome_btn)
	
	toolbar.add_child(VSeparator.new())
	
	# Snap to Grid
	var snap_lbl = Label.new()
	snap_lbl.text = "Snap:"
	snap_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(snap_lbl)
	
	snap_selector = OptionButton.new()
	snap_selector.add_item("🧲 1 Bar", 0)
	snap_selector.add_item("🧲 1/2 Bar", 1)
	snap_selector.add_item("🧲 1 Beat", 2)
	snap_selector.add_item("🧲 1/2 Beat", 3)
	snap_selector.add_item("Off", 4)
	toolbar.add_child(snap_selector)
	
	# Horizontal Zoom
	var zoom_lbl = Label.new()
	zoom_lbl.text = "Zoom:"
	zoom_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(zoom_lbl)
	
	zoom_spinbox = SpinBox.new()
	zoom_spinbox.min_value = 50.0
	zoom_spinbox.max_value = 300.0
	zoom_spinbox.value = 100.0
	zoom_spinbox.step = 10.0
	zoom_spinbox.suffix = "%"
	zoom_spinbox.value_changed.connect(func(v):
		zoom_factor = v / 100.0
		if ruler_canvas: ruler_canvas.queue_redraw()
		for t in tracks:
			if t.waveform_canvas: t.waveform_canvas.queue_redraw()
			if t.auto_canvas: t.auto_canvas.queue_redraw()
	)
	toolbar.add_child(zoom_spinbox)
	
	toolbar.add_child(VSeparator.new())
	
	# Real-time Beat & Bar Counter
	beat_counter_lbl = Label.new()
	beat_counter_lbl.text = "⏱️ Bar 1 : Beat 1.0"
	beat_counter_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(beat_counter_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	# Combat Intensity Slider
	var int_lbl = Label.new()
	int_lbl.text = "Intensity:"
	int_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(int_lbl)
	
	intensity_slider = HSlider.new()
	intensity_slider.min_value = 0.0
	intensity_slider.max_value = 1.0
	intensity_slider.step = 0.01
	intensity_slider.value = 0.0
	intensity_slider.custom_minimum_size = Vector2(130, 20)
	intensity_slider.value_changed.connect(_on_intensity_slider_changed)
	toolbar.add_child(intensity_slider)
	
	intensity_lbl = Label.new()
	intensity_lbl.text = "0% (Explore)"
	intensity_lbl.add_theme_font_size_override("font_size", 10)
	intensity_lbl.custom_minimum_size = Vector2(85, 0)
	toolbar.add_child(intensity_lbl)
	
	main_vbox.add_child(toolbar)
	
	# 2. Main Splitter (DAW Multi-Track Lanes on Left, Inspector Tabs on Right)
	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	main_vbox.add_child(split)
	
	# Sequencer Container
	var seq_vbox = VBoxContainer.new()
	seq_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seq_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seq_vbox.add_theme_constant_override("separation", 4)
	
	# Header Row (Left corner spacer with [+ Add Track] + Rhythmic Timeline Ruler)
	var ruler_row = HBoxContainer.new()
	ruler_row.add_theme_constant_override("separation", 6)
	
	var track_header_spacer = PanelContainer.new()
	track_header_spacer.custom_minimum_size = Vector2(250, 34)
	
	var spacer_hbox = HBoxContainer.new()
	spacer_hbox.add_theme_constant_override("margin_left", 6)
	spacer_hbox.add_theme_constant_override("margin_right", 6)
	spacer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_header_spacer.add_child(spacer_hbox)
	
	var spacer_lbl = Label.new()
	spacer_lbl.text = "Tracks / Stems"
	spacer_lbl.add_theme_font_size_override("font_size", 11)
	spacer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spacer_hbox.add_child(spacer_lbl)
	
	btn_add_track = Button.new()
	btn_add_track.text = "➕ Add Track"
	btn_add_track.tooltip_text = "Add new custom audio stem layer"
	btn_add_track.custom_minimum_size = Vector2(85, 24)
	btn_add_track.pressed.connect(func(): add_new_custom_track())
	spacer_hbox.add_child(btn_add_track)
	
	ruler_row.add_child(track_header_spacer)
	
	ruler_canvas = Control.new()
	ruler_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ruler_canvas.custom_minimum_size = Vector2(0, 34)
	ruler_canvas.draw.connect(_on_draw_timeline_ruler)
	ruler_canvas.gui_input.connect(_on_ruler_gui_input)
	ruler_row.add_child(ruler_canvas)
	seq_vbox.add_child(ruler_row)
	
	# Multi-Track Lanes Stack inside functional ScrollContainer
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	lanes_vbox = VBoxContainer.new()
	lanes_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes_vbox.add_theme_constant_override("separation", 6)
	scroll_container.add_child(lanes_vbox)
	seq_vbox.add_child(scroll_container)
	
	split.add_child(seq_vbox)
	
	# 3. Right Inspector TabContainer (Transitions & Playlist Sequencer)
	right_tab_container = TabContainer.new()
	right_tab_container.custom_minimum_size = Vector2(250, 0)
	
	# Tab 1: Transitions & Stingers
	var trans_tab = VBoxContainer.new()
	trans_tab.name = "🔀 Transitions"
	trans_tab.add_theme_constant_override("separation", 8)
	
	var trans_title = Label.new()
	trans_title.text = "Quantized Transition Matrix"
	trans_title.add_theme_font_size_override("font_size", 11)
	trans_tab.add_child(trans_title)
	
	var target_lbl = Label.new()
	target_lbl.text = "Target Segment:"
	target_lbl.add_theme_font_size_override("font_size", 10)
	trans_tab.add_child(target_lbl)
	
	transition_target_opt = OptionButton.new()
	transition_target_opt.add_item("Segment: Combat_Loop", 0)
	transition_target_opt.add_item("Segment: Exploration_Pads", 1)
	transition_target_opt.add_item("Segment: Boss_Encounter", 2)
	transition_target_opt.add_item("Segment: Victory_Outro", 3)
	transition_target_opt.item_selected.connect(func(_idx): mark_dirty(true))
	trans_tab.add_child(transition_target_opt)
	
	var sync_lbl = Label.new()
	sync_lbl.text = "Quantize Exit Rule:"
	sync_lbl.add_theme_font_size_override("font_size", 10)
	trans_tab.add_child(sync_lbl)
	
	sync_mode_opt = OptionButton.new()
	sync_mode_opt.add_item("⏱️ Next Bar (Downbeat)", 0)
	sync_mode_opt.add_item("🎵 Next Beat", 1)
	sync_mode_opt.add_item("⚡ Immediate", 2)
	sync_mode_opt.item_selected.connect(func(_idx): mark_dirty(true))
	trans_tab.add_child(sync_mode_opt)
	
	var fade_lbl = Label.new()
	fade_lbl.text = "Crossfade Duration (s):"
	fade_lbl.add_theme_font_size_override("font_size", 10)
	trans_tab.add_child(fade_lbl)
	
	fade_duration_spinbox = SpinBox.new()
	fade_duration_spinbox.min_value = 0.1
	fade_duration_spinbox.max_value = 4.0
	fade_duration_spinbox.step = 0.1
	fade_duration_spinbox.value = 1.5
	fade_duration_spinbox.value_changed.connect(func(_v): mark_dirty(true))
	trans_tab.add_child(fade_duration_spinbox)
	
	var tail_lbl = Label.new()
	tail_lbl.text = "Post-Exit Tail (s):"
	tail_lbl.add_theme_font_size_override("font_size", 10)
	trans_tab.add_child(tail_lbl)
	
	tail_duration_spinbox = SpinBox.new()
	tail_duration_spinbox.min_value = 0.5
	tail_duration_spinbox.max_value = 5.0
	tail_duration_spinbox.step = 0.1
	tail_duration_spinbox.value = post_exit_tail_sec
	tail_duration_spinbox.value_changed.connect(func(v):
		post_exit_tail_sec = v
		if ruler_canvas: ruler_canvas.queue_redraw()
		mark_dirty(true)
	)
	trans_tab.add_child(tail_duration_spinbox)
	
	var btn_trigger_trans = Button.new()
	btn_trigger_trans.text = "🔀 Trigger Transition"
	btn_trigger_trans.pressed.connect(_on_trigger_transition_pressed)
	trans_tab.add_child(btn_trigger_trans)
	
	trans_tab.add_child(HSeparator.new())
	
	var stinger_title = Label.new()
	stinger_title.text = "💥 Rhythmic Stingers"
	stinger_title.add_theme_font_size_override("font_size", 11)
	trans_tab.add_child(stinger_title)
	
	btn_stinger_victory = Button.new()
	btn_stinger_victory.text = "🎺 Stinger: Victory_Brass"
	btn_stinger_victory.toggle_mode = true
	btn_stinger_victory.toggled.connect(func(is_on: bool):
		if is_on:
			if btn_stinger_danger:
				btn_stinger_danger.set_pressed_no_signal(false)
				btn_stinger_danger.text = "⚠️ Stinger: Danger_Hit"
				btn_stinger_danger.modulate = Color.WHITE
			btn_stinger_victory.text = "⏹ Stop: Victory_Brass"
			btn_stinger_victory.modulate = Color(0.4, 1.0, 0.4)
			play_audition_stinger(&"Victory_Brass")
			stinger_requested.emit(&"Victory_Brass", 0)
		else:
			btn_stinger_victory.text = "🎺 Stinger: Victory_Brass"
			btn_stinger_victory.modulate = Color.WHITE
			stop_audition_stinger()
	)
	trans_tab.add_child(btn_stinger_victory)
	
	btn_stinger_danger = Button.new()
	btn_stinger_danger.text = "⚠️ Stinger: Danger_Hit"
	btn_stinger_danger.toggle_mode = true
	btn_stinger_danger.toggled.connect(func(is_on: bool):
		if is_on:
			if btn_stinger_victory:
				btn_stinger_victory.set_pressed_no_signal(false)
				btn_stinger_victory.text = "🎺 Stinger: Victory_Brass"
				btn_stinger_victory.modulate = Color.WHITE
			btn_stinger_danger.text = "⏹ Stop: Danger_Hit"
			btn_stinger_danger.modulate = Color(1.0, 0.4, 0.3)
			play_audition_stinger(&"Danger_Hit")
			stinger_requested.emit(&"Danger_Hit", 1)
		else:
			btn_stinger_danger.text = "⚠️ Stinger: Danger_Hit"
			btn_stinger_danger.modulate = Color.WHITE
			stop_audition_stinger()
	)
	trans_tab.add_child(btn_stinger_danger)
	
	right_tab_container.add_child(trans_tab)
	
	# Tab 2: Playlist Sequencer & Hierarchy (TASK-033)
	var play_tab = VBoxContainer.new()
	play_tab.name = "🎼 Playlist"
	play_tab.add_theme_constant_override("separation", 6)
	
	var play_toolbar = HBoxContainer.new()
	play_toolbar.add_theme_constant_override("separation", 4)
	
	btn_playlist_play = Button.new()
	btn_playlist_play.text = "▶ Play List"
	btn_playlist_play.tooltip_text = "Execute Non-Linear Music Playlist Hierarchy"
	btn_playlist_play.toggle_mode = true
	btn_playlist_play.toggled.connect(_on_playlist_play_toggled)
	play_toolbar.add_child(btn_playlist_play)
	
	btn_playlist_loop = Button.new()
	btn_playlist_loop.text = "🔁"
	btn_playlist_loop.tooltip_text = "Loop entire playlist sequence"
	btn_playlist_loop.toggle_mode = true
	btn_playlist_loop.button_pressed = true
	btn_playlist_loop.toggled.connect(func(is_l):
		if playlist_manager: playlist_manager.is_looping_playlist = is_l
		mark_dirty(true)
	)
	play_toolbar.add_child(btn_playlist_loop)
	
	btn_playlist_add = Button.new()
	btn_playlist_add.text = "➕"
	btn_playlist_add.tooltip_text = "Add Segment to Playlist"
	btn_playlist_add.pressed.connect(func():
		var target_seg = transition_target_opt.get_item_text(transition_target_opt.selected).replace("Segment: ", "")
		playlist_manager.add_item(StringName(target_seg), 1, 2)
		_refresh_playlist_ui()
		mark_dirty(true)
	)
	play_toolbar.add_child(btn_playlist_add)
	
	btn_playlist_up = Button.new()
	btn_playlist_up.text = "⬆️"
	btn_playlist_up.tooltip_text = "Move Selected Segment Up"
	btn_playlist_up.pressed.connect(func():
		var sel = playlist_item_list.get_selected_items()
		if sel.size() > 0:
			playlist_manager.move_item_up(sel[0])
			_refresh_playlist_ui()
			mark_dirty(true)
	)
	play_toolbar.add_child(btn_playlist_up)
	
	btn_playlist_down = Button.new()
	btn_playlist_down.text = "⬇️"
	btn_playlist_down.tooltip_text = "Move Selected Segment Down"
	btn_playlist_down.pressed.connect(func():
		var sel = playlist_item_list.get_selected_items()
		if sel.size() > 0:
			playlist_manager.move_item_down(sel[0])
			_refresh_playlist_ui()
			mark_dirty(true)
	)
	play_toolbar.add_child(btn_playlist_down)
	
	btn_playlist_del = Button.new()
	btn_playlist_del.text = "🗑️"
	btn_playlist_del.tooltip_text = "Remove Selected Segment from Playlist"
	btn_playlist_del.pressed.connect(func():
		var sel = playlist_item_list.get_selected_items()
		if sel.size() > 0:
			playlist_manager.remove_item_at(sel[0])
			_refresh_playlist_ui()
			mark_dirty(true)
	)
	play_toolbar.add_child(btn_playlist_del)
	
	play_tab.add_child(play_toolbar)
	
	playlist_item_list = ItemList.new()
	playlist_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playlist_item_list.custom_minimum_size = Vector2(0, 180)
	play_tab.add_child(playlist_item_list)
	
	right_tab_container.add_child(play_tab)
	split.add_child(right_tab_container)
	
	_refresh_playlist_ui()

func _refresh_playlist_ui() -> void:
	if not playlist_item_list or not playlist_manager:
		return
	playlist_item_list.clear()
	for i in range(playlist_manager.items.size()):
		var it = playlist_manager.items[i]
		var is_cur = (playlist_manager.is_active and playlist_manager.current_index == i)
		var prefix = "▶ " if is_cur else "  "
		var loops_str = "%dx" % it.loop_count_min if it.loop_count_min == it.loop_count_max else "%d-%dx" % [it.loop_count_min, it.loop_count_max]
		playlist_item_list.add_item("%s%d. %s (%s)" % [prefix, i + 1, it.segment_name, loops_str])
		if is_cur:
			playlist_item_list.set_item_custom_fg_color(i, Color(0.3, 1.0, 0.4))

func _on_playlist_play_toggled(is_on: bool) -> void:
	is_playlist_mode = is_on
	if is_on:
		btn_playlist_play.text = "⏹ Stop List"
		btn_playlist_play.modulate = Color(0.3, 1.0, 0.4)
		var first_seg = playlist_manager.start_playlist()
		_refresh_playlist_ui()
		if not first_seg.is_empty():
			playlist_segment_changed.emit(first_seg)
		_on_music_play_pressed()
	else:
		btn_playlist_play.text = "▶ Play List"
		btn_playlist_play.modulate = Color.WHITE
		playlist_manager.stop_playlist()
		_refresh_playlist_ui()
		_on_music_stop_pressed()

## Marks the DAW as dirty or clean, notifying parent editor.
func mark_dirty(dirty: bool = true) -> void:
	if is_dirty != dirty:
		is_dirty = dirty
		dirty_changed.emit(is_dirty)

## Adds a new customizable stem track with interactive header, file picker, variation button, bus routing, automation sub-lane, delete button, and waveform canvas.
func _add_track(track_name: String, min_int: float, max_int: float, color: Color, audio_path: String = "", left_t: float = 0.0, right_t: float = 1.0, p_bus: StringName = &"Master") -> TrackLaneData:
	var t = TrackLaneData.new()
	t.name = track_name
	t.min_intensity = min_int
	t.max_intensity = max_int
	t.color = color
	t.audio_file_path = audio_path
	t.left_trim_ratio = left_t
	t.right_trim_ratio = right_t
	t.bus_name = p_bus
	t.sub_tracks = [{"name": "Var 1", "audio_path": audio_path, "weight": 1.0}]
	
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 6)
	t.row_container = row
	
	# 1. Track Header (Left Panel, 250px)
	var header = PanelContainer.new()
	header.custom_minimum_size = Vector2(250, 60)
	t.header_panel = header
	
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	header.add_child(header_hbox)
	
	# Color badge
	var badge = ColorRect.new()
	badge.color = color
	badge.custom_minimum_size = Vector2(4, 48)
	header_hbox.add_child(badge)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	
	# Top line: Track Title + Var Button + Delete button
	var top_title_box = HBoxContainer.new()
	top_title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_title_box.add_theme_constant_override("separation", 4)
	
	var name_lbl = Label.new()
	name_lbl.text = track_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_title_box.add_child(name_lbl)
	
	# Random Variation Button
	var v_btn = Button.new()
	v_btn.text = "🎲 1"
	v_btn.tooltip_text = "Add / Cycle Random Sub-Tracks for this layer"
	v_btn.custom_minimum_size = Vector2(26, 18)
	v_btn.pressed.connect(func(): _on_track_variation_clicked(t))
	t.var_btn = v_btn
	top_title_box.add_child(v_btn)
	
	# File Picker Button
	var f_btn = Button.new()
	f_btn.text = "📁"
	f_btn.tooltip_text = "Select Audio File (.wav/.ogg)"
	f_btn.custom_minimum_size = Vector2(22, 18)
	f_btn.pressed.connect(func(): open_file_dialog_for_track(tracks.find(t)))
	t.file_btn = f_btn
	top_title_box.add_child(f_btn)
	
	# Delete Track Button
	var del_btn = Button.new()
	del_btn.text = "🗑️"
	del_btn.tooltip_text = "Delete Track"
	del_btn.custom_minimum_size = Vector2(22, 18)
	del_btn.pressed.connect(func(): delete_track(t))
	t.delete_btn = del_btn
	top_title_box.add_child(del_btn)
	
	info_vbox.add_child(top_title_box)
	
	# Middle line: Controls (Mute, Solo, Vol Slider, Auto toggle)
	var controls_hbox = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 4)
	
	# Mute Button
	var m_btn = Button.new()
	m_btn.text = "M"
	m_btn.tooltip_text = "Mute Track"
	m_btn.toggle_mode = true
	m_btn.custom_minimum_size = Vector2(20, 18)
	m_btn.toggled.connect(func(is_m):
		t.is_muted = is_m
		m_btn.modulate = Color(1.0, 0.3, 0.3) if is_m else Color.WHITE
		_update_stem_levels()
		mark_dirty(true)
	)
	t.mute_btn = m_btn
	controls_hbox.add_child(m_btn)
	
	# Solo Button
	var s_btn = Button.new()
	s_btn.text = "S"
	s_btn.tooltip_text = "Solo Track"
	s_btn.toggle_mode = true
	s_btn.custom_minimum_size = Vector2(20, 18)
	s_btn.toggled.connect(func(is_s):
		t.is_solo = is_s
		s_btn.modulate = Color(1.0, 0.9, 0.2) if is_s else Color.WHITE
		_update_stem_levels()
		mark_dirty(true)
	)
	t.solo_btn = s_btn
	controls_hbox.add_child(s_btn)
	
	# Volume Slider
	var vol_slider = HSlider.new()
	vol_slider.min_value = -24.0
	vol_slider.max_value = 6.0
	vol_slider.value = t.volume_db
	vol_slider.step = 0.5
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.custom_minimum_size = Vector2(40, 0)
	vol_slider.value_changed.connect(func(v):
		t.volume_db = v
		_update_stem_levels()
		mark_dirty(true)
	)
	t.vol_slider = vol_slider
	controls_hbox.add_child(vol_slider)
	
	# Automation Toggle Button
	var a_btn = Button.new()
	a_btn.text = "📈"
	a_btn.tooltip_text = "Toggle Automation Sub-Lane"
	a_btn.toggle_mode = true
	a_btn.custom_minimum_size = Vector2(24, 18)
	a_btn.toggled.connect(func(is_on):
		t.automation_enabled = is_on
		a_btn.modulate = Color(1.0, 0.85, 0.2) if is_on else Color.WHITE
		if t.auto_row:
			t.auto_row.visible = is_on
		_update_stem_levels()
		mark_dirty(true)
	)
	t.auto_btn = a_btn
	controls_hbox.add_child(a_btn)
	
	info_vbox.add_child(controls_hbox)
	
	# Bottom line: Audio Bus Selector & File Path Preview
	var btm_hbox = HBoxContainer.new()
	btm_hbox.add_theme_constant_override("separation", 4)
	
	var bus_selector = OptionButton.new()
	bus_selector.add_item("Master", 0)
	bus_selector.add_item("Music", 1)
	bus_selector.add_item("Music_Percussion", 2)
	bus_selector.add_item("Music_Pads", 3)
	bus_selector.add_item("Music_Leads", 4)
	bus_selector.custom_minimum_size = Vector2(75, 16)
	bus_selector.item_selected.connect(func(idx):
		var b_name = bus_selector.get_item_text(idx)
		t.bus_name = StringName(b_name)
		var trk_idx = tracks.find(t)
		if trk_idx >= 0 and trk_idx < stem_players.size():
			stem_players[trk_idx].bus = t.bus_name
		mark_dirty(true)
	)
	t.bus_opt = bus_selector
	btm_hbox.add_child(bus_selector)
	
	var path_lbl = Label.new()
	path_lbl.text = audio_path.get_file() if not audio_path.is_empty() else "Procedural Synth"
	path_lbl.add_theme_font_size_override("font_size", 8)
	path_lbl.modulate = Color(0.6, 0.7, 0.8)
	path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.file_label = path_lbl
	btm_hbox.add_child(path_lbl)
	
	info_vbox.add_child(btm_hbox)
	header_hbox.add_child(info_vbox)
	
	# Live LED Meter Bar
	var meter = Control.new()
	meter.custom_minimum_size = Vector2(8, 48)
	meter.draw.connect(func():
		var s = meter.size
		meter.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.12, 0.15, 1.0))
		var fill_h = s.y * clampf(t.current_gain, 0.0, 1.0)
		var fill_rect = Rect2(Vector2(1, s.y - fill_h + 1), Vector2(s.x - 2, fill_h - 2))
		var c = Color(0.2, 0.85, 0.4) if t.current_gain < 0.75 else (Color(0.95, 0.7, 0.2) if t.current_gain < 0.95 else Color(0.95, 0.25, 0.25))
		if t.current_gain > 0.01:
			meter.draw_rect(fill_rect, c)
	)
	t.meter_rect = meter
	header_hbox.add_child(meter)
	
	row.add_child(header)
	
	# 2. Interactive Waveform Clip Canvas with Trim Handles
	var wave_canvas = Control.new()
	wave_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_canvas.custom_minimum_size = Vector2(0, 60)
	wave_canvas.draw.connect(func(): _on_draw_track_waveform(t, wave_canvas))
	wave_canvas.gui_input.connect(func(ev): _on_waveform_gui_input(t, wave_canvas, ev))
	t.waveform_canvas = wave_canvas
	row.add_child(wave_canvas)
	
	tracks.append(t)
	lanes_vbox.add_child(row)
	
	# 3. Expandable Automation Sub-Lane (TASK-032)
	var auto_row = HBoxContainer.new()
	auto_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.custom_minimum_size = Vector2(0, 36)
	auto_row.add_theme_constant_override("separation", 6)
	auto_row.visible = false
	t.auto_row = auto_row
	
	var auto_header = PanelContainer.new()
	auto_header.custom_minimum_size = Vector2(250, 36)
	var auto_header_box = HBoxContainer.new()
	auto_header_box.add_theme_constant_override("margin_left", 8)
	auto_header_box.add_theme_constant_override("separation", 6)
	auto_header_box.add_child(auto_header_box)
	
	var auto_lbl = Label.new()
	auto_lbl.text = "📈 Curve:"
	auto_lbl.add_theme_font_size_override("font_size", 9)
	auto_header_box.add_child(auto_lbl)
	
	var param_opt = OptionButton.new()
	param_opt.add_item("🔊 Volume", 0)
	param_opt.add_item("🎛️ LPF Cutoff", 1)
	param_opt.add_item("⚡ CombatIntensity", 2)
	param_opt.custom_minimum_size = Vector2(140, 20)
	param_opt.item_selected.connect(func(idx):
		t.automation_parameter = idx
		mark_dirty(true)
	)
	t.auto_param_opt = param_opt
	auto_header_box.add_child(param_opt)
	auto_row.add_child(auto_header)
	
	var auto_canvas = Control.new()
	auto_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_canvas.custom_minimum_size = Vector2(0, 36)
	auto_canvas.draw.connect(func(): _on_draw_automation_curve(t, auto_canvas))
	auto_canvas.gui_input.connect(func(ev): _on_automation_gui_input(t, auto_canvas, ev))
	t.auto_canvas = auto_canvas
	auto_row.add_child(auto_canvas)
	
	lanes_vbox.add_child(auto_row)
	
	# Add matching audio player for this stem
	var p = AudioStreamPlayer.new()
	p.bus = p_bus
	add_child(p)
	p.volume_db = -80.0
	_assign_default_or_file_stream(p, tracks.size() - 1, audio_path)
	stem_players.append(p)
	
	return t

## Clicking the variation button adds or cycles random sub-tracks.
func _on_track_variation_clicked(t: TrackLaneData) -> void:
	var next_num = t.sub_tracks.size() + 1
	var new_var_name = "Var %d" % next_num
	t.sub_tracks.append({"name": new_var_name, "audio_path": t.audio_file_path, "weight": 1.0})
	t.active_sub_index = t.sub_tracks.size() - 1
	if t.var_btn:
		t.var_btn.text = "🎲 %d" % t.sub_tracks.size()
	if t.file_label:
		t.file_label.text = "%s (%s)" % [t.audio_file_path.get_file() if not t.audio_file_path.is_empty() else "Procedural Synth", new_var_name]
	mark_dirty(true)

## Randomly selects sub-tracks on loop completion.
func _pick_random_variations_on_loop() -> void:
	for i in range(tracks.size()):
		var t = tracks[i]
		if t.is_random_mode and t.sub_tracks.size() > 1:
			var rand_idx = randi() % t.sub_tracks.size()
			t.active_sub_index = rand_idx
			var sub_data = t.sub_tracks[rand_idx]
			var path = str(sub_data.get("audio_path", ""))
			if i < stem_players.size() and stem_players[i]:
				_assign_default_or_file_stream(stem_players[i], i, path)
			if t.file_label:
				var fn = path.get_file() if not path.is_empty() else "Procedural Synth"
				t.file_label.text = "%s (%s)" % [fn, str(sub_data.get("name", "Var"))]

func _assign_default_or_file_stream(player: AudioStreamPlayer, idx: int, audio_path: String) -> void:
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		var res = ResourceLoader.load(audio_path)
		if res is AudioStream:
			player.stream = res
			return
	match idx % 4:
		0: player.stream = AudioSynthesizerClass.create_music_pad_loop(2.0)
		1: player.stream = AudioSynthesizerClass.create_music_bass_loop(2.0)
		2: player.stream = AudioSynthesizerClass.create_music_drums_loop(2.0)
		3: player.stream = AudioSynthesizerClass.create_music_brass_loop(2.0)

## Adds a new custom track dynamically.
func add_new_custom_track(custom_name: String = "") -> void:
	var next_idx = tracks.size() + 1
	var t_name = custom_name if not custom_name.is_empty() else "Layer %d: Stem_%d" % [next_idx, next_idx]
	var colors = [Color(0.2, 0.75, 0.95), Color(0.3, 0.85, 0.45), Color(0.98, 0.65, 0.22), Color(0.98, 0.25, 0.35), Color(0.75, 0.4, 0.95)]
	var col = colors[(next_idx - 1) % colors.size()]
	_add_track(t_name, 0.0, 1.0, col)
	_update_stem_levels()
	mark_dirty(true)
	track_added.emit(t_name)

## Deletes an existing track dynamically.
func delete_track(t: TrackLaneData) -> void:
	var idx = tracks.find(t)
	if idx >= 0:
		var deleted_name = t.name
		if t.row_container:
			t.row_container.queue_free()
		if t.auto_row:
			t.auto_row.queue_free()
		tracks.remove_at(idx)
		if idx < stem_players.size():
			var p = stem_players[idx]
			stem_players.remove_at(idx)
			p.queue_free()
		_update_stem_levels()
		mark_dirty(true)
		track_deleted.emit(deleted_name)

func open_file_dialog_for_track(idx: int) -> void:
	if idx >= 0 and idx < tracks.size():
		pending_file_track_index = idx
		if file_dialog:
			file_dialog.popup_centered(Vector2i(700, 450))

func _on_audio_file_selected(path: String) -> void:
	if pending_file_track_index >= 0 and pending_file_track_index < tracks.size():
		var t = tracks[pending_file_track_index]
		t.audio_file_path = path
		if t.active_sub_index < t.sub_tracks.size():
			t.sub_tracks[t.active_sub_index]["audio_path"] = path
		if t.file_label:
			t.file_label.text = path.get_file()
		if pending_file_track_index < stem_players.size():
			_assign_default_or_file_stream(stem_players[pending_file_track_index], pending_file_track_index, path)
		if t.waveform_canvas:
			t.waveform_canvas.queue_redraw()
		mark_dirty(true)

## Handles mouse dragging on trim handles.
func _on_waveform_gui_input(t: TrackLaneData, canvas: Control, ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var size = canvas.size
				var total_w = size.x * zoom_factor
				var lx = t.left_trim_ratio * total_w
				var rx = t.right_trim_ratio * total_w
				if absf(mb.position.x - lx) <= 12.0:
					dragging_trim_track = t
					dragging_trim_handle = 1
				elif absf(mb.position.x - rx) <= 12.0:
					dragging_trim_track = t
					dragging_trim_handle = 2
			else:
				if dragging_trim_track:
					dragging_trim_track = null
					dragging_trim_handle = 0
					mark_dirty(true)
	elif ev is InputEventMouseMotion and dragging_trim_track == t:
		var mm = ev as InputEventMouseMotion
		var size = canvas.size
		var total_w = size.x * zoom_factor
		var ratio = clampf(mm.position.x / total_w, 0.0, 1.0)
		if dragging_trim_handle == 1:
			t.left_trim_ratio = minf(ratio, t.right_trim_ratio - 0.05)
		elif dragging_trim_handle == 2:
			t.right_trim_ratio = maxf(ratio, t.left_trim_ratio + 0.05)
		canvas.queue_redraw()

## Handles mouse clicking and point dragging on automation curve canvas.
func _on_automation_gui_input(t: TrackLaneData, canvas: Control, ev: InputEvent) -> void:
	var size = canvas.size
	var total_w = size.x * zoom_factor
	if ev is InputEventMouseButton:
		var mb = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var clicked_pt = -1
				for i in range(t.automation_points.size()):
					var pt = t.automation_points[i]
					var px = pt.x * total_w
					var py = (1.0 - pt.y) * size.y
					if mb.position.distance_to(Vector2(px, py)) <= 10.0:
						clicked_pt = i
						break
				if clicked_pt != -1:
					t.selected_point_index = clicked_pt
					dragging_auto_track = t
				else:
					var new_x = clampf(mb.position.x / total_w, 0.0, 1.0)
					var new_y = clampf(1.0 - (mb.position.y / size.y), 0.0, 1.0)
					t.automation_points.append(Vector2(new_x, new_y))
					t.automation_points.sort_custom(func(a, b): return a.x < b.x)
					t.selected_point_index = t.automation_points.find(Vector2(new_x, new_y))
					dragging_auto_track = t
					mark_dirty(true)
				canvas.queue_redraw()
			else:
				if dragging_auto_track == t:
					dragging_auto_track = null
					mark_dirty(true)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if t.automation_points.size() > 2:
				for i in range(t.automation_points.size()):
					var pt = t.automation_points[i]
					var px = pt.x * total_w
					var py = (1.0 - pt.y) * size.y
					if mb.position.distance_to(Vector2(px, py)) <= 10.0:
						t.automation_points.remove_at(i)
						canvas.queue_redraw()
						mark_dirty(true)
						break
	elif ev is InputEventMouseMotion and dragging_auto_track == t and t.selected_point_index >= 0 and t.selected_point_index < t.automation_points.size():
		var mm = ev as InputEventMouseMotion
		var new_x = clampf(mm.position.x / total_w, 0.0, 1.0)
		var new_y = clampf(1.0 - (mm.position.y / size.y), 0.0, 1.0)
		t.automation_points[t.selected_point_index] = Vector2(new_x, new_y)
		t.automation_points.sort_custom(func(a, b): return a.x < b.x)
		canvas.queue_redraw()

## Handles mouse dragging on timeline ruler for Entry and Exit cues.
func _on_ruler_gui_input(ev: InputEvent) -> void:
	if not ruler_canvas:
		return
	var size = ruler_canvas.size
	var bar_w = (size.x / 8.0) * zoom_factor
	var entry_x = entry_cue_bar * bar_w
	var exit_x = exit_cue_bar * bar_w
	
	if ev is InputEventMouseButton:
		var mb = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if absf(mb.position.x - entry_x) <= 14.0:
					dragging_cue_marker = 1
				elif absf(mb.position.x - exit_x) <= 14.0:
					dragging_cue_marker = 2
			else:
				if dragging_cue_marker != 0:
					dragging_cue_marker = 0
					mark_dirty(true)
	elif ev is InputEventMouseMotion and dragging_cue_marker != 0:
		var mm = ev as InputEventMouseMotion
		var bar_pos = mm.position.x / bar_w
		bar_pos = snappedf(bar_pos, 0.25)
		if dragging_cue_marker == 1:
			entry_cue_bar = clampf(bar_pos, -2.0, exit_cue_bar - 0.5)
		elif dragging_cue_marker == 2:
			exit_cue_bar = clampf(bar_pos, entry_cue_bar + 0.5, 16.0)
		ruler_canvas.queue_redraw()

## Persists the active music suites, tracks, cues, tails, bus routing, automation curves, and playlists to disk.
func save_to_disk() -> void:
	var root_dict = {}
	if FileAccess.file_exists(MUSIC_SUITES_SAVE_PATH):
		var file = FileAccess.open(MUSIC_SUITES_SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				root_dict = parsed
				
	var suite_data = {
		"bpm": clock.bpm if clock else 120.0,
		"intensity": active_intensity,
		"entry_cue": entry_cue_bar,
		"exit_cue": exit_cue_bar,
		"tail_sec": post_exit_tail_sec,
		"playlist": playlist_manager.serialize() if playlist_manager else [],
		"tracks": []
	}
	for t in tracks:
		var pts_arr = []
		for p in t.automation_points:
			pts_arr.append([p.x, p.y])
		suite_data["tracks"].append({
			"name": t.name,
			"min_intensity": t.min_intensity,
			"max_intensity": t.max_intensity,
			"color": t.color.to_html(false),
			"volume_db": t.volume_db,
			"is_muted": t.is_muted,
			"is_solo": t.is_solo,
			"bus_name": str(t.bus_name),
			"audio_file_path": t.audio_file_path,
			"left_trim": t.left_trim_ratio,
			"right_trim": t.right_trim_ratio,
			"sub_tracks": t.sub_tracks,
			"auto_enabled": t.automation_enabled,
			"auto_param": t.automation_parameter,
			"auto_points": pts_arr
		})
	root_dict[str(active_suite_name)] = suite_data
	
	var out_file = FileAccess.open(MUSIC_SUITES_SAVE_PATH, FileAccess.WRITE)
	if out_file:
		out_file.store_string(JSON.stringify(root_dict, "\t"))
		
	mark_dirty(false)

## Loads the active music suite configuration from disk, creating default tracks if not present.
func load_from_disk(suite_name: StringName) -> void:
	active_suite_name = suite_name
	for t in tracks:
		if t.row_container: t.row_container.queue_free()
		if t.auto_row: t.auto_row.queue_free()
	tracks.clear()
	for p in stem_players:
		p.queue_free()
	stem_players.clear()
	
	var loaded = false
	if FileAccess.file_exists(MUSIC_SUITES_SAVE_PATH):
		var file = FileAccess.open(MUSIC_SUITES_SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.has(str(suite_name)):
				var s_data = parsed[str(suite_name)]
				var bpm_val = float(s_data.get("bpm", 120.0))
				_on_bpm_changed(bpm_val)
				if bpm_spinbox: bpm_spinbox.value = bpm_val
				var int_val = float(s_data.get("intensity", 0.0))
				_on_intensity_slider_changed(int_val)
				if intensity_slider: intensity_slider.value = int_val
				
				entry_cue_bar = float(s_data.get("entry_cue", 0.0))
				exit_cue_bar = float(s_data.get("exit_cue", 8.0))
				post_exit_tail_sec = float(s_data.get("tail_sec", 2.0))
				if tail_duration_spinbox: tail_duration_spinbox.value = post_exit_tail_sec
				
				if s_data.has("playlist") and playlist_manager:
					var pl_arr = s_data.get("playlist")
					if pl_arr is Array:
						playlist_manager.deserialize(pl_arr)
						_refresh_playlist_ui()
				
				var track_list = s_data.get("tracks", [])
				for td in track_list:
					var col = Color.from_string(str(td.get("color", "ffffff")), Color.WHITE)
					var b_name = StringName(str(td.get("bus_name", "Master")))
					var t = _add_track(
						str(td.get("name", "Track")),
						float(td.get("min_intensity", 0.0)),
						float(td.get("max_intensity", 1.0)),
						col,
						str(td.get("audio_file_path", "")),
						float(td.get("left_trim", 0.0)),
						float(td.get("right_trim", 1.0)),
						b_name
					)
					t.volume_db = float(td.get("volume_db", 0.0))
					t.is_muted = bool(td.get("is_muted", false))
					t.is_solo = bool(td.get("is_solo", false))
					t.automation_enabled = bool(td.get("auto_enabled", false))
					t.automation_parameter = int(td.get("auto_param", 0))
					if td.has("auto_points"):
						var pts_raw = td.get("auto_points")
						if pts_raw is Array:
							t.automation_points.clear()
							for pt_pair in pts_raw:
								if pt_pair is Array and pt_pair.size() >= 2:
									t.automation_points.append(Vector2(float(pt_pair[0]), float(pt_pair[1])))
					if td.has("sub_tracks"):
						var arr = td.get("sub_tracks")
						if arr is Array:
							t.sub_tracks = arr
							if t.var_btn: t.var_btn.text = "🎲 %d" % t.sub_tracks.size()
					if t.vol_slider: t.vol_slider.value = t.volume_db
					if t.mute_btn: t.mute_btn.set_pressed_no_signal(t.is_muted)
					if t.solo_btn: t.solo_btn.set_pressed_no_signal(t.is_solo)
					if t.auto_btn: t.auto_btn.set_pressed_no_signal(t.automation_enabled)
					if t.auto_row: t.auto_row.visible = t.automation_enabled
					if t.auto_param_opt: t.auto_param_opt.selected = t.automation_parameter
				loaded = true
				
	if not loaded:
		# Fallback to default 4 interactive stems
		_add_track("Layer 1: Ambient_Pads", 0.0, 0.5, Color(0.2, 0.75, 0.95), "", 0.0, 1.0, &"Music_Pads")
		_add_track("Layer 2: Stealth_Bass", 0.2, 0.7, Color(0.3, 0.85, 0.45), "", 0.0, 1.0, &"Music")
		_add_track("Layer 3: Combat_Drums", 0.5, 1.0, Color(0.98, 0.65, 0.22), "", 0.0, 1.0, &"Music_Percussion")
		_add_track("Layer 4: Brass_Climax", 0.8, 1.0, Color(0.98, 0.25, 0.35), "", 0.0, 1.0, &"Music_Leads")
		entry_cue_bar = 0.0
		exit_cue_bar = 8.0
		post_exit_tail_sec = 2.0
		_on_intensity_slider_changed(0.0)
		
	_update_stem_levels()
	mark_dirty(false)

func get_ui_state() -> Dictionary:
	return {
		"zoom": zoom_factor,
		"intensity": active_intensity,
		"bpm": clock.bpm if clock else 120.0,
		"entry_cue": entry_cue_bar,
		"exit_cue": exit_cue_bar,
		"tail_sec": post_exit_tail_sec,
		"scroll_h": scroll_container.scroll_horizontal if scroll_container else 0,
		"scroll_v": scroll_container.scroll_vertical if scroll_container else 0
	}

func restore_ui_state(st: Dictionary) -> void:
	if st.has("zoom") and zoom_spinbox:
		zoom_spinbox.value = st["zoom"] * 100.0
	if st.has("intensity") and intensity_slider:
		intensity_slider.value = st["intensity"]
	if st.has("bpm") and bpm_spinbox:
		bpm_spinbox.value = st["bpm"]
	if st.has("entry_cue"):
		entry_cue_bar = st["entry_cue"]
	if st.has("exit_cue"):
		exit_cue_bar = st["exit_cue"]
	if st.has("tail_sec"):
		post_exit_tail_sec = st["tail_sec"]
		if tail_duration_spinbox: tail_duration_spinbox.value = post_exit_tail_sec
	if scroll_container:
		if st.has("scroll_h"): scroll_container.scroll_horizontal = st["scroll_h"]
		if st.has("scroll_v"): scroll_container.scroll_vertical = st["scroll_v"]
	if ruler_canvas: ruler_canvas.queue_redraw()

func _on_bpm_changed(val: float) -> void:
	if clock:
		clock.bpm = val
	bpm_changed.emit(val)
	mark_dirty(true)

func _on_intensity_slider_changed(val: float) -> void:
	active_intensity = val
	var pct = int(val * 100.0)
	var desc = "Explore" if val < 0.3 else ("Combat" if val < 0.75 else "Climax")
	intensity_lbl.text = "%d%% (%s)" % [pct, desc]
	_update_stem_levels()
	intensity_changed.emit(val)
	mark_dirty(true)

func load_music_suite(idx: int) -> void:
	var suites = [
		&"Dynamic_Combat_Suite.tres",
		&"Exploration_Ambient_Theme.tres",
		&"Boss_Phase_Orchestral.tres"
	]
	if idx >= 0 and idx < suites.size():
		load_from_disk(suites[idx])

func _update_stem_levels() -> void:
	var any_solo = false
	for t in tracks:
		if t.is_solo:
			any_solo = true
			break
			
	for i in range(tracks.size()):
		var t = tracks[i]
		var target_gain = 0.0
		if active_intensity >= t.min_intensity and active_intensity <= t.max_intensity:
			var fade = 0.15
			var raw_gain = 1.0
			if active_intensity < t.min_intensity + fade:
				raw_gain = (active_intensity - t.min_intensity) / fade
			elif active_intensity > t.max_intensity - fade:
				raw_gain = (t.max_intensity - active_intensity) / fade
			target_gain = clampf(raw_gain, 0.0, 1.0)
			
		# Apply Volume Slider, Mute, Solo
		var lin_vol = db_to_linear(t.volume_db)
		target_gain *= lin_vol
		
		# Apply Volume Automation Curve if active
		if t.automation_enabled and t.automation_parameter == 0:
			var auto_gain = t.evaluate_automation_value(current_playhead_ratio)
			target_gain *= auto_gain
		
		if t.is_muted:
			target_gain = 0.0
		elif any_solo and not t.is_solo:
			target_gain = 0.0
			
		t.current_gain = target_gain
		if t.meter_rect: t.meter_rect.queue_redraw()
		if t.waveform_canvas: t.waveform_canvas.queue_redraw()
		if t.auto_canvas and t.automation_enabled: t.auto_canvas.queue_redraw()
		
		# Drive dedicated stem audio player in real-time
		if i < stem_players.size() and stem_players[i]:
			if target_gain > 0.001:
				stem_players[i].volume_db = clampf(linear_to_db(target_gain), -60.0, 6.0)
			else:
				stem_players[i].volume_db = -80.0

## Triggers smooth transition with Post-Exit Reverb Tail Decayer buffers.
func _on_trigger_transition_pressed() -> void:
	var target_name = &"Combat_Loop"
	match transition_target_opt.selected:
		0: target_name = &"Combat_Loop"
		1: target_name = &"Exploration_Pads"
		2: target_name = &"Boss_Encounter"
		3: target_name = &"Victory_Outro"
	var sync_m = sync_mode_opt.selected
	var fade_t = fade_duration_spinbox.value
	
	# Spawn Post-Exit Tail Decayer for active stem layers
	if is_playing and post_exit_tail_sec > 0.01:
		for p in stem_players:
			if p.playing and p.volume_db > -60.0:
				var tail_p = AudioStreamPlayer.new()
				tail_p.stream = p.stream
				tail_p.volume_db = p.volume_db
				tail_p.bus = p.bus
				add_child(tail_p)
				tail_p.play(p.get_playback_position())
				tail_decay_players.append(tail_p)
				
				# Smooth exponential decay over post_exit_tail_sec
				var tw = create_tween()
				tw.tween_property(tail_p, "volume_db", -80.0, post_exit_tail_sec)
				tw.tween_callback(func():
					tail_decay_players.erase(tail_p)
					tail_p.queue_free()
				)
				
	transition_requested.emit(target_name, sync_m, fade_t)

func play_audition_stinger(stinger_name: StringName) -> void:
	if stinger_player:
		if "Victory" in str(stinger_name):
			stinger_player.stream = AudioSynthesizerClass.create_stinger_fanfare(1.5)
		else:
			stinger_player.stream = AudioSynthesizerClass.create_stinger_impact(1.2)
		stinger_player.volume_db = 2.0
		stinger_player.play()

func stop_audition_stinger() -> void:
	if stinger_player:
		stinger_player.stop()
	_reset_stinger_buttons()

func _on_stinger_finished() -> void:
	_reset_stinger_buttons()

func _reset_stinger_buttons() -> void:
	if btn_stinger_victory:
		btn_stinger_victory.set_pressed_no_signal(false)
		btn_stinger_victory.text = "🎺 Stinger: Victory_Brass"
		btn_stinger_victory.modulate = Color.WHITE
	if btn_stinger_danger:
		btn_stinger_danger.set_pressed_no_signal(false)
		btn_stinger_danger.text = "⚠️ Stinger: Danger_Hit"
		btn_stinger_danger.modulate = Color.WHITE

func _on_music_play_pressed() -> void:
	is_playing = true
	is_paused = false
	if play_btn:
		play_btn.text = "▶ Playing"
		play_btn.modulate = Color(0.3, 1.0, 0.4)
	if pause_btn:
		pause_btn.text = "⏸ Pause"
		
	_update_stem_levels()
	for p in stem_players:
		p.stream_paused = false
		if not p.playing:
			p.play()

func _on_music_pause_pressed() -> void:
	if not is_playing:
		return
	is_paused = not is_paused
	if pause_btn:
		pause_btn.text = "▶ Resume" if is_paused else "⏸ Pause"
	for p in stem_players:
		p.stream_paused = is_paused

func _on_music_stop_pressed() -> void:
	is_playing = false
	is_paused = false
	if play_btn:
		play_btn.text = "▶ Play"
		play_btn.modulate = Color.WHITE
	if pause_btn:
		pause_btn.text = "⏸ Pause"
		
	for p in stem_players:
		p.stop()
	for tp in tail_decay_players:
		tp.stop()
		tp.queue_free()
	tail_decay_players.clear()
		
	if clock:
		clock.current_time_sec = 0.0
		clock.current_beat = 0
		clock.current_bar = 0
		
	current_playhead_ratio = 0.0
	last_reported_beat = -1
	if beat_counter_lbl:
		beat_counter_lbl.text = "⏱️ Bar 1 : Beat 1.0"
	if ruler_canvas:
		ruler_canvas.queue_redraw()
	for t in tracks:
		if t.waveform_canvas:
			t.waveform_canvas.queue_redraw()
		if t.auto_canvas:
			t.auto_canvas.queue_redraw()

func _process(delta: float) -> void:
	if is_playing and not is_paused and clock:
		clock.update(delta)
		var loop_length = (exit_cue_bar - entry_cue_bar) * 2.0
		if loop_length <= 0.1: loop_length = 16.0
		
		current_playhead_ratio = fposmod(clock.current_time_sec / 16.0, 1.0)
		beat_counter_lbl.text = "⏱️ Bar %d : Beat %d.0" % [clock.current_bar + 1, clock.current_beat + 1]
		
		# Check loop or stop at end of active exit cue
		if clock.current_time_sec >= loop_length:
			if is_playlist_mode and playlist_manager and playlist_manager.is_active:
				var next_seg = playlist_manager.advance_loop()
				_refresh_playlist_ui()
				if next_seg.is_empty():
					_on_playlist_play_toggled(false)
					return
				else:
					playlist_segment_changed.emit(next_seg)
					_on_trigger_transition_pressed()
					clock.current_time_sec = fposmod(clock.current_time_sec, loop_length)
			elif loop_btn and loop_btn.button_pressed:
				clock.current_time_sec = fposmod(clock.current_time_sec, loop_length)
				_pick_random_variations_on_loop()
			else:
				_on_music_stop_pressed()
				return
		
		_update_stem_levels()
		
		# Metronome tick
		if metronome_btn and metronome_btn.button_pressed:
			var cur_beat = clock.current_beat + clock.current_bar * 4
			if cur_beat != last_reported_beat:
				last_reported_beat = cur_beat
				_play_metronome_click(clock.current_beat == 0)
				
		if ruler_canvas:
			ruler_canvas.queue_redraw()
		for t in tracks:
			if t.waveform_canvas:
				t.waveform_canvas.queue_redraw()
			if t.auto_canvas and t.automation_enabled:
				t.auto_canvas.queue_redraw()

func _play_metronome_click(is_downbeat: bool) -> void:
	if metronome_player:
		metronome_player.stream = AudioSynthesizerClass.create_gunshot()
		metronome_player.pitch_scale = 2.4 if is_downbeat else 1.6
		metronome_player.volume_db = -8.0 if is_downbeat else -14.0
		metronome_player.play()

func _on_draw_timeline_ruler() -> void:
	if not ruler_canvas:
		return
	var size = ruler_canvas.size
	if size.x <= 10.0:
		return
		
	# Dark Background
	ruler_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.14, 0.18, 1.0))
	ruler_canvas.draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(0.3, 0.35, 0.45), 1.0)
	
	var num_bars = 8
	var bar_width = (size.x / float(num_bars)) * zoom_factor
	
	for b in range(num_bars * int(ceil(1.0 / zoom_factor)) + 1):
		var bar_x = float(b) * bar_width
		if bar_x > size.x:
			break
		# Bar Line
		ruler_canvas.draw_line(Vector2(bar_x, 0), Vector2(bar_x, size.y), Color(0.45, 0.5, 0.65), 1.5)
		ruler_canvas.draw_string(ThemeDB.fallback_font, Vector2(bar_x + 4, 14), "Bar %d" % (b + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 0.98))
		
		# Beat ticks
		for beat in range(1, 4):
			var beat_x = bar_x + float(beat) * (bar_width / 4.0)
			if beat_x <= size.x:
				ruler_canvas.draw_line(Vector2(beat_x, size.y - 8), Vector2(beat_x, size.y), Color(0.3, 0.35, 0.45), 1.0)
				
	# Post-Exit Tail Shaded Zone (Purple)
	var exit_x = exit_cue_bar * bar_width
	var tail_w = (post_exit_tail_sec / 2.0) * bar_width
	if exit_x <= size.x:
		var tail_rect = Rect2(Vector2(exit_x, 2), Vector2(minf(tail_w, size.x - exit_x), size.y - 4))
		ruler_canvas.draw_rect(tail_rect, Color(0.65, 0.25, 0.9, 0.22))
		ruler_canvas.draw_rect(tail_rect, Color(0.65, 0.25, 0.9, 0.6), false, 1.0)
		ruler_canvas.draw_string(ThemeDB.fallback_font, Vector2(exit_x + 4, size.y - 4), "Tail: +%.1fs" % post_exit_tail_sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.6, 1.0))
		
	# Entry Cue Marker (Green Badge ▼)
	var entry_x = entry_cue_bar * bar_width
	if entry_x >= 0 and entry_x <= size.x:
		ruler_canvas.draw_line(Vector2(entry_x, 0), Vector2(entry_x, size.y), Color(0.25, 0.95, 0.45), 2.5)
		ruler_canvas.draw_rect(Rect2(Vector2(entry_x - 3, 0), Vector2(6, 10)), Color(0.25, 0.95, 0.45))
		ruler_canvas.draw_string(ThemeDB.fallback_font, Vector2(entry_x + 4, size.y - 4), "Entry", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.25, 0.95, 0.45))
		
	# Exit Cue Marker (Red Badge ▼)
	if exit_x >= 0 and exit_x <= size.x:
		ruler_canvas.draw_line(Vector2(exit_x, 0), Vector2(exit_x, size.y), Color(0.95, 0.3, 0.35), 2.5)
		ruler_canvas.draw_rect(Rect2(Vector2(exit_x - 3, 0), Vector2(6, 10)), Color(0.95, 0.3, 0.35))
		ruler_canvas.draw_string(ThemeDB.fallback_font, Vector2(exit_x - 22, 14), "Exit", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.3, 0.35))
		
	# Playhead cursor
	var playhead_x = current_playhead_ratio * size.x * zoom_factor
	ruler_canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.35, 0.35, 1.0), 2.0)

func _on_draw_track_waveform(t: TrackLaneData, canvas: Control) -> void:
	if not canvas:
		return
	var size = canvas.size
	if size.x <= 10.0 or size.y <= 10.0:
		return
		
	var total_w = size.x * zoom_factor
	var left_trim_x = t.left_trim_ratio * total_w
	var right_trim_x = t.right_trim_ratio * total_w
	
	# 1. Dark Waveform Clip Background
	var alpha_factor = clampf(t.current_gain, 0.25, 1.0)
	var bg_col = Color(0.08, 0.1, 0.13, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), bg_col)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(t.color.r, t.color.g, t.color.b, 0.3 * alpha_factor), false, 1.0)
	
	# 2. Grid Subdivision Lines
	var num_bars = 8
	var bar_width = (size.x / float(num_bars)) * zoom_factor
	for b in range(num_bars * int(ceil(1.0 / zoom_factor)) + 1):
		var bx = float(b) * bar_width
		if bx <= size.x:
			canvas.draw_line(Vector2(bx, 0), Vector2(bx, size.y), Color(0.18, 0.22, 0.28, 0.7), 1.0)
			
	# 3. Center Zero-Crossing
	var mid_y = size.y * 0.5
	canvas.draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.2, 0.25, 0.32, 0.5), 1.0)
	
	# 4. Rich Multi-Peak Waveform Drawing
	var steps = int(size.x / 4.0)
	if steps > 4:
		var wave_color = Color(t.color.r, t.color.g, t.color.b, 0.85 * alpha_factor)
		for i in range(steps):
			var x = float(i) * 4.0
			var is_inside_trim = (x >= left_trim_x and x <= right_trim_x)
			var col = wave_color if is_inside_trim else Color(wave_color.r * 0.3, wave_color.g * 0.3, wave_color.b * 0.3, 0.3)
			var t_norm = (x / size.x) * 8.0
			var peak = (sin(t_norm * TAU * 2.0) * 0.4 + sin(t_norm * TAU * 6.0) * 0.3 + sin(t_norm * TAU * 14.0) * 0.3)
			var amp = absf(peak) * (size.y * 0.4) * clampf(t.current_gain, 0.3, 1.0)
			canvas.draw_line(Vector2(x, mid_y - amp), Vector2(x, mid_y + amp), col, 2.0)
			
	# 5. Trim Handles Visuals ([ | and | ])
	canvas.draw_line(Vector2(left_trim_x, 0), Vector2(left_trim_x, size.y), Color(0.3, 0.95, 0.95, 0.9), 2.5)
	canvas.draw_rect(Rect2(Vector2(left_trim_x, 2), Vector2(6, 12)), Color(0.3, 0.95, 0.95, 1.0))
	
	canvas.draw_line(Vector2(right_trim_x, 0), Vector2(right_trim_x, size.y), Color(0.95, 0.85, 0.3, 0.9), 2.5)
	canvas.draw_rect(Rect2(Vector2(right_trim_x - 6, size.y - 14), Vector2(6, 12)), Color(0.95, 0.85, 0.3, 1.0))
	
	# 6. Playhead Line
	var playhead_x = current_playhead_ratio * size.x * zoom_factor
	canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.35, 0.35, 0.9), 1.5)

## Draws the interactive automation curve with handles and real-time cursor (TASK-032).
func _on_draw_automation_curve(t: TrackLaneData, canvas: Control) -> void:
	if not canvas:
		return
	var size = canvas.size
	if size.x <= 10.0 or size.y <= 10.0:
		return
		
	var total_w = size.x * zoom_factor
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.1, 1.0))
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.3, 0.5), false, 1.0)
	
	canvas.draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.15, 0.2, 0.25, 0.7), 1.0)
	
	if t.automation_points.size() >= 2:
		var line_col = Color(1.0, 0.85, 0.2, 0.9)
		for i in range(t.automation_points.size() - 1):
			var p0 = t.automation_points[i]
			var p1 = t.automation_points[i + 1]
			var p0_v = Vector2(p0.x * total_w, (1.0 - p0.y) * size.y)
			var p1_v = Vector2(p1.x * total_w, (1.0 - p1.y) * size.y)
			canvas.draw_line(p0_v, p1_v, line_col, 2.0)
			
	for i in range(t.automation_points.size()):
		var p = t.automation_points[i]
		var pv = Vector2(p.x * total_w, (1.0 - p.y) * size.y)
		var is_sel = (t.selected_point_index == i)
		var pt_col = Color(1.0, 1.0, 0.4) if is_sel else Color(1.0, 0.85, 0.2)
		canvas.draw_circle(pv, 4.0 if is_sel else 3.0, pt_col)
		canvas.draw_circle(pv, 4.0 if is_sel else 3.0, Color.BLACK, false, 1.0)
		
	var playhead_x = current_playhead_ratio * total_w
	canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.35, 0.35, 0.9), 1.5)
