@tool
class_name OpenDouSequenceGraphNode
extends OpenDouBaseGraphNode

## Visual GraphNode for AudioSequenceContainer with sequential step ordering, delays, loop modes, and animated step visualizer.

const AudioSequenceContainerClass = preload("res://addons/opendou/resources/containers/audio_sequence_container.gd")

var sequence_resource: AudioSequenceContainer

var mode_opt: OptionButton
var step_delay_spin: SpinBox
var loop_check: CheckBox
var step_item_list: ItemList
var btn_audition: Button
var active_step_index: int = -1

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_SEQUENCE
	title = "⛓️ Sequence Container"
	custom_minimum_size = Vector2(250, 240)
	sequence_resource = AudioSequenceContainerClass.new()
	_setup_slots()
	_build_ui()

func _setup_slots() -> void:
	# Slot 0: Multiple Audio In (left) -> Audio Out (right)
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, true, 0, COLOR_AUDIO_SIGNAL)

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# Top Mode & Loop Row
	var top_hbox = HBoxContainer.new()
	var mode_lbl = Label.new()
	mode_lbl.text = "Order:"
	mode_lbl.add_theme_font_size_override("font_size", 9)
	top_hbox.add_child(mode_lbl)
	
	mode_opt = OptionButton.new()
	mode_opt.add_item("➡️ Sequential (1→2→3)", 0)
	mode_opt.add_item("🔄 Ping-Pong (1→2→3→2→1)", 1)
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(mode_opt)
	
	loop_check = CheckBox.new()
	loop_check.text = "Loop"
	loop_check.toggled.connect(func(is_l): sequence_resource.loop = is_l)
	top_hbox.add_child(loop_check)
	vbox.add_child(top_hbox)
	
	# Step Delay Row
	var delay_hbox = HBoxContainer.new()
	var d_lbl = Label.new()
	d_lbl.text = "Step Delay (s):"
	d_lbl.add_theme_font_size_override("font_size", 9)
	delay_hbox.add_child(d_lbl)
	
	step_delay_spin = SpinBox.new()
	step_delay_spin.min_value = 0.0
	step_delay_spin.max_value = 5.0
	step_delay_spin.step = 0.05
	step_delay_spin.value = 0.1
	step_delay_spin.custom_minimum_size = Vector2(70, 0)
	delay_hbox.add_child(step_delay_spin)
	vbox.add_child(delay_hbox)
	
	# Step Visual List
	step_item_list = ItemList.new()
	step_item_list.custom_minimum_size = Vector2(0, 85)
	step_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	step_item_list.add_item("1. Step A: Gun_Intro.wav")
	step_item_list.add_item("2. Step B: Gun_Sustain.wav")
	step_item_list.add_item("3. Step C: Gun_Tail_Reverb.wav")
	vbox.add_child(step_item_list)
	
	# Audition Sequence Button
	btn_audition = Button.new()
	btn_audition.text = "▶ Audition Sequence"
	btn_audition.custom_minimum_size = Vector2(0, 24)
	btn_audition.pressed.connect(_on_audition_pressed)
	vbox.add_child(btn_audition)
	
	add_child(vbox)

func _on_audition_pressed() -> void:
	active_step_index = 0
	_highlight_step(0)
	var tw = create_tween()
	tw.tween_interval(0.35 + step_delay_spin.value)
	tw.tween_callback(func(): _highlight_step(1))
	tw.tween_interval(0.35 + step_delay_spin.value)
	tw.tween_callback(func(): _highlight_step(2))
	tw.tween_interval(0.35 + step_delay_spin.value)
	tw.tween_callback(func():
		_highlight_step(-1)
		active_step_index = -1
	)

func _highlight_step(idx: int) -> void:
	if not step_item_list:
		return
	for i in range(step_item_list.item_count):
		if i == idx:
			step_item_list.set_item_custom_fg_color(i, Color(0.3, 1.0, 0.4))
		else:
			step_item_list.set_item_custom_fg_color(i, Color.WHITE)
