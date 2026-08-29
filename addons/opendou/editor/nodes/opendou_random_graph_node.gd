class_name OpenDouRandomGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a stochastic / shuffle variation container.

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
	title = "Random (SFX)"
	custom_minimum_size = Vector2(190, 130)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Shuffle Checkbox
	shuffle_check = CheckBox.new()
	shuffle_check.text = "Shuffle (No-Repeat)"
	shuffle_check.button_pressed = is_shuffle
	shuffle_check.toggled.connect(func(val): is_shuffle = val)
	vbox.add_child(shuffle_check)
	
	# Pitch Jitter
	var pitch_hbox = HBoxContainer.new()
	var pitch_lbl = Label.new()
	pitch_lbl.text = "Pitch Jitter:"
	pitch_spin = SpinBox.new()
	pitch_spin.min_value = 0.0
	pitch_spin.max_value = 1.0
	pitch_spin.step = 0.01
	pitch_spin.value = pitch_jitter
	pitch_spin.value_changed.connect(func(val): pitch_jitter = float(val))
	pitch_hbox.add_child(pitch_lbl)
	pitch_hbox.add_child(pitch_spin)
	vbox.add_child(pitch_hbox)
	
	# Volume Jitter
	var vol_hbox = HBoxContainer.new()
	var vol_lbl = Label.new()
	vol_lbl.text = "Vol Jitter (dB):"
	vol_spin = SpinBox.new()
	vol_spin.min_value = 0.0
	vol_spin.max_value = 12.0
	vol_spin.step = 0.1
	vol_spin.value = volume_jitter_db
	vol_spin.value_changed.connect(func(val): volume_jitter_db = float(val))
	vol_hbox.add_child(vol_lbl)
	vol_hbox.add_child(vol_spin)
	vbox.add_child(vol_hbox)
	
	# Set input slot (left port)
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, true, 0, COLOR_AUDIO_SIGNAL)
	
	# Configure variations
	for i in range(1, variation_count + 1):
		var lbl = Label.new()
		lbl.text = "Variation %d" % i
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(lbl)
		set_slot(i, false, 0, Color.WHITE, true, 0, COLOR_AUDIO_SIGNAL)
