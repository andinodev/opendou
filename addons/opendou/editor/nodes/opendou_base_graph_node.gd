class_name OpenDouBaseGraphNode
extends GraphNode

## Base class for all visual logic container nodes in OpenDou Audio Graph Editor.

enum NodeType {
	TYPE_OUTPUT,
	TYPE_AUDIO_FILE,
	TYPE_RANDOM,
	TYPE_SWITCH,
	TYPE_BLEND,
	TYPE_SEQUENCE
}

const COLOR_AUDIO_SIGNAL: Color = Color(0.95, 0.75, 0.2, 1.0) # Gold
const COLOR_LOGIC_BRANCH: Color = Color(0.3, 0.7, 0.95, 1.0) # Cyan/Blue

var node_type: NodeType = NodeType.TYPE_OUTPUT
var is_active_highlight: bool = false

func _init() -> void:
	resizable = false
	custom_minimum_size = Vector2(180, 80)

## Sets the visual active/auditioning state (glowing LED border).
func set_active_highlight(active: bool) -> void:
	is_active_highlight = active
	queue_redraw()

func _draw() -> void:
	if is_active_highlight:
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.2, 0.9, 0.4, 0.35), false, 3.0)
