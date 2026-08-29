@tool
class_name OpenDouMusicTimeline
extends PanelContainer

## DAW-style interactive music timeline with BPM grid ruler, multi-track layer visualizer, combat intensity fader, and quantized transition matrix.

signal bpm_changed(new_bpm: float)
signal intensity_changed(new_intensity: float)
signal transition_requested(target_segment: StringName, sync_mode: int, fade_time: float)
signal stinger_requested(stinger_name: StringName, sync_mode: int)

const MusicClockClass = preload("res://addons/opendou/core/music/music_clock.gd")
const MusicSegmentClass = preload("res://addons/opendou/core/music/music_segment.gd")
const MusicTransitionMatrixClass = preload("res://addons/opendou/core/music/music_transition_matrix.gd")
const MusicStingerQueueClass = preload("res://addons/opendou/core/music/music_stinger_queue.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var clock: MusicClock
var current_segment: MusicSegment
var transition_matrix: MusicTransitionMatrix
var stinger_queue: MusicStingerQueue
var stinger_player: AudioStreamPlayer

var bpm_spinbox: SpinBox
var intensity_slider: HSlider
var intensity_lbl: Label
var beat_counter_lbl: Label

var timeline_canvas: Control
var track_lanes_box: VBoxContainer
var transition_target_opt: OptionButton
var sync_mode_opt: OptionButton
var fade_duration_spinbox: SpinBox

var current_playhead_ratio: float = 0.0
var active_intensity: float = 0.0

func _init() -> void:
	clock = MusicClockClass.new(120.0, 4, 4)
	transition_matrix = MusicTransitionMatrixClass.new()
	stinger_queue = MusicStingerQueueClass.new()
	
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
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
	title_lbl.text = "🎼 Interactive Music DAW Sequencer"
	title_lbl.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(title_lbl)
	
	toolbar.add_child(VSeparator.new())
	
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
	
	var meter_lbl = Label.new()
	meter_lbl.text = "Meter: 4/4"
	meter_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(meter_lbl)
	
	toolbar.add_child(VSeparator.new())
	
	beat_counter_lbl = Label.new()
	beat_counter_lbl.text = "⏱️ Bar 1 : Beat 1"
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
	intensity_slider.custom_minimum_size = Vector2(120, 20)
	intensity_slider.value_changed.connect(_on_intensity_slider_changed)
	toolbar.add_child(intensity_slider)
	
	intensity_lbl = Label.new()
	intensity_lbl.text = "0% (Explore)"
	intensity_lbl.add_theme_font_size_override("font_size", 10)
	intensity_lbl.custom_minimum_size = Vector2(75, 0)
	toolbar.add_child(intensity_lbl)
	
	main_vbox.add_child(toolbar)
	
	# 2. Main Timeline Splitter (Timeline Canvas on Left, Transition Matrix on Right)
	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 320
	main_vbox.add_child(split)
	
	# Timeline Multi-Track Container
	var timeline_box = VBoxContainer.new()
	timeline_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_box.add_theme_constant_override("separation", 4)
	
	# Rhythmic Grid Canvas
	timeline_canvas = Control.new()
	timeline_canvas.custom_minimum_size = Vector2(0, 36)
	timeline_canvas.draw.connect(_on_draw_timeline_ruler)
	timeline_box.add_child(timeline_canvas)
	
	# Multi-track Lanes
	track_lanes_box = VBoxContainer.new()
	track_lanes_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_lanes_box.add_theme_constant_override("separation", 6)
	
	_add_track_lane("Layer 1: Ambient_Pads", 0.0, 0.5, Color(0.2, 0.6, 0.9))
	_add_track_lane("Layer 2: Stealth_Bass", 0.2, 0.7, Color(0.4, 0.8, 0.4))
	_add_track_lane("Layer 3: Combat_Drums", 0.5, 1.0, Color(0.9, 0.6, 0.2))
	_add_track_lane("Layer 4: Brass_Climax", 0.8, 1.0, Color(0.9, 0.2, 0.3))
	
	timeline_box.add_child(track_lanes_box)
	split.add_child(timeline_box)
	
	# 3. Transition Matrix & Stinger Panel
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(240, 0)
	right_panel.add_theme_constant_override("separation", 8)
	
	var trans_title = Label.new()
	trans_title.text = "🔀 Quantized Transition Matrix"
	trans_title.add_theme_font_size_override("font_size", 11)
	right_panel.add_child(trans_title)
	
	var target_lbl = Label.new()
	target_lbl.text = "Target Segment:"
	target_lbl.add_theme_font_size_override("font_size", 10)
	right_panel.add_child(target_lbl)
	
	transition_target_opt = OptionButton.new()
	transition_target_opt.add_item("Segment: Combat_Loop", 0)
	transition_target_opt.add_item("Segment: Exploration_Pads", 1)
	transition_target_opt.add_item("Segment: Boss_Encounter", 2)
	right_panel.add_child(transition_target_opt)
	
	var sync_lbl = Label.new()
	sync_lbl.text = "Quantize Exit Rule:"
	sync_lbl.add_theme_font_size_override("font_size", 10)
	right_panel.add_child(sync_lbl)
	
	sync_mode_opt = OptionButton.new()
	sync_mode_opt.add_item("⏱️ Next Bar (Downbeat)", 0)
	sync_mode_opt.add_item("🎵 Next Beat", 1)
	sync_mode_opt.add_item("⚡ Immediate", 2)
	right_panel.add_child(sync_mode_opt)
	
	var fade_lbl = Label.new()
	fade_lbl.text = "Crossfade Duration (s):"
	fade_lbl.add_theme_font_size_override("font_size", 10)
	right_panel.add_child(fade_lbl)
	
	fade_duration_spinbox = SpinBox.new()
	fade_duration_spinbox.min_value = 0.1
	fade_duration_spinbox.max_value = 4.0
	fade_duration_spinbox.step = 0.1
	fade_duration_spinbox.value = 1.5
	right_panel.add_child(fade_duration_spinbox)
	
	var btn_trigger_trans = Button.new()
	btn_trigger_trans.text = "🔀 Trigger Transition"
	btn_trigger_trans.pressed.connect(_on_trigger_transition_pressed)
	right_panel.add_child(btn_trigger_trans)
	
	right_panel.add_child(HSeparator.new())
	
	var stinger_title = Label.new()
	stinger_title.text = "💥 Rhythmic Stingers"
	stinger_title.add_theme_font_size_override("font_size", 11)
	right_panel.add_child(stinger_title)
	
	stinger_player = AudioStreamPlayer.new()
	add_child(stinger_player)
	
	var btn_stinger_victory = Button.new()
	btn_stinger_victory.text = "🎺 Stinger: Victory_Brass"
	btn_stinger_victory.pressed.connect(func():
		play_audition_stinger(&"Victory_Brass")
		stinger_requested.emit(&"Victory_Brass", 0)
	)
	right_panel.add_child(btn_stinger_victory)
	
	var btn_stinger_danger = Button.new()
	btn_stinger_danger.text = "⚠️ Stinger: Danger_Hit"
	btn_stinger_danger.pressed.connect(func():
		play_audition_stinger(&"Danger_Hit")
		stinger_requested.emit(&"Danger_Hit", 1)
	)
	right_panel.add_child(btn_stinger_danger)
	
	split.add_child(right_panel)

func play_audition_stinger(stinger_name: StringName) -> void:
	if stinger_player:
		stinger_player.stream = AudioSynthesizerClass.create_chord_loop(0.8)
		stinger_player.pitch_scale = 1.3 if "Victory" in str(stinger_name) else 0.7
		stinger_player.volume_db = 2.0
		stinger_player.play()

func _add_track_lane(layer_name: String, min_int: float, max_int: float, color: Color) -> void:
	var lane_panel = PanelContainer.new()
	lane_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_panel.custom_minimum_size = Vector2(0, 36)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	lane_panel.add_child(hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = layer_name
	name_lbl.custom_minimum_size = Vector2(160, 0)
	name_lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(name_lbl)
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.set_meta("min_int", min_int)
	bar.set_meta("max_int", max_int)
	bar.set_meta("color", color)
	hbox.add_child(bar)
	
	track_lanes_box.add_child(lane_panel)

func _on_bpm_changed(val: float) -> void:
	if clock:
		clock.bpm = val
	bpm_changed.emit(val)

func _on_intensity_slider_changed(val: float) -> void:
	active_intensity = val
	var pct = int(val * 100.0)
	var desc = "Explore" if val < 0.3 else ("Combat" if val < 0.75 else "Climax")
	intensity_lbl.text = "%d%% (%s)" % [pct, desc]
	
	# Update track visualizer lane bars
	for child in track_lanes_box.get_children():
		var hbox = child.get_child(0)
		var pbar = hbox.get_child(1) as ProgressBar
		if pbar:
			var min_i: float = pbar.get_meta("min_int")
			var max_i: float = pbar.get_meta("max_int")
			if val >= min_i and val <= max_i:
				var fade = 0.15
				var gain = 1.0
				if val < min_i + fade: gain = (val - min_i) / fade
				elif val > max_i - fade: gain = (max_i - val) / fade
				pbar.value = clampf(gain, 0.0, 1.0)
			else:
				pbar.value = 0.0
				
	intensity_changed.emit(val)

func _on_trigger_transition_pressed() -> void:
	var target_name = &"Combat_Loop"
	match transition_target_opt.selected:
		0: target_name = &"Combat_Loop"
		1: target_name = &"Exploration_Pads"
		2: target_name = &"Boss_Encounter"
	var sync_m = sync_mode_opt.selected
	var fade_t = fade_duration_spinbox.value
	transition_requested.emit(target_name, sync_m, fade_t)

func _process(delta: float) -> void:
	if clock:
		clock.update(delta)
		current_playhead_ratio = fposmod(clock.current_time_sec / 16.0, 1.0)
		beat_counter_lbl.text = "⏱️ Bar %d : Beat %d" % [clock.current_bar + 1, clock.current_beat + 1]
		if timeline_canvas:
			timeline_canvas.queue_redraw()

func _on_draw_timeline_ruler() -> void:
	if not timeline_canvas:
		return
	var size = timeline_canvas.size
	if size.x <= 10.0:
		return
		
	# Draw ruler background
	timeline_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.16, 1.0))
	
	# Draw 8 Bars with 4 Beat subdivisions
	var num_bars = 8
	var bar_width = size.x / float(num_bars)
	
	for b in range(num_bars):
		var bar_x = float(b) * bar_width
		# Major bar line
		timeline_canvas.draw_line(Vector2(bar_x, 0), Vector2(bar_x, size.y), Color(0.4, 0.45, 0.55), 1.5)
		timeline_canvas.draw_string(ThemeDB.fallback_font, Vector2(bar_x + 4, 14), "Bar %d" % (b + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.85, 0.9))
		
		# Beat ticks
		for beat in range(1, 4):
			var beat_x = bar_x + float(beat) * (bar_width / 4.0)
			timeline_canvas.draw_line(Vector2(beat_x, size.y - 8), Vector2(beat_x, size.y), Color(0.3, 0.35, 0.45), 1.0)
			
	# Playhead cursor
	var playhead_x = current_playhead_ratio * size.x
	timeline_canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.3, 0.3, 1.0), 2.0)
