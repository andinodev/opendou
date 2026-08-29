@tool
class_name OpenDouGraphSerializer
extends RefCounted

## Serializes, deserializes, and compiles between visual GraphEdit node topologies, AudioLogicNode Composite trees, and dynamic DSP processing chains.

const OpenDouBaseGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_base_graph_node.gd")
const OpenDouBlendGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_blend_graph_node.gd")
const OpenDouRandomGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_random_graph_node.gd")
const OpenDouSwitchGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_switch_graph_node.gd")
const OpenDouAudioFileGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_audio_file_graph_node.gd")
const OpenDouOutputGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_output_graph_node.gd")
const OpenDouConvolutionGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_convolution_graph_node.gd")
const OpenDouGranularGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_granular_graph_node.gd")
const OpenDouBinauralGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_binaural_graph_node.gd")

const AudioLogicNodeClass = preload("res://addons/opendou/resources/containers/audio_logic_node.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")

## Reconstructs an executable runtime AudioLogicNode tree and DSP chain from the current GraphEdit canvas.
static func build_composite_from_graph(graph_edit: GraphEdit) -> Dictionary:
	var result = {
		"root_node": null,
		"dsp_chain": [],
		"audio_files": []
	}
	
	if not graph_edit:
		return result
		
	# Find Output Node
	var output_node: OpenDouOutputGraphNode = null
	for child in graph_edit.get_children():
		if child is OpenDouOutputGraphNodeClass:
			output_node = child
			break
			
	var connections = graph_edit.get_connection_list()
	
	# Collect any DSP nodes in the graph
	for child in graph_edit.get_children():
		if child is OpenDouConvolutionGraphNodeClass:
			result["dsp_chain"].append({ "type": "convolution", "node": child })
		elif child is OpenDouGranularGraphNodeClass:
			result["dsp_chain"].append({ "type": "granular", "node": child })
		elif child is OpenDouBinauralGraphNodeClass:
			result["dsp_chain"].append({ "type": "binaural", "node": child })
		elif child is OpenDouAudioFileGraphNodeClass:
			result["audio_files"].append(child)
			
	if not output_node:
		# If no output node, fallback to building container from first root container found
		for child in graph_edit.get_children():
			if child is OpenDouRandomGraphNodeClass or child is OpenDouBlendGraphNodeClass or child is OpenDouSwitchGraphNodeClass:
				result["root_node"] = _compile_node_recursive(child, connections, graph_edit)
				return result
		return result
		
	# Find what connects to Output Node (port 0)
	for conn in connections:
		if conn["to_node"] == output_node.name:
			var source_node = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
			if source_node:
				result["root_node"] = _compile_node_recursive(source_node, connections, graph_edit)
				break
				
	return result

static func _compile_node_recursive(visual_node: Node, connections: Array, graph_edit: GraphEdit) -> AudioLogicNode:
	if visual_node is OpenDouAudioFileGraphNodeClass:
		var phys = AudioPhysicalNodeClass.new()
		phys.stream = visual_node._create_matching_stream()
		phys.pitch_modifier = 1.0
		phys.volume_offset_db = 0.0
		return phys
		
	elif visual_node is OpenDouRandomGraphNodeClass:
		var rnd = AudioRandomContainerClass.new()
		rnd.use_shuffle = visual_node.is_shuffle
		rnd.pitch_jitter_range = Vector2(-visual_node.pitch_jitter, visual_node.pitch_jitter)
		rnd.volume_jitter_db_range = Vector2(-visual_node.volume_jitter_db, 0.0)
		
		# Find all input connections to this random node
		for conn in connections:
			if conn["to_node"] == visual_node.name:
				var child_vis = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
				if child_vis:
					var child_logic = _compile_node_recursive(child_vis, connections, graph_edit)
					if child_logic:
						rnd.children.append(child_logic)
		return rnd
		
	elif visual_node is OpenDouBlendGraphNodeClass:
		var blend = AudioBlendContainerClass.new()
		blend.rtpc_parameter = visual_node.rtpc_name
		for conn in connections:
			if conn["to_node"] == visual_node.name:
				var child_vis = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
				if child_vis:
					var child_logic = _compile_node_recursive(child_vis, connections, graph_edit)
					if child_logic:
						blend.add_layer(child_logic, null)
		return blend
		
	elif visual_node is OpenDouSwitchGraphNodeClass:
		var sw = AudioSwitchContainerClass.new()
		sw.switch_group_name = visual_node.switch_group
		var idx = 0
		for conn in connections:
			if conn["to_node"] == visual_node.name:
				var child_vis = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
				if child_vis:
					var child_logic = _compile_node_recursive(child_vis, connections, graph_edit)
					if child_logic:
						var st_name = StringName("State_%d" % idx)
						sw.set_state_node(st_name, child_logic)
						idx += 1
		return sw
		
	return null

## Converts an AudioLogicNode composite resource tree into visual GraphNodes and connections inside a GraphEdit.
static func populate_graph_from_composite(root_node: AudioLogicNode, graph_edit: GraphEdit) -> void:
	if not graph_edit or not root_node:
		return
		
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is OpenDouBaseGraphNodeClass:
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
