@tool
class_name OpenDouLFOGraphNode
extends OpenDouBaseGraphNode

## Visual GraphNode for Low Frequency Oscillators (LFOs) with periodic waveform visualizer, shape selector and rate/depth controls.

const LFOModulatorClass = preload("res://addons/opendou/resources/modulators/lfo_modulator.gd")

var modulator_resource: LFOModulator

var target_opt: OptionButton
var waveform_opt: OptionButton
var freq_spin: SpinBox
var depth_spin: SpinBox
var wave_canvas: Control

var anim_phase: float = 0.0

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_MODULATOR_LFO
	title = "〰️ LFO Oscillator"
	custom_minimum_size = Vector2(250, 240)
	modulator_resource = LFOModulatorClass.new()
	_setup_slots()
	_build_ui()

func _setup_slots() -> void:
	# Slot 0: Audio In -> Audio Out
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# Target Property Row
	var target_hbox = HBoxContainer.new()
	var target_lbl = Label.new()
	target_lbl.text = "Modulates:"
	target_lbl.add_theme_font_size_override("font_size", 10)
	target_hbox.add_child(target_lbl)
	
	target_opt = OptionButton.new()
	target_opt.add_item("🎵 Pitch (Vibrato)", 0)
	target_opt.add_item("🔊 Volume (Tremolo)", 1)
	target_opt.add_item("🎛️ Filter Cutoff (Sweep)", 2)
	target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_opt.item_selected.connect(_on_target_selected)
	target_hbox.add_child(target_opt)
	vbox.add_child(target_hbox)
	
	# Waveform Canvas
	wave_canvas = Control.new()
	wave_canvas.custom_minimum_size = Vector2(230, 65)
	wave_canvas.draw.connect(_on_draw_waveform)
	vbox.add_child(wave_canvas)
	
	# Shape Selector
	var shape_hbox = HBoxContainer.new()
	var shape_lbl = Label.new()
	shape_lbl.text = "Shape:"
	shape_lbl.add_theme_font_size_override("font_size", 9)
	shape_hbox.add_child(shape_lbl)
	
	waveform_opt = OptionButton.new()
	waveform_opt.add_item("∿ Sine Wave", 0)
	waveform_opt.add_item("∧ Triangle", 1)
	waveform_opt.add_item("⊓ Square", 2)
	waveform_opt.add_item("⩘ Sawtooth", 3)
	waveform_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform_opt.item_selected.connect(func(idx):
		modulator_resource.waveform = idx as LFOModulator.Waveform
		wave_canvas.queue_redraw()
	)
	shape_hbox.add_child(waveform_opt)
	vbox.add_child(shape_hbox)
	
	# Frequency & Depth
	var params_grid = GridContainer.new()
	params_grid.columns = 4
	params_grid.add_theme_constant_override("h_separation", 6)
	params_grid.add_theme_constant_override("v_separation", 4)
	
	var f_lbl = Label.new()
	f_lbl.text = "Rate (Hz):"
	f_lbl.add_theme_font_size_override("font_size", 9)
	params_grid.add_child(f_lbl)
	
	freq_spin = SpinBox.new()
	freq_spin.min_value = 0.1
	freq_spin.max_value = 20.0
	freq_spin.step = 0.1
	freq_spin.value = modulator_resource.frequency_hz
	freq_spin.value_changed.connect(func(v):
		modulator_resource.frequency_hz = v
		wave_canvas.queue_redraw()
	)
	params_grid.add_child(freq_spin)
	
	var dep_lbl = Label.new()
	dep_lbl.text = "Depth (%):"
	dep_lbl.add_theme_font_size_override("font_size", 9)
	params_grid.add_child(dep_lbl)
	
	depth_spin = SpinBox.new()
	depth_spin.min_value = 0.0
	depth_spin.max_value = 1.0
	depth_spin.step = 0.05
	depth_spin.value = modulator_resource.depth
	depth_spin.value_changed.connect(func(v):
		modulator_resource.depth = v
		wave_canvas.queue_redraw()
	)
	params_grid.add_child(depth_spin)
	
	vbox.add_child(params_grid)
	add_child(vbox)

func _on_target_selected(idx: int) -> void:
	match idx:
		0: modulator_resource.target_property = &"pitch_scale"
		1: modulator_resource.target_property = &"volume_db"
		2: modulator_resource.target_property = &"cutoff_hz"

func _process(delta: float) -> void:
	anim_phase = fposmod(anim_phase + delta * modulator_resource.frequency_hz, 1.0)
	if wave_canvas:
		wave_canvas.queue_redraw()

func _on_draw_waveform() -> void:
	if not wave_canvas:
		return
	var size = wave_canvas.size
	wave_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.13, 1.0))
	wave_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.4, 0.8, 0.4), false, 1.0)
	
	var mid_y = size.y * 0.5
	wave_canvas.draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.2, 0.25, 0.35, 0.5), 1.0)
	
	var pts = 60
	var prev_pt = Vector2.ZERO
	var wave_color = Color(0.98, 0.45, 0.85)
	
	for i in range(pts):
		var x = (float(i) / float(pts - 1)) * size.x
		var t = (float(i) / float(pts - 1)) * 2.0 + anim_phase
		var val = 0.0
		match modulator_resource.waveform:
			LFOModulator.Waveform.SINE:
				val = sin(t * TAU)
			LFOModulator.Waveform.TRIANGLE:
				val = absf(fposmod(t * 2.0 - 1.0, 2.0) - 1.0) * 2.0 - 1.0
			LFOModulator.Waveform.SQUARE:
				val = 1.0 if fposmod(t, 1.0) < 0.5 else -1.0
			LFOModulator.Waveform.SAWTOOTH:
				val = fposmod(t, 1.0) * 2.0 - 1.0
		var y = mid_y - val * (size.y * 0.38) * clampf(modulator_resource.depth, 0.2, 1.0)
		var pt = Vector2(x, y)
		if i > 0:
			wave_canvas.draw_line(prev_pt, pt, wave_color, 2.0)
		prev_pt = pt
