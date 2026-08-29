@tool
class_name OpenDouConvolutionGraphNode
extends OpenDouBaseGraphNode

## Graph node for Convolution Reverb DSP filtering with Impulse Response (.wav) loader and Wet/Dry mix.

signal ir_selected(ir_name: String)
signal wet_mix_changed(wet_pct: float)

var ir_selector: OptionButton
var wet_slider: HSlider
var wet_spinbox: SpinBox
var predelay_spinbox: SpinBox

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_CONVOLUTION
	title = "🌊 Convolution Reverb"
	custom_minimum_size = Vector2(250, 160)
	
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, true, 0, COLOR_AUDIO_SIGNAL)
	_build_ui()

func _build_ui() -> void:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	add_child(container)
	
	# IR Selector
	var ir_lbl = Label.new()
	ir_lbl.text = "Impulse Response (IR):"
	ir_lbl.add_theme_font_size_override("font_size", 10)
	container.add_child(ir_lbl)
	
	ir_selector = OptionButton.new()
	ir_selector.add_item("🏛️ Cathedral_Hall.wav", 0)
	ir_selector.add_item("🌲 Dense_Forest_IR.wav", 1)
	ir_selector.add_item("🛡️ Stone_Bunker_IR.wav", 2)
	ir_selector.item_selected.connect(func(i): ir_selected.emit(ir_selector.get_item_text(i)))
	container.add_child(ir_selector)
	
	# Wet / Dry compound slider
	var wet_lbl = Label.new()
	wet_lbl.text = "Wet Mix (%):"
	wet_lbl.add_theme_font_size_override("font_size", 10)
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
	pre_lbl.add_theme_font_size_override("font_size", 10)
	pre_hbox.add_child(pre_lbl)
	
	predelay_spinbox = SpinBox.new()
	predelay_spinbox.min_value = 0.0
	predelay_spinbox.max_value = 150.0
	predelay_spinbox.value = 20.0
	predelay_spinbox.step = 1.0
	pre_hbox.add_child(predelay_spinbox)
	container.add_child(pre_hbox)
