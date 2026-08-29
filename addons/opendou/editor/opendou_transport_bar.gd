@tool
class_name OpenDouTransportBar
extends PanelContainer

## Ultra-compact bottom transport bar with dynamic context-aware workspace adaptation (SFX RTPCs, Music DAW Transport, Dialogue Localization), active GraphEdit compilation, and stereo VU meters.

signal play_requested()
signal pause_requested()
signal stop_requested()
signal rtpc_changed(param_name: StringName, value: float)
signal switch_changed(group_name: StringName, state_name: StringName)
signal music_intensity_changed(intensity: float)
signal music_bpm_changed(bpm: float)

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const OpenDouGraphSerializerClass = preload("res://addons/opendou/editor/opendou_graph_serializer.gd")

var is_playing: bool = false
var is_paused: bool = false

var play_btn: Button
var pause_btn: Button
var stop_btn: Button
var target_event_label: Label
var master_vol_slider: HSlider
var master_vol_spin: SpinBox

var dynamic_controls_container: HBoxContainer
var vu_meter_rect: Control

var left_peak: float = 0.0
var right_peak: float = 0.0

# Editor playback audio
var editor_audio_player: AudioStreamPlayer
var current_event_name: StringName = &"Battlefield_Gunfire.tres"
var current_workspace_mode: int = 0 # 0 = Graph, 1 = Music, 2 = Dialogue

# Reference to active editor graph for live evaluation
var active_graph_editor: GraphEdit = null
var current_simulation_rtpcs: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(0, 36)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	editor_audio_player = AudioStreamPlayer.new()
	add_child(editor_audio_player)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_hbox)
	
	# 1. Transport Playback Controls (Compact 26px)
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 6)
	
	play_btn = Button.new()
	play_btn.text = "▶"
	play_btn.tooltip_text = "Play Event (Space)"
	play_btn.custom_minimum_size = Vector2(34, 26)
	play_btn.pressed.connect(_on_play_pressed)
	
	pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.tooltip_text = "Pause"
	pause_btn.custom_minimum_size = Vector2(34, 26)
	pause_btn.pressed.connect(_on_pause_pressed)
	
	stop_btn = Button.new()
	stop_btn.text = "⏹"
	stop_btn.tooltip_text = "Stop All (Esc)"
	stop_btn.custom_minimum_size = Vector2(34, 26)
	stop_btn.pressed.connect(_on_stop_pressed)
	
	buttons_hbox.add_child(play_btn)
	buttons_hbox.add_child(pause_btn)
	buttons_hbox.add_child(stop_btn)
	main_hbox.add_child(buttons_hbox)
	
	main_hbox.add_child(VSeparator.new())
	
	# 2. Audition Target Event Badge
	target_event_label = Label.new()
	target_event_label.text = "Audition: [%s]" % str(current_event_name)
	target_event_label.add_theme_font_size_override("font_size", 11)
	main_hbox.add_child(target_event_label)
	
	main_hbox.add_child(VSeparator.new())
	
	# 3. Dynamic Contextual Controls Container
	dynamic_controls_container = HBoxContainer.new()
	dynamic_controls_container.add_theme_constant_override("separation", 14)
	dynamic_controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(dynamic_controls_container)
	
	_populate_default_faders()
	
	main_hbox.add_child(VSeparator.new())
	
	# 4. Master Volume (Compact Slider + SpinBox)
	var vol_box = HBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 6)
	var vol_lbl = Label.new()
	vol_lbl.text = "Vol:"
	vol_lbl.add_theme_font_size_override("font_size", 11)
	
	master_vol_slider = HSlider.new()
	master_vol_slider.min_value = -60.0
	master_vol_slider.max_value = 6.0
	master_vol_slider.value = 0.0
	master_vol_slider.custom_minimum_size = Vector2(65, 0)
	master_vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	master_vol_spin = SpinBox.new()
	master_vol_spin.min_value = -60.0
	master_vol_spin.max_value = 6.0
	master_vol_spin.value = 0.0
	master_vol_spin.step = 0.5
	master_vol_spin.suffix = "dB"
	master_vol_spin.custom_minimum_size = Vector2(70, 0)
	master_vol_spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	master_vol_slider.value_changed.connect(func(v):
		if not is_equal_approx(master_vol_spin.value, v): master_vol_spin.value = v
		if editor_audio_player: editor_audio_player.volume_db = v
	)
	master_vol_spin.value_changed.connect(func(v):
		if not is_equal_approx(master_vol_slider.value, v): master_vol_slider.value = v
		if editor_audio_player: editor_audio_player.volume_db = v
	)
	
	vol_box.add_child(vol_lbl)
	vol_box.add_child(master_vol_slider)
	vol_box.add_child(master_vol_spin)
	main_hbox.add_child(vol_box)
	
	main_hbox.add_child(VSeparator.new())
	
	# 5. High-Precision Stereo VU Meter
	vu_meter_rect = Control.new()
	vu_meter_rect.custom_minimum_size = Vector2(50, 24)
	vu_meter_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vu_meter_rect.draw.connect(_on_draw_vu_meter)
	main_hbox.add_child(vu_meter_rect)

## Dynamically adapts bottom transport controls based on active workspace mode.
func set_workspace_context(mode: int) -> void:
	current_workspace_mode = mode
	clear_dynamic_controls()
	
	match mode:
		0: # Graph Workspace (SFX & RTPCs)
			target_event_label.text = "Audition: [%s]" % str(current_event_name)
			add_precision_fader(&"Distance", 0.0, 100.0, 15.0, 0.5, "m")
			add_precision_fader(&"RPM", 0.0, 8000.0, 3200.0, 50.0, "RPM")
			add_precision_fader(&"Pitch Jitter", 0.0, 0.5, 0.05, 0.01, "±")
			
		1: # Music DAW Workspace
			target_event_label.text = "Audition: [🎼 Dynamic_Combat_Suite]"
			_add_music_transport_controls()
			
		2: # Dialogue Grid Workspace
			target_event_label.text = "Audition: [🗣️ Dialogue_Voice_Bank]"
			_add_dialogue_transport_controls()

func _add_music_transport_controls() -> void:
	# Master Tempo BPM Spinbox
	var bpm_box = HBoxContainer.new()
	bpm_box.add_theme_constant_override("separation", 4)
	var bpm_lbl = Label.new()
	bpm_lbl.text = "BPM:"
	bpm_lbl.add_theme_font_size_override("font_size", 11)
	var bpm_spin = SpinBox.new()
	bpm_spin.min_value = 40.0
	bpm_spin.max_value = 240.0
	bpm_spin.value = 120.0
	bpm_spin.value_changed.connect(func(v): music_bpm_changed.emit(v))
	bpm_box.add_child(bpm_lbl)
	bpm_box.add_child(bpm_spin)
	dynamic_controls_container.add_child(bpm_box)
	
	# Combat Intensity Slider
	var int_box = HBoxContainer.new()
	int_box.add_theme_constant_override("separation", 4)
	var int_lbl = Label.new()
	int_lbl.text = "Intensity:"
	int_lbl.add_theme_font_size_override("font_size", 11)
	var int_slider = HSlider.new()
	int_slider.min_value = 0.0
	int_slider.max_value = 1.0
	int_slider.step = 0.01
	int_slider.value = 0.0
	int_slider.custom_minimum_size = Vector2(85, 0)
	int_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	int_slider.value_changed.connect(func(v): music_intensity_changed.emit(v))
	int_box.add_child(int_lbl)
	int_box.add_child(int_slider)
	dynamic_controls_container.add_child(int_box)
	
	# Quantize Selector
	var snap_opt = OptionButton.new()
	snap_opt.add_item("🧲 Next Bar", 0)
	snap_opt.add_item("🧲 Next Beat", 1)
	snap_opt.add_item("⚡ Immediate", 2)
	dynamic_controls_container.add_child(snap_opt)

func _add_dialogue_transport_controls() -> void:
	var loc_box = HBoxContainer.new()
	loc_box.add_theme_constant_override("separation", 4)
	var loc_lbl = Label.new()
	loc_lbl.text = "Locale:"
	loc_lbl.add_theme_font_size_override("font_size", 11)
	var loc_opt = OptionButton.new()
	loc_opt.add_item("🇺🇸 EN", 0)
	loc_opt.add_item("🇪🇸 ES", 1)
	loc_opt.add_item("🇯🇵 JA", 2)
	loc_opt.add_item("🇨🇳 ZH", 3)
	loc_box.add_child(loc_lbl)
	loc_box.add_child(loc_opt)
	dynamic_controls_container.add_child(loc_box)
	
	var duck_lbl = Label.new()
	duck_lbl.text = "Ducking: -12 dB (Voice Bus)"
	duck_lbl.add_theme_font_size_override("font_size", 10)
	dynamic_controls_container.add_child(duck_lbl)

func _populate_default_faders() -> void:
	clear_dynamic_controls()
	add_precision_fader(&"Distance", 0.0, 100.0, 15.0, 0.5, "m")
	add_precision_fader(&"RPM", 0.0, 8000.0, 3200.0, 50.0, "RPM")

func clear_dynamic_controls() -> void:
	current_simulation_rtpcs.clear()
	for child in dynamic_controls_container.get_children():
		child.queue_free()

func set_audition_event(event_name: StringName) -> void:
	current_event_name = event_name
	if target_event_label:
		target_event_label.text = "Audition: [%s]" % str(current_event_name)
		
	clear_dynamic_controls()
	if "Vehicle" in str(event_name):
		add_precision_fader(&"RPM", 0.0, 8000.0, 3200.0, 50.0, "RPM")
		add_precision_fader(&"Speed", 0.0, 50.0, 15.0, 1.0, "m/s")
	elif "Footstep" in str(event_name):
		add_precision_fader(&"Pace", 0.5, 3.0, 1.0, 0.1, "x")
	else:
		add_precision_fader(&"Distance", 0.0, 100.0, 10.0, 0.5, "m")
		add_precision_fader(&"Pitch Jitter", 0.0, 0.5, 0.05, 0.01, "±")

## Populates simulation faders dynamically from persistent GameSyncs registry.
func populate_from_game_syncs(rtpcs: Dictionary) -> void:
	if current_workspace_mode != 0:
		return # Only populate RTPC faders in Graph mode
	clear_dynamic_controls()
	for param in rtpcs.keys():
		var d = rtpcs[param]
		var min_v = float(d.get("min", 0.0))
		var max_v = float(d.get("max", 100.0))
		var def_v = float(d.get("default", 0.0))
		var unit = "RPM" if "RPM" in str(param) else ("m" if "Dist" in str(param) else "")
		add_precision_fader(param, min_v, max_v, def_v, (max_v - min_v) / 100.0, unit)

## Adds a compound precision control (Label + HSlider + SpinBox) with two-way binding.
func add_precision_fader(p_name: StringName, min_v: float, max_v: float, def_v: float, step_v: float, unit: String) -> void:
	current_simulation_rtpcs[p_name] = def_v
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	
	var lbl = Label.new()
	lbl.text = "%s:" % str(p_name)
	lbl.add_theme_font_size_override("font_size", 11)
	
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = def_v
	slider.custom_minimum_size = Vector2(75, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value = def_v
	spin.suffix = unit
	spin.custom_minimum_size = Vector2(75, 0)
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	slider.value_changed.connect(func(val):
		if not is_equal_approx(spin.value, val): spin.value = val
		current_simulation_rtpcs[p_name] = val
		rtpc_changed.emit(p_name, val)
		if is_playing and p_name == &"RPM" and editor_audio_player:
			editor_audio_player.pitch_scale = lerpf(0.6, 2.5, val / 8000.0)
	)
	
	spin.value_changed.connect(func(val):
		if not is_equal_approx(slider.value, val): slider.value = val
		current_simulation_rtpcs[p_name] = val
		rtpc_changed.emit(p_name, val)
		if is_playing and p_name == &"RPM" and editor_audio_player:
			editor_audio_player.pitch_scale = lerpf(0.6, 2.5, val / 8000.0)
	)
	
	box.add_child(lbl)
	box.add_child(slider)
	box.add_child(spin)
	dynamic_controls_container.add_child(box)

func _process(delta: float) -> void:
	if is_playing:
		left_peak = clampf(left_peak + randf_range(-0.15, 0.2), 0.25, 0.95)
		right_peak = clampf(right_peak + randf_range(-0.15, 0.2), 0.25, 0.95)
	else:
		left_peak = lerpf(left_peak, 0.0, delta * 8.0)
		right_peak = lerpf(right_peak, 0.0, delta * 8.0)
		
	if vu_meter_rect:
		vu_meter_rect.queue_redraw()

func _on_draw_vu_meter() -> void:
	if not vu_meter_rect:
		return
	var size = vu_meter_rect.size
	# Background
	vu_meter_rect.draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.1, 1.0))
	vu_meter_rect.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.3, 0.5), false, 1.0)
	
	var bar_h = (size.y - 4.0) * 0.5
	# Left Channel Bar
	var l_w = (size.x - 4.0) * left_peak
	var l_color = Color(0.2, 0.85, 0.4) if left_peak < 0.8 else Color(0.95, 0.3, 0.2)
	vu_meter_rect.draw_rect(Rect2(Vector2(2, 2), Vector2(l_w, bar_h)), l_color)
	
	# Right Channel Bar
	var r_w = (size.x - 4.0) * right_peak
	var r_color = Color(0.2, 0.85, 0.4) if right_peak < 0.8 else Color(0.95, 0.3, 0.2)
	vu_meter_rect.draw_rect(Rect2(Vector2(2, 2 + bar_h + 1), Vector2(r_w, bar_h)), r_color)

func _on_play_pressed() -> void:
	is_playing = true
	is_paused = false
	
	if current_workspace_mode == 1: # Music DAW Mode
		play_requested.emit()
		return
		
	if editor_audio_player:
		# 1. Compile active visual graph if available
		var compiled = OpenDouGraphSerializerClass.build_composite_from_graph(active_graph_editor) if active_graph_editor else {}
		var root_node = compiled.get("root_node", null)
		
		var ctx = AudioPlaybackContextClass.new()
		for p_name in current_simulation_rtpcs.keys():
			ctx.set_rtpc(p_name, current_simulation_rtpcs[p_name])
			
		var resolved_voices = root_node.resolve_voices(ctx) if root_node else []
		
		var base_stream: AudioStream = null
		var resolved_pitch: float = 1.0
		var resolved_vol_db: float = master_vol_slider.value if master_vol_slider else 0.0
		
		if not resolved_voices.is_empty():
			var chosen_voice = resolved_voices[randi() % resolved_voices.size()]
			resolved_pitch = chosen_voice.pitch_modifier
			resolved_vol_db += chosen_voice.volume_offset_db
			if chosen_voice.stream:
				base_stream = chosen_voice.stream
				
		if base_stream == null:
			# Fallback synthesis based on event name
			var ev_str = str(current_event_name).to_lower()
			if "gunfire" in ev_str or "battlefield" in ev_str or "shot" in ev_str:
				base_stream = AudioSynthesizerClass.create_gunshot()
			elif "vehicle" in ev_str or "rpm" in ev_str or "engine" in ev_str:
				var rpm = current_simulation_rtpcs.get(&"RPM", 3200.0)
				base_stream = AudioSynthesizerClass.create_engine_loop(lerpf(30.0, 120.0, rpm / 8000.0))
			elif "footstep" in ev_str or "step" in ev_str or "surface" in ev_str:
				base_stream = AudioSynthesizerClass.create_footstep(&"Concrete", randi_range(1, 3))
			else:
				base_stream = AudioSynthesizerClass.create_chord_loop(1.5)
				
		editor_audio_player.stream = base_stream
		editor_audio_player.pitch_scale = clampf(resolved_pitch, 0.1, 4.0)
		editor_audio_player.volume_db = resolved_vol_db
		editor_audio_player.play()
		
	play_requested.emit()

func _on_pause_pressed() -> void:
	is_paused = not is_paused
	if current_workspace_mode == 1:
		pause_requested.emit()
		return
	if editor_audio_player:
		editor_audio_player.stream_paused = is_paused
	pause_requested.emit()

func _on_stop_pressed() -> void:
	is_playing = false
	is_paused = false
	if current_workspace_mode == 1:
		stop_requested.emit()
		return
	if editor_audio_player:
		editor_audio_player.stop()
	stop_requested.emit()
