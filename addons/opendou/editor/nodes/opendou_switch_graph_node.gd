class_name OpenDouSwitchGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a discrete switch/state routing container.

var switch_group: StringName = &"SurfaceType"
var states: Array[String] = ["Concrete", "Metal", "Water"]

var group_edit: LineEdit
var slots_vbox: VBoxContainer

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_SWITCH
	title = "Switch (GameSync)"
	custom_minimum_size = Vector2(190, 120)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Switch Group Name
	var group_hbox = HBoxContainer.new()
	var group_lbl = Label.new()
	group_lbl.text = "Group:"
	group_edit = LineEdit.new()
	group_edit.text = str(switch_group)
	group_edit.text_changed.connect(func(val): switch_group = StringName(val))
	group_hbox.add_child(group_lbl)
	group_hbox.add_child(group_edit)
	vbox.add_child(group_hbox)
	
	# Input slot 0
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, false, 0, Color.WHITE)
	
	# Output slots for each state
	slots_vbox = VBoxContainer.new()
	vbox.add_child(slots_vbox)
	_rebuild_state_slots()

func _rebuild_state_slots() -> void:
	for child in slots_vbox.get_children():
		child.queue_free()
		
	for i in range(states.size()):
		var lbl = Label.new()
		lbl.text = states[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slots_vbox.add_child(lbl)
		set_slot(i + 1, false, 0, Color.WHITE, true, 0, COLOR_AUDIO_SIGNAL)

## Sets the list of switch states and updates ports.
func set_states_list(new_states: Array[String]) -> void:
	states = new_states
	_rebuild_state_slots()
