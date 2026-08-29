@tool
class_name AudioSequenceContainer
extends AudioLogicNode

## Resolves child nodes in sequential order.

@export var children: Array[AudioLogicNode] = []
@export var loop: bool = false

func _init(p_children: Array[AudioLogicNode] = []) -> void:
	children = p_children

## Adds a child node to the sequence.
func add_child_node(child: AudioLogicNode) -> void:
	if child:
		children.append(child)

func resolve(context: AudioPlaybackContext, out_voices: Array[ResolvedVoice]) -> bool:
	var resolved_any: bool = false
	for child in children:
		if child and child.resolve(context, out_voices):
			resolved_any = true
	return resolved_any
