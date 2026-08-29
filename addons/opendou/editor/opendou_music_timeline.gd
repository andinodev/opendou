@tool
class_name OpenDouMusicTimeline
extends PanelContainer

## Professional DAW-style interactive music timeline with Rhythmic BPM Grid Ruler, Multi-Track Headers (Mute, Solo, Volume Fader), High-Definition Waveform Clip Previews, Metronome, Horizontal Zoom, and Quantized Transition Matrix.

signal bpm_changed(new_bpm: float)
signal intensity_changed(new_intensity: float)
signal transition_requested(target_segment: StringName, sync_mode: int, fade_time: float)
signal stinger_requested(stinger_name: StringName, sync_mode: int)

const MusicClockClass = preload("res://addons/opendou/core/music/music_clock.gd")
const MusicSegmentClass = preload("res://addons/opendou/core/music/music_segment.gd")
const MusicTransitionMatrixClass = preload("res://addons/opendou/core/music/music_transition_matrix.gd")
const MusicStingerQueueClass = preload("res://addons/opendou/core/music/music_stinger_queue.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

class TrackLaneData:
	var name: String
	var min_intensity: float
	var max_intensity: float
	var color: Color
	var is_muted: bool = false
	var is_solo: bool = false
	var volume_db: float = 0.0
	var current_gain: float = 0.0
	var header_panel: PanelContainer
	var mute_btn: Button
	var solo_btn: Button
	var vol_slider: HSlider
	var meter_rect: Control
	var waveform_canvas: Control

var clock: MusicClock
var transition_matrix: MusicTransitionMatrix
var stinger_queue: MusicStingerQueue

# Toolbar Controls
var bpm_spinbox: SpinBox
var metronome_btn: Button
var snap_selector: OptionButton
var zoom_spinbox: SpinBox
var intensity_slider: HSlider
var intensity_lbl: Label
var beat_counter_lbl: Label

# Center Sequencer
var ruler_canvas: Control
var scroll_container: ScrollContainer
var lanes_vbox: VBoxContainer
var tracks: Array[TrackLaneData] = []

# Right Matrix Controls
var transition_target_opt: OptionButton
var sync_mode_opt: OptionButton
var fade_duration_spinbox: SpinBox

# Playback State
var is_playing: bool = false
var zoom_factor: float = 1.0 # 0.5 to 3.0
var active_intensity: float = 0.0
var current_playhead_ratio: float = 0.0
var last_reported_beat: int = -1

# Audio Players
var metronome_player: AudioStreamPlayer
var music_audio_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer

func _init() -> void:
	clock = MusicClockClass.new(120.0, 4, 4)
	transition_matrix = MusicTransitionMatrixClass.new()
	stinger_queue = MusicStingerQueueClass.new()
	
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	# Audio Players
	metronome_player = AudioStreamPlayer.new()
	add_child(metronome_player)
	
	music_audio_player = AudioStreamPlayer.new()
	add_child(music_audio_player)
	
	stinger_player = AudioStreamPlayer.new()
	add_child(stinger_player)
	
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
	)
	toolbar.add_child(zoom_spinbox)
	
	toolbar.add_child(VSeparator.new())
	
	# Beat Counter Display
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
	
	# 2. Main Splitter (DAW Multi-Track Lanes on Left, Transition Matrix on Right)
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
	
	# Header Row (Left corner spacer + Rhythmic Timeline Ruler)
	var ruler_row = HBoxContainer.new()
	ruler_row.add_theme_constant_override("separation", 6)
	
	var track_header_spacer = PanelContainer.new()
	track_header_spacer.custom_minimum_size = Vector2(230, 32)
	var spacer_lbl = Label.new()
	spacer_lbl.text = "  Tracks / Stems"
	spacer_lbl.add_theme_font_size_override("font_size", 10)
	spacer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	track_header_spacer.add_child(spacer_lbl)
	ruler_row.add_child(track_header_spacer)
	
	ruler_canvas = Control.new()
	ruler_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ruler_canvas.custom_minimum_size = Vector2(0, 32)
	ruler_canvas.draw.connect(_on_draw_timeline_ruler)
	ruler_row.add_child(ruler_canvas)
	seq_vbox.add_child(ruler_row)
	
	# Multi-Track Lanes Stack inside ScrollContainer
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
	
	# 3. Transition Matrix & Stinger Inspector (Right Panel)
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
	transition_target_opt.add_item("Segment: Victory_Outro", 3)
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
	
	# Populate 4 Default Interactive Stems
	_add_track("Layer 1: Ambient_Pads", 0.0, 0.5, Color(0.2, 0.75, 0.95))
	_add_track("Layer 2: Stealth_Bass", 0.2, 0.7, Color(0.3, 0.85, 0.45))
	_add_track("Layer 3: Combat_Drums", 0.5, 1.0, Color(0.98, 0.65, 0.22))
	_add_track("Layer 4: Brass_Climax", 0.8, 1.0, Color(0.98, 0.25, 0.35))
	
	_on_intensity_slider_changed(0.0)

func _add_track(track_name: String, min_int: float, max_int: float, color: Color) -> void:
	var t = TrackLaneData.new()
	t.name = track_name
	t.min_intensity = min_int
	t.max_intensity = max_int
	t.color = color
	
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 6)
	
	# 1. Track Header (Left Panel, 230px)
	var header = PanelContainer.new()
	header.custom_minimum_size = Vector2(230, 52)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	header.add_child(header_hbox)
	
	# Color badge
	var badge = ColorRect.new()
	badge.color = color
	badge.custom_minimum_size = Vector2(4, 40)
	header_hbox.add_child(badge)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	
	var name_lbl = Label.new()
	name_lbl.text = track_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_vbox.add_child(name_lbl)
	
	var controls_hbox = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 4)
	
	# Mute Button
	var m_btn = Button.new()
	m_btn.text = "M"
	m_btn.tooltip_text = "Mute Track"
	m_btn.toggle_mode = true
	m_btn.custom_minimum_size = Vector2(22, 20)
	m_btn.toggled.connect(func(is_m):
		t.is_muted = is_m
		m_btn.modulate = Color(1.0, 0.3, 0.3) if is_m else Color.WHITE
		_update_stem_levels()
	)
	t.mute_btn = m_btn
	controls_hbox.add_child(m_btn)
	
	# Solo Button
	var s_btn = Button.new()
	s_btn.text = "S"
	s_btn.tooltip_text = "Solo Track"
	s_btn.toggle_mode = true
	s_btn.custom_minimum_size = Vector2(22, 20)
	s_btn.toggled.connect(func(is_s):
		t.is_solo = is_s
		s_btn.modulate = Color(1.0, 0.9, 0.2) if is_s else Color.WHITE
		_update_stem_levels()
	)
	t.solo_btn = s_btn
	controls_hbox.add_child(s_btn)
	
	# Volume Slider
	var vol_slider = HSlider.new()
	vol_slider.min_value = -24.0
	vol_slider.max_value = 6.0
	vol_slider.value = 0.0
	vol_slider.step = 0.5
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.custom_minimum_size = Vector2(60, 0)
	vol_slider.value_changed.connect(func(v):
		t.volume_db = v
		_update_stem_levels()
	)
	t.vol_slider = vol_slider
	controls_hbox.add_child(vol_slider)
	
	info_vbox.add_child(controls_hbox)
	header_hbox.add_child(info_vbox)
	
	# Live LED Meter Bar
	var meter = Control.new()
	meter.custom_minimum_size = Vector2(8, 40)
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
	
	# 2. Waveform Clip Canvas
	var wave_canvas = Control.new()
	wave_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_canvas.custom_minimum_size = Vector2(0, 52)
	wave_canvas.draw.connect(func(): _on_draw_track_waveform(t, wave_canvas))
	t.waveform_canvas = wave_canvas
	row.add_child(wave_canvas)
	
	tracks.append(t)
	lanes_vbox.add_child(row)

func _on_bpm_changed(val: float) -> void:
	if clock:
		clock.bpm = val
	bpm_changed.emit(val)

func _on_intensity_slider_changed(val: float) -> void:
	active_intensity = val
	var pct = int(val * 100.0)
	var desc = "Explore" if val < 0.3 else ("Combat" if val < 0.75 else "Climax")
	intensity_lbl.text = "%d%% (%s)" % [pct, desc]
	_update_stem_levels()
	intensity_changed.emit(val)

func _update_stem_levels() -> void:
	var any_solo = false
	for t in tracks:
		if t.is_solo:
			any_solo = true
			break
			
	for t in tracks:
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
		
		if t.is_muted:
			target_gain = 0.0
		elif any_solo and not t.is_solo:
			target_gain = 0.0
			
		t.current_gain = target_gain
		if t.meter_rect: t.meter_rect.queue_redraw()
		if t.waveform_canvas: t.waveform_canvas.queue_redraw()

func _on_trigger_transition_pressed() -> void:
	var target_name = &"Combat_Loop"
	match transition_target_opt.selected:
		0: target_name = &"Combat_Loop"
		1: target_name = &"Exploration_Pads"
		2: target_name = &"Boss_Encounter"
		3: target_name = &"Victory_Outro"
	var sync_m = sync_mode_opt.selected
	var fade_t = fade_duration_spinbox.value
	transition_requested.emit(target_name, sync_m, fade_t)

func play_audition_stinger(stinger_name: StringName) -> void:
	if stinger_player:
		stinger_player.stream = AudioSynthesizerClass.create_chord_loop(0.8)
		stinger_player.pitch_scale = 1.3 if "Victory" in str(stinger_name) else 0.7
		stinger_player.volume_db = 2.0
		stinger_player.play()

func _process(delta: float) -> void:
	if clock:
		clock.update(delta)
		current_playhead_ratio = fposmod(clock.current_time_sec / 16.0, 1.0)
		beat_counter_lbl.text = "⏱️ Bar %d : Beat %d.0" % [clock.current_bar + 1, clock.current_beat + 1]
		
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
				
	# Playhead cursor
	var playhead_x = current_playhead_ratio * size.x * zoom_factor
	ruler_canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.35, 0.35, 1.0), 2.0)

func _on_draw_track_waveform(t: TrackLaneData, canvas: Control) -> void:
	if not canvas:
		return
	var size = canvas.size
	if size.x <= 10.0 or size.y <= 10.0:
		return
		
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
			var t_norm = (x / size.x) * 8.0 # 8 beats pattern
			var peak = (sin(t_norm * TAU * 2.0) * 0.4 + sin(t_norm * TAU * 6.0) * 0.3 + sin(t_norm * TAU * 14.0) * 0.3)
			var amp = absf(peak) * (size.y * 0.4) * clampf(t.current_gain, 0.3, 1.0)
			canvas.draw_line(Vector2(x, mid_y - amp), Vector2(x, mid_y + amp), wave_color, 2.0)
			
	# 5. Playhead Line
	var playhead_x = current_playhead_ratio * size.x * zoom_factor
	canvas.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.35, 0.35, 0.9), 1.5)
