class_name OpenDouTransportBar
extends PanelContainer

## Bottom / Header transport bar for auditioning events, tweaking RTPC faders, and panic stopping in the editor.

signal play_requested()
signal pause_requested()
signal stop_requested()
signal rtpc_changed(param_name: StringName, value: float)
signal switch_changed(group_name: StringName, state_name: StringName)

var is_playing: bool = false
var is_paused: bool = false

var play_btn: Button
var pause_btn: Button
var stop_btn: Button
var target_event_label: Label
var master_vol_slider: HSlider

var rtpc_faders_container: HBoxContainer
var switch_selectors_container: HBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(0, 48)
	_build_ui()

func _build_ui() -> void:
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	add_child(main_hbox)
	
	# 1. Transport Buttons
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 4)
	
	play_btn = Button.new()
	play_btn.text = "▶ Play"
	play_btn.custom_minimum_size = Vector2(70, 32)
	play_btn.pressed.connect(_on_play_pressed)
	
	pause_btn = Button.new()
	pause_btn.text = "⏸ Pause"
	pause_btn.custom_minimum_size = Vector2(70, 32)
	pause_btn.pressed.connect(_on_pause_pressed)
	
	stop_btn = Button.new()
	stop_btn.text = "⏹ Stop (Esc)"
	stop_btn.custom_minimum_size = Vector2(85, 32)
	stop_btn.pressed.connect(_on_stop_pressed)
	
	buttons_hbox.add_child(play_btn)
	buttons_hbox.add_child(pause_btn)
	buttons_hbox.add_child(stop_btn)
	main_hbox.add_child(buttons_hbox)
	
	main_hbox.add_child(VSeparator.new())
	
	# 2. Audition Target Event Label
	target_event_label = Label.new()
	target_event_label.text = "Event: (None Selected)"
	target_event_label.custom_minimum_size = Vector2(160, 0)
	main_hbox.add_child(target_event_label)
	
	main_hbox.add_child(VSeparator.new())
	
	# 3. Dynamic RTPC Faders Container
	rtpc_faders_container = HBoxContainer.new()
	rtpc_faders_container.add_theme_constant_override("separation", 8)
	main_hbox.add_child(rtpc_faders_container)
	
	# 4. Dynamic Switch Selectors Container
	switch_selectors_container = HBoxContainer.new()
	switch_selectors_container.add_theme_constant_override("separation", 8)
	main_hbox.add_child(switch_selectors_container)
	
	main_hbox.add_child(VSeparator.new())
	
	# 5. Master Audition Volume
	var vol_hbox = HBoxContainer.new()
	var vol_lbl = Label.new()
	vol_lbl.text = "Master Vol:"
	master_vol_slider = HSlider.new()
	master_vol_slider.min_value = -60.0
	master_vol_slider.max_value = 6.0
	master_vol_slider.value = 0.0
	master_vol_slider.custom_minimum_size = Vector2(90, 0)
	vol_hbox.add_child(vol_lbl)
	vol_hbox.add_child(master_vol_slider)
	main_hbox.add_child(vol_hbox)

## Adds an interactive RTPC test slider to the transport bar.
func add_rtpc_fader(param_name: StringName, min_val: float = 0.0, max_val: float = 100.0, default_val: float = 0.0) -> void:
	var fader_box = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "%s:" % str(param_name)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.custom_minimum_size = Vector2(80, 0)
	slider.value_changed.connect(func(val): rtpc_changed.emit(param_name, float(val)))
	
	fader_box.add_child(lbl)
	fader_box.add_child(slider)
	rtpc_faders_container.add_child(fader_box)

## Adds an interactive Switch state dropdown selector.
func add_switch_selector(group_name: StringName, states_list: Array[String]) -> void:
	var sw_box = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "%s:" % str(group_name)
	
	var opt = OptionButton.new()
	for i in range(states_list.size()):
		opt.add_item(states_list[i], i)
	opt.item_selected.connect(func(idx): switch_changed.emit(group_name, StringName(states_list[idx])))
	
	sw_box.add_child(lbl)
	sw_box.add_child(opt)
	switch_selectors_container.add_child(sw_box)

## Clears dynamic sliders and switches.
func clear_dynamic_controls() -> void:
	for c in rtpc_faders_container.get_children():
		c.queue_free()
	for c in switch_selectors_container.get_children():
		c.queue_free()

## Sets the name of the target event being auditioned.
func set_target_event(event_name: StringName) -> void:
	target_event_label.text = "Event: %s" % str(event_name)

func _on_play_pressed() -> void:
	is_playing = true
	is_paused = false
	play_requested.emit()

func _on_pause_pressed() -> void:
	if is_playing:
		is_paused = not is_paused
		pause_btn.text = "▶ Resume" if is_paused else "⏸ Pause"
		pause_requested.emit()

func _on_stop_pressed() -> void:
	is_playing = false
	is_paused = false
	pause_btn.text = "⏸ Pause"
	stop_requested.emit()
