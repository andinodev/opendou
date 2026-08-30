@tool
class_name OpenDouAHDSRGraphNode
extends OpenDouBaseGraphNode

## Visual GraphNode for AHDSR Envelope Modulators with interactive curve visualizer, property mapping and trigger testing.

const AHDSRModulatorClass = preload("res://addons/opendou/resources/modulators/ahdsr_modulator.gd")

var modulator_resource: AHDSRModulator

var target_opt: OptionButton
var attack_spin: SpinBox
var hold_spin: SpinBox
var decay_spin: SpinBox
var sustain_spin: SpinBox
var release_spin: SpinBox
var curve_canvas: Control
var btn_trigger: Button

# Visual animation state
var preview_phase: float = -1.0 # -1 = idle, 0..1 = progress

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_MODULATOR_AHDSR
	title = "⚡ AHDSR Envelope"
	custom_minimum_size = Vector2(250, 260)
	modulator_resource = AHDSRModulatorClass.new()
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
	target_lbl.text = "Target:"
	target_lbl.add_theme_font_size_override("font_size", 10)
	target_hbox.add_child(target_lbl)
	
	target_opt = OptionButton.new()
	target_opt.add_item("🔊 Volume (Gain)", 0)
	target_opt.add_item("🎵 Pitch (Octave)", 1)
	target_opt.add_item("🎛️ Filter Cutoff", 2)
	target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_opt.item_selected.connect(_on_target_selected)
	target_hbox.add_child(target_opt)
	vbox.add_child(target_hbox)
	
	# Interactive Envelope Curve Visualizer
	curve_canvas = Control.new()
	curve_canvas.custom_minimum_size = Vector2(230, 70)
	curve_canvas.draw.connect(_on_draw_curve)
	vbox.add_child(curve_canvas)
	
	# Grid of parameters
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	
	# Attack
	var a_lbl = Label.new()
	a_lbl.text = "Atk (s):"
	a_lbl.add_theme_font_size_override("font_size", 9)
	grid.add_child(a_lbl)
	
	attack_spin = SpinBox.new()
	attack_spin.min_value = 0.01
	attack_spin.max_value = 3.0
	attack_spin.step = 0.05
	attack_spin.value = modulator_resource.attack_time
	attack_spin.value_changed.connect(func(v):
		modulator_resource.attack_time = v
		curve_canvas.queue_redraw()
	)
	grid.add_child(attack_spin)
	
	# Hold
	var h_lbl = Label.new()
	h_lbl.text = "Hld (s):"
	h_lbl.add_theme_font_size_override("font_size", 9)
	grid.add_child(h_lbl)
	
	hold_spin = SpinBox.new()
	hold_spin.min_value = 0.0
	hold_spin.max_value = 3.0
	hold_spin.step = 0.05
	hold_spin.value = modulator_resource.hold_time
	hold_spin.value_changed.connect(func(v):
		modulator_resource.hold_time = v
		curve_canvas.queue_redraw()
	)
	grid.add_child(hold_spin)
	
	# Decay
	var d_lbl = Label.new()
	d_lbl.text = "Dcy (s):"
	d_lbl.add_theme_font_size_override("font_size", 9)
	grid.add_child(d_lbl)
	
	decay_spin = SpinBox.new()
	decay_spin.min_value = 0.01
	decay_spin.max_value = 3.0
	decay_spin.step = 0.05
	decay_spin.value = modulator_resource.decay_time
	decay_spin.value_changed.connect(func(v):
		modulator_resource.decay_time = v
		curve_canvas.queue_redraw()
	)
	grid.add_child(decay_spin)
	
	# Sustain
	var s_lbl = Label.new()
	s_lbl.text = "Sus (%):"
	s_lbl.add_theme_font_size_override("font_size", 9)
	grid.add_child(s_lbl)
	
	sustain_spin = SpinBox.new()
	sustain_spin.min_value = 0.0
	sustain_spin.max_value = 1.0
	sustain_spin.step = 0.05
	sustain_spin.value = modulator_resource.sustain_level
	sustain_spin.value_changed.connect(func(v):
		modulator_resource.sustain_level = v
		curve_canvas.queue_redraw()
	)
	grid.add_child(sustain_spin)
	
	# Release
	var r_lbl = Label.new()
	r_lbl.text = "Rel (s):"
	r_lbl.add_theme_font_size_override("font_size", 9)
	grid.add_child(r_lbl)
	
	release_spin = SpinBox.new()
	release_spin.min_value = 0.01
	release_spin.max_value = 4.0
	release_spin.step = 0.05
	release_spin.value = modulator_resource.release_time
	release_spin.value_changed.connect(func(v):
		modulator_resource.release_time = v
		curve_canvas.queue_redraw()
	)
	grid.add_child(release_spin)
	
	vbox.add_child(grid)
	
	btn_trigger = Button.new()
	btn_trigger.text = "⚡ Test Envelope Trigger"
	btn_trigger.custom_minimum_size = Vector2(0, 22)
	btn_trigger.pressed.connect(_on_test_trigger_pressed)
	vbox.add_child(btn_trigger)
	
	add_child(vbox)

func _on_target_selected(idx: int) -> void:
	match idx:
		0: modulator_resource.target_property = &"volume_db"
		1: modulator_resource.target_property = &"pitch_scale"
		2: modulator_resource.target_property = &"cutoff_hz"

func _on_test_trigger_pressed() -> void:
	preview_phase = 0.0
	var tw = create_tween()
	tw.tween_property(self, "preview_phase", 1.0, 1.0)
	tw.tween_callback(func():
		preview_phase = -1.0
		if curve_canvas: curve_canvas.queue_redraw()
	)

func _process(_delta: float) -> void:
	if preview_phase >= 0.0 and curve_canvas:
		curve_canvas.queue_redraw()

func _on_draw_curve() -> void:
	if not curve_canvas:
		return
	var size = curve_canvas.size
	curve_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.13, 1.0))
	curve_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.85, 0.75, 0.4), false, 1.0)
	
	var total_time = modulator_resource.attack_time + modulator_resource.hold_time + modulator_resource.decay_time + 0.3 + modulator_resource.release_time
	if total_time <= 0.001: total_time = 1.0
	
	var p0 = Vector2(4, size.y - 4)
	var x_atk = 4 + (modulator_resource.attack_time / total_time) * (size.x - 8)
	var p_atk = Vector2(x_atk, 6)
	
	var x_hld = x_atk + (modulator_resource.hold_time / total_time) * (size.x - 8)
	var p_hld = Vector2(x_hld, 6)
	
	var x_dcy = x_hld + (modulator_resource.decay_time / total_time) * (size.x - 8)
	var y_sus = 6 + (1.0 - modulator_resource.sustain_level) * (size.y - 12)
	var p_dcy = Vector2(x_dcy, y_sus)
	
	var x_sus = x_dcy + (0.3 / total_time) * (size.x - 8)
	var p_sus = Vector2(x_sus, y_sus)
	
	var x_rel = x_sus + (modulator_resource.release_time / total_time) * (size.x - 8)
	var p_rel = Vector2(minf(x_rel, size.x - 4), size.y - 4)
	
	var curve_color = Color(0.25, 0.95, 0.85)
	curve_canvas.draw_line(p0, p_atk, curve_color, 2.0)
	curve_canvas.draw_line(p_atk, p_hld, curve_color, 2.0)
	curve_canvas.draw_line(p_hld, p_dcy, curve_color, 2.0)
	curve_canvas.draw_line(p_dcy, p_sus, curve_color, 2.0)
	curve_canvas.draw_line(p_sus, p_rel, curve_color, 2.0)
	
	# Handles
	curve_canvas.draw_circle(p_atk, 3.0, Color.WHITE)
	curve_canvas.draw_circle(p_hld, 3.0, Color.WHITE)
	curve_canvas.draw_circle(p_dcy, 3.0, Color.WHITE)
	curve_canvas.draw_circle(p_sus, 3.0, Color.WHITE)
	
	# Playhead dot if active
	if preview_phase >= 0.0:
		var dot_x = 4 + preview_phase * (size.x - 8)
		curve_canvas.draw_line(Vector2(dot_x, 2), Vector2(dot_x, size.y - 2), Color(1.0, 0.4, 0.4), 1.5)
