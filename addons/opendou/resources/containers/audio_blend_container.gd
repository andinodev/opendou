@tool
class_name AudioBlendContainer
extends AudioLogicNode

## Plays multiple layers simultaneously, crossfading volumes based on an RTPC curve.

const BlendLayerClass = preload("res://addons/opendou/resources/containers/blend_layer.gd")

@export var rtpc_parameter: StringName = &""
@export var min_input_value: float = 0.0
@export var max_input_value: float = 1.0
@export var layers: Array[BlendLayer] = []
@export var silence_threshold_db: float = -80.0

func _init(p_rtpc_param: StringName = &"", p_min: float = 0.0, p_max: float = 1.0) -> void:
	rtpc_parameter = p_rtpc_param
	min_input_value = p_min
	max_input_value = p_max
	layers = []

## Adds a new blend layer with an associated volume curve.
func add_layer(node: AudioLogicNode, volume_curve: Curve) -> void:
	if node:
		layers.append(BlendLayerClass.new(node, volume_curve))

func resolve(context: AudioPlaybackContext, out_voices: Array[ResolvedVoice]) -> bool:
	var current_rtpc_value: float = 0.0
	if context:
		current_rtpc_value = context.get_rtpc(rtpc_parameter, 0.0)
		
	var norm_x: float = current_rtpc_value
	if max_input_value > min_input_value:
		norm_x = clampf((current_rtpc_value - min_input_value) / (max_input_value - min_input_value), 0.0, 1.0)
		
	var resolved_any: bool = false
	
	for layer in layers:
		if not layer or not layer.node:
			continue
			
		var calculated_volume_db: float = 0.0
		if layer.volume_curve:
			calculated_volume_db = layer.volume_curve.sample(norm_x)
		
		# Silence Culling optimization: Ignore layers fully muted
		if calculated_volume_db <= silence_threshold_db:
			continue
			
		var layer_voices: Array[ResolvedVoice] = []
		if layer.node.resolve(context, layer_voices):
			for v in layer_voices:
				v.volume_offset_db += calculated_volume_db
				out_voices.append(v)
			resolved_any = true
			
	return resolved_any
