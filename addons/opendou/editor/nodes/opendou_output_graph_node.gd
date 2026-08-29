class_name OpenDouOutputGraphNode
extends OpenDouBaseGraphNode

## Terminal visual graph node representing the audio event master output.

func _init() -> void:
	super._init()
	node_type = NodeType.TYPE_OUTPUT
	title = "Output (Audio Output)"
	custom_minimum_size = Vector2(160, 70)
	_build_ui()

func _build_ui() -> void:
	var lbl = Label.new()
	lbl.text = "Event Master Signal"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	
	# Left port enabled for input, right port disabled
	set_slot(0, true, 0, COLOR_AUDIO_SIGNAL, false, 0, Color.WHITE)
