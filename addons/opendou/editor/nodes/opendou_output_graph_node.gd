@tool
class_name OpenDouOutputGraphNode
extends OpenDouBaseGraphNode

## Visual graph node representing the master event output / mixer bus routing.

var bus_name: StringName = &"Master"
var bus_edit: LineEdit

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_OUTPUT
	title = "🔴 Master Output Bus"
	custom_minimum_size = Vector2(240, 130)
	_build_ui()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	
	var bus_hbox = HBoxContainer.new()
	bus_hbox.add_theme_constant_override("separation", 8)
	var bus_lbl = Label.new()
	bus_lbl.text = "Target Audio Bus:"
	bus_edit = LineEdit.new()
	bus_edit.text = str(bus_name)
	bus_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bus_edit.text_changed.connect(func(val): bus_name = StringName(val))
	bus_hbox.add_child(bus_lbl)
	bus_hbox.add_child(bus_edit)
	vbox.add_child(bus_hbox)
	
	var note_lbl = Label.new()
	note_lbl.text = "Final routing to Godot AudioServer"
	note_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(note_lbl)
	
	# Slot 0: Input audio signal
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, false, 0, Color.WHITE)
