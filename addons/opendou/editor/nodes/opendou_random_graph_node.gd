@tool
class_name OpenDouRandomGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a stochastic / shuffle variation container with generous spacing and precision SpinBoxes.

var is_shuffle: bool = true
var pitch_jitter: float = 0.05
var volume_jitter_db: float = 1.5
var variation_count: int = 3

var shuffle_check: CheckBox
var pitch_spin: SpinBox
var vol_spin: SpinBox

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_RANDOM
	title = "🎲 Random / Shuffle Container"
	custom_minimum_size = Vector2(260, 165)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	# Shuffle Checkbox
	shuffle_check = CheckBox.new()
	shuffle_check.text = "Shuffle Bag (Anti-Repetition)"
	shuffle_check.button_pressed = is_shuffle
	shuffle_check.toggled.connect(func(val): is_shuffle = val)
	vbox.add_child(shuffle_check)
	
	# Pitch Jitter Row
	var pitch_hbox = HBoxContainer.new()
	pitch_hbox.add_theme_constant_override("separation", 8)
	var pitch_lbl = Label.new()
	pitch_lbl.text = "Pitch Jitter (±):"
	pitch_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	pitch_spin = SpinBox.new()
	pitch_spin.min_value = 0.0
	pitch_spin.max_value = 1.0
	pitch_spin.step = 0.01
	pitch_spin.value = pitch_jitter
	pitch_spin.custom_minimum_size = Vector2(85, 0)
	pitch_spin.value_changed.connect(func(val): pitch_jitter = float(val))
	
	pitch_hbox.add_child(pitch_lbl)
	pitch_hbox.add_child(pitch_spin)
	vbox.add_child(pitch_hbox)
	
	# Volume Jitter Row
	var vol_hbox = HBoxContainer.new()
	vol_hbox.add_theme_constant_override("separation", 8)
	var vol_lbl = Label.new()
	vol_lbl.text = "Vol Jitter (dB):"
	vol_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	vol_spin = SpinBox.new()
	vol_spin.min_value = 0.0
	vol_spin.max_value = 12.0
	vol_spin.step = 0.1
	vol_spin.value = volume_jitter_db
	vol_spin.custom_minimum_size = Vector2(85, 0)
	vol_spin.value_changed.connect(func(val): volume_jitter_db = float(val))
	
	vol_hbox.add_child(vol_lbl)
	vol_hbox.add_child(vol_spin)
	vbox.add_child(vol_hbox)
	
	# Slot 0: Input logic, Output signal
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, true, 0, COLOR_AUDIO_SIGNAL)
