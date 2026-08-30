@tool
class_name OpenDouConvolutionGraphNode
extends OpenDouBaseGraphNode

## Graph node for Convolution Reverb DSP filtering with Impulse Response (.wav) loader, Sabine Parametric Room Acoustics Designer, and Wet/Dry mix.

signal ir_selected(ir_name: String)
signal wet_mix_changed(wet_pct: float)

var mode_opt: OptionButton
var ir_file_box: VBoxContainer
var ir_selector: OptionButton
var wet_slider: HSlider
var wet_spinbox: SpinBox
var predelay_spinbox: SpinBox

# Parametric Room Designer Controls
var room_box: VBoxContainer
var room_len_spin: SpinBox
var room_width_spin: SpinBox
var room_height_spin: SpinBox
var material_opt: OptionButton
var acoustic_calc_lbl: Label
var ir_waveform_canvas: Control
var btn_generate_ir: Button

# Calculated values
var calculated_rt60: float = 1.42

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_CONVOLUTION
	title = "🌊 Convolution Reverb & Room Designer"
	custom_minimum_size = Vector2(260, 310)
	
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)
	_build_ui()

func _build_ui() -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	add_child(container)
	
	# Reverb Mode Row
	var mode_hbox = HBoxContainer.new()
	var mode_lbl = Label.new()
	mode_lbl.text = "IR Mode:"
	mode_lbl.add_theme_font_size_override("font_size", 9)
	mode_hbox.add_child(mode_lbl)
	
	mode_opt = OptionButton.new()
	mode_opt.add_item("🏛️ Parametric Room Designer", 0)
	mode_opt.add_item("📁 Pre-recorded WAV File", 1)
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_opt.item_selected.connect(_on_mode_selected)
	mode_hbox.add_child(mode_opt)
	container.add_child(mode_hbox)
	
	# 1. Parametric Room Box
	room_box = VBoxContainer.new()
	room_box.add_theme_constant_override("separation", 4)
	
	var dim_grid = GridContainer.new()
	dim_grid.columns = 6
	dim_grid.add_theme_constant_override("h_separation", 4)
	dim_grid.add_theme_constant_override("v_separation", 2)
	
	var l_lbl = Label.new()
	l_lbl.text = "L(m):"
	l_lbl.add_theme_font_size_override("font_size", 8)
	dim_grid.add_child(l_lbl)
	
	room_len_spin = SpinBox.new()
	room_len_spin.min_value = 2.0
	room_len_spin.max_value = 80.0
	room_len_spin.value = 14.0
	room_len_spin.step = 0.5
	room_len_spin.custom_minimum_size = Vector2(48, 0)
	room_len_spin.value_changed.connect(func(_v): _recalculate_room_acoustics())
	dim_grid.add_child(room_len_spin)
	
	var w_lbl = Label.new()
	w_lbl.text = "W(m):"
	w_lbl.add_theme_font_size_override("font_size", 8)
	dim_grid.add_child(w_lbl)
	
	room_width_spin = SpinBox.new()
	room_width_spin.min_value = 2.0
	room_width_spin.max_value = 60.0
	room_width_spin.value = 10.0
	room_width_spin.step = 0.5
	room_width_spin.custom_minimum_size = Vector2(48, 0)
	room_width_spin.value_changed.connect(func(_v): _recalculate_room_acoustics())
	dim_grid.add_child(room_width_spin)
	
	var h_lbl = Label.new()
	h_lbl.text = "H(m):"
	h_lbl.add_theme_font_size_override("font_size", 8)
	dim_grid.add_child(h_lbl)
	
	room_height_spin = SpinBox.new()
	room_height_spin.min_value = 2.0
	room_height_spin.max_value = 30.0
	room_height_spin.value = 6.0
	room_height_spin.step = 0.5
	room_height_spin.custom_minimum_size = Vector2(48, 0)
	room_height_spin.value_changed.connect(func(_v): _recalculate_room_acoustics())
	dim_grid.add_child(room_height_spin)
	room_box.add_child(dim_grid)
	
	var mat_hbox = HBoxContainer.new()
	var mat_lbl = Label.new()
	mat_lbl.text = "Material:"
	mat_lbl.add_theme_font_size_override("font_size", 8)
	mat_hbox.add_child(mat_lbl)
	
	material_opt = OptionButton.new()
	material_opt.add_item("Concrete / Stone (α=0.03)", 0)
	material_opt.add_item("Wood Panels (α=0.12)", 1)
	material_opt.add_item("Plaster / Drywall (α=0.08)", 2)
	material_opt.add_item("Curtains / Fabric (α=0.45)", 3)
	material_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	material_opt.item_selected.connect(func(_idx): _recalculate_room_acoustics())
	mat_hbox.add_child(material_opt)
	room_box.add_child(mat_hbox)
	
	acoustic_calc_lbl = Label.new()
	acoustic_calc_lbl.text = "Vol: 840 m³ | RT60: 1.42s (Sabine)"
	acoustic_calc_lbl.add_theme_font_size_override("font_size", 8)
	acoustic_calc_lbl.modulate = Color(0.3, 0.95, 0.85)
	room_box.add_child(acoustic_calc_lbl)
	
	# IR Waveform Preview Canvas
	ir_waveform_canvas = Control.new()
	ir_waveform_canvas.custom_minimum_size = Vector2(240, 48)
	ir_waveform_canvas.draw.connect(_on_draw_ir_waveform)
	room_box.add_child(ir_waveform_canvas)
	
	container.add_child(room_box)
	
	# 2. File IR Box (hidden by default in parametric mode)
	ir_file_box = VBoxContainer.new()
	ir_file_box.add_theme_constant_override("separation", 4)
	ir_file_box.visible = false
	
	var ir_lbl = Label.new()
	ir_lbl.text = "Impulse Response (IR):"
	ir_lbl.add_theme_font_size_override("font_size", 9)
	ir_file_box.add_child(ir_lbl)
	
	ir_selector = OptionButton.new()
	ir_selector.add_item("🏛️ Cathedral_Hall.wav", 0)
	ir_selector.add_item("🌲 Dense_Forest_IR.wav", 1)
	ir_selector.add_item("🛡️ Stone_Bunker_IR.wav", 2)
	ir_selector.item_selected.connect(func(i): ir_selected.emit(ir_selector.get_item_text(i)))
	ir_file_box.add_child(ir_selector)
	container.add_child(ir_file_box)
	
	# Wet / Dry compound slider
	var wet_lbl = Label.new()
	wet_lbl.text = "Wet Mix (%):"
	wet_lbl.add_theme_font_size_override("font_size", 9)
	container.add_child(wet_lbl)
	
	var wet_hbox = HBoxContainer.new()
	wet_slider = HSlider.new()
	wet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wet_slider.min_value = 0.0
	wet_slider.max_value = 100.0
	wet_slider.value = 35.0
	wet_hbox.add_child(wet_slider)
	
	wet_spinbox = SpinBox.new()
	wet_spinbox.min_value = 0.0
	wet_spinbox.max_value = 100.0
	wet_spinbox.value = 35.0
	wet_hbox.add_child(wet_spinbox)
	
	wet_slider.value_changed.connect(func(v):
		wet_spinbox.value = v
		wet_mix_changed.emit(v)
	)
	wet_spinbox.value_changed.connect(func(v):
		wet_slider.value = v
		wet_mix_changed.emit(v)
	)
	container.add_child(wet_hbox)
	
	# Pre-delay
	var pre_hbox = HBoxContainer.new()
	var pre_lbl = Label.new()
	pre_lbl.text = "Pre-Delay (ms):"
	pre_lbl.add_theme_font_size_override("font_size", 9)
	pre_hbox.add_child(pre_lbl)
	
	predelay_spinbox = SpinBox.new()
	predelay_spinbox.min_value = 0.0
	predelay_spinbox.max_value = 150.0
	predelay_spinbox.value = 20.0
	predelay_spinbox.step = 1.0
	pre_hbox.add_child(predelay_spinbox)
	container.add_child(pre_hbox)
	
	_recalculate_room_acoustics()

func _on_mode_selected(idx: int) -> void:
	if idx == 0:
		room_box.visible = true
		ir_file_box.visible = false
	else:
		room_box.visible = false
		ir_file_box.visible = true

func _recalculate_room_acoustics() -> void:
	if not room_len_spin or not room_width_spin or not room_height_spin:
		return
	var l = room_len_spin.value
	var w = room_width_spin.value
	var h = room_height_spin.value
	var vol = l * w * h
	var surf = 2.0 * (l * w + l * h + w * h)
	
	var alpha = 0.05
	match material_opt.selected:
		0: alpha = 0.03 # Concrete
		1: alpha = 0.12 # Wood
		2: alpha = 0.08 # Plaster
		3: alpha = 0.45 # Fabric
		
	# Sabine equation: RT60 = 0.161 * (V / A) where A = S * alpha
	calculated_rt60 = clampf(0.161 * (vol / maxf(surf * alpha, 0.1)), 0.1, 8.0)
	if acoustic_calc_lbl:
		acoustic_calc_lbl.text = "Vol: %.0f m³ | RT60: %.2fs (Sabine)" % [vol, calculated_rt60]
	if ir_waveform_canvas:
		ir_waveform_canvas.queue_redraw()

func _on_draw_ir_waveform() -> void:
	if not ir_waveform_canvas:
		return
	var size = ir_waveform_canvas.size
	ir_waveform_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.1, 1.0))
	ir_waveform_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.82, 0.85, 0.4), false, 1.0)
	
	var mid_y = size.y * 0.5
	ir_waveform_canvas.draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.2, 0.25, 0.35, 0.5), 1.0)
	
	# Draw synthetic impulse response with early reflections + exponential decay tail
	var steps = int(size.x)
	var prev_top = Vector2(0, mid_y)
	var prev_btm = Vector2(0, mid_y)
	var wave_color = Color(0.15, 0.9, 0.85, 0.8)
	
	var decay_rate = 3.0 / maxf(calculated_rt60, 0.2)
	for i in range(steps):
		var t_norm = float(i) / float(steps)
		var env = exp(-t_norm * decay_rate)
		# Early reflection spikes in first 20%
		var reflection = 0.0
		if t_norm < 0.2:
			if i % 8 == 0: reflection = randf_range(0.5, 1.0) * env
		else:
			reflection = randf_range(-0.8, 0.8) * env
		var amp = absf(reflection) * (size.y * 0.42)
		ir_waveform_canvas.draw_line(Vector2(i, mid_y - amp), Vector2(i, mid_y + amp), wave_color, 1.0)
