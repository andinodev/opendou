@tool
class_name OpenDouSwitchGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing a discrete switch/state routing container.

var switch_group: StringName = &"SurfaceType"
var states: Array[String] = ["Asphalt", "Mud", "Metal", "Stone", "Wood", "Water"]

var group_edit: LineEdit
var slots_vbox: VBoxContainer

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_SWITCH
	title = "🔀 Switch (GameSync Branch)"
	custom_minimum_size = Vector2(250, 170)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	
	# Switch Group Name
	var group_hbox = HBoxContainer.new()
	group_hbox.add_theme_constant_override("separation", 8)
	var group_lbl = Label.new()
	group_lbl.text = "Switch Group:"
	group_edit = LineEdit.new()
	group_edit.text = str(switch_group)
	group_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_edit.text_changed.connect(func(val): switch_group = StringName(val))
	group_hbox.add_child(group_lbl)
	group_hbox.add_child(group_edit)
	vbox.add_child(group_hbox)
	
	# Slot 0: Input logic
	set_slot(0, true, 0, COLOR_LOGIC_BRANCH, true, 0, COLOR_AUDIO_SIGNAL)
	
	# Output branches summary
	var branches_lbl = Label.new()
	branches_lbl.text = "States: Asphalt • Mud • Metal • Stone • Wood • Water"
	branches_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(branches_lbl)

## Sustituye la lista de estados del switch y reconstruye sus slots.
## La llama el editor al cargar un contenedor cuyos estados no son los de por
## defecto, y el panel de Game Syncs cuando cambia el grupo activo.
func set_states_list(new_states: Array) -> void:
	states.clear()
	for s in new_states:
		states.append(str(s))
	_rebuild_state_slots()

## Redibuja un slot de salida por estado.
func _rebuild_state_slots() -> void:
	if slots_vbox == null:
		return
	for child in slots_vbox.get_children():
		child.queue_free()
	for i in range(states.size()):
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = states[i]
		row.add_child(lbl)
		slots_vbox.add_child(row)
