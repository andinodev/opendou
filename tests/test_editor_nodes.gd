class_name TestEditorNodes
extends RefCounted

const OpenDouBaseGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_base_graph_node.gd")
const OpenDouBlendGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_blend_graph_node.gd")
const OpenDouRandomGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_random_graph_node.gd")
const OpenDouSwitchGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_switch_graph_node.gd")
const OpenDouAudioFileGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_audio_file_graph_node.gd")
const OpenDouOutputGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_output_graph_node.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Blend Graph Node
	var blend_node = OpenDouBlendGraphNodeClass.new()
	if blend_node.node_type != OpenDouBaseGraphNodeClass.NodeType.TYPE_BLEND:
		failures.append("Test 1a Failed: Blend node type mismatch")
	if blend_node.rtpc_name != &"RPM":
		failures.append("Test 1b Failed: Blend node initial RTPC name mismatch")
	blend_node.set_live_rtpc_progress(0.75)
	if not is_equal_approx(blend_node.curve_canvas.progress, 0.75):
		failures.append("Test 1c Failed: Blend node mini curve progress update failed")
		
	# Test 2: Random Graph Node
	var random_node = OpenDouRandomGraphNodeClass.new()
	if random_node.node_type != OpenDouBaseGraphNodeClass.NodeType.TYPE_RANDOM:
		failures.append("Test 2a Failed: Random node type mismatch")
	if not random_node.is_shuffle or not is_equal_approx(random_node.pitch_jitter, 0.05):
		failures.append("Test 2b Failed: Random node properties mismatch")
		
	# Test 3: Switch Graph Node
	var switch_node = OpenDouSwitchGraphNodeClass.new()
	if switch_node.node_type != OpenDouBaseGraphNodeClass.NodeType.TYPE_SWITCH:
		failures.append("Test 3a Failed: Switch node type mismatch")
	switch_node.set_states_list(["Wood", "Stone", "Dirt", "Metal"])
	if switch_node.states.size() != 4:
		failures.append("Test 3b Failed: Switch node states dynamic resize failed")
		
	# Test 4: Audio File Graph Node
	var audio_node = OpenDouAudioFileGraphNodeClass.new()
	if audio_node.node_type != OpenDouBaseGraphNodeClass.NodeType.TYPE_AUDIO_FILE:
		failures.append("Test 4a Failed: Audio file node type mismatch")
	audio_node.set_audio_asset("res://sfx/shot.wav", 1.8)
	if audio_node.duration_sec != 1.8 or audio_node.audio_path != "res://sfx/shot.wav":
		failures.append("Test 4b Failed: Audio file node asset assignment failed")
		
	# Test 5: Output Graph Node
	var output_node = OpenDouOutputGraphNodeClass.new()
	if output_node.node_type != OpenDouBaseGraphNodeClass.NodeType.TYPE_OUTPUT:
		failures.append("Test 5 Failed: Output node type mismatch")
		
	return failures
