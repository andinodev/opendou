@tool
class_name OpenDouBaseGraphNode
extends GraphNode

## Base class for visual logic container nodes in OpenDou Audio Graph Editor with enhanced respiration, margins, and functional color coding.

enum NodeType {
	TYPE_OUTPUT,
	TYPE_AUDIO_FILE,
	TYPE_RANDOM,
	TYPE_SWITCH,
	TYPE_BLEND,
	TYPE_SEQUENCE,
	TYPE_CONVOLUTION,
	TYPE_GRANULAR,
	TYPE_BINAURAL
}

const COLOR_AUDIO_SIGNAL: Color = Color(0.18, 0.83, 0.55, 1.0) # Emerald Mint
const COLOR_LOGIC_BRANCH: Color = Color(0.22, 0.74, 0.97, 1.0) # Sapphire Cyan

const NODE_ACCENT_COLORS = {
	NodeType.TYPE_AUDIO_FILE: Color(0.18, 0.83, 0.55), # Emerald Mint
	NodeType.TYPE_RANDOM: Color(0.22, 0.74, 0.97),     # Sapphire Cyan
	NodeType.TYPE_SWITCH: Color(0.75, 0.52, 0.98),     # Purple Magenta
	NodeType.TYPE_BLEND: Color(0.98, 0.75, 0.14),      # Amber Gold
	NodeType.TYPE_OUTPUT: Color(0.97, 0.44, 0.44),     # Coral Red
	NodeType.TYPE_CONVOLUTION: Color(0.12, 0.82, 0.85),# Cyan Teal
	NodeType.TYPE_GRANULAR: Color(0.98, 0.55, 0.22),   # Coral Orange
	NodeType.TYPE_BINAURAL: Color(0.45, 0.55, 0.98)    # Royal Indigo
}

var node_type: NodeType = NodeType.TYPE_OUTPUT
var is_active_highlight: bool = false

func _init() -> void:
	resizable = false
	custom_minimum_size = Vector2(240, 140)

## Sets the visual active/auditioning state (glowing LED border).
func set_active_highlight(active: bool) -> void:
	is_active_highlight = active
	queue_redraw()

func _draw() -> void:
	var accent = NODE_ACCENT_COLORS.get(node_type, Color(0.5, 0.6, 0.7))
	# Draw accent bar at top header
	draw_line(Vector2(6, 1), Vector2(size.x - 6, 1), accent, 4.0)
	
	if is_active_highlight:
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.2, 0.95, 0.5, 0.4), false, 3.0)
