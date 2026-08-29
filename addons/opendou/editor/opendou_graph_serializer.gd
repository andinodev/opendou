class_name OpenDouGraphSerializer
extends RefCounted

## Serializes and deserializes between visual GraphEdit node topologies and AudioLogicNode Composite trees.

const OpenDouBaseGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_base_graph_node.gd")
const OpenDouBlendGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_blend_graph_node.gd")
const OpenDouRandomGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_random_graph_node.gd")
const OpenDouSwitchGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_switch_graph_node.gd")
const OpenDouAudioFileGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_audio_file_graph_node.gd")
const OpenDouOutputGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_output_graph_node.gd")

const AudioLogicNodeClass = preload("res://addons/opendou/resources/containers/audio_logic_node.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")

## Converts an AudioLogicNode composite resource tree into visual GraphNodes and connections inside a GraphEdit.
static func populate_graph_from_composite(root_node: AudioLogicNode, graph_edit: GraphEdit) -> void:
	if not graph_edit or not root_node:
		return
		
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is OpenDouBaseGraphNode:
			child.queue_free()
			
	var output_node = OpenDouOutputGraphNodeClass.new()
	output_node.name = "OutputNode"
	output_node.position_offset = Vector2(800, 200)
	graph_edit.add_child(output_node)
	
	_recursive_build_visual(root_node, graph_edit, output_node, 0, Vector2(400, 200))

static func _recursive_build_visual(logic_node: AudioLogicNode, graph_edit: GraphEdit, parent_visual: OpenDouBaseGraphNode, target_port: int, offset: Vector2) -> OpenDouBaseGraphNode:
	var visual: OpenDouBaseGraphNode = null
	
	if logic_node is AudioPhysicalNodeClass:
		var wav_node = OpenDouAudioFileGraphNodeClass.new()
		wav_node.position_offset = offset
		wav_node.set_audio_asset(logic_node.resource_path if not logic_node.resource_path.is_empty() else "sample.wav")
		visual = wav_node
	elif logic_node is AudioRandomContainerClass:
		var rnd_node = OpenDouRandomGraphNodeClass.new()
		rnd_node.position_offset = offset
		rnd_node.is_shuffle = logic_node.is_shuffle
		rnd_node.pitch_jitter = logic_node.pitch_jitter
		rnd_node.volume_jitter_db = logic_node.volume_jitter_db
		visual = rnd_node
		
		# Build children
		var y_step = 140
		var start_y = offset.y - (logic_node.children.size() * y_step * 0.5)
		for i in range(logic_node.children.size()):
			var child_logic = logic_node.children[i]
			var child_pos = Vector2(offset.x - 260, start_y + (i * y_step))
			var child_vis = _recursive_build_visual(child_logic, graph_edit, rnd_node, i, child_pos)
			if child_vis:
				graph_edit.connect_node(child_vis.name, 0, rnd_node.name, i)
	elif logic_node is AudioSwitchContainerClass:
		var sw_node = OpenDouSwitchGraphNodeClass.new()
		sw_node.position_offset = offset
		sw_node.switch_group = logic_node.switch_group
		visual = sw_node
	elif logic_node is AudioBlendContainerClass:
		var bl_node = OpenDouBlendGraphNodeClass.new()
		bl_node.position_offset = offset
		bl_node.rtpc_name = logic_node.rtpc_parameter
		visual = bl_node
		
	if visual:
		graph_edit.add_child(visual)
		if parent_visual:
			graph_edit.connect_node(visual.name, 0, parent_visual.name, target_port)
			
	return visual
