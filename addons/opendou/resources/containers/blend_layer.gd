@tool
class_name BlendLayer
extends Resource

## Represents a single layer within an AudioBlendContainer with an associated volume modulation curve.

const AudioLogicNodeClass = preload("res://addons/opendou/resources/containers/audio_logic_node.gd")

@export var node: AudioLogicNode
@export var volume_curve: Curve

func _init(p_node: AudioLogicNode = null, p_curve: Curve = null) -> void:
	node = p_node
	volume_curve = p_curve
