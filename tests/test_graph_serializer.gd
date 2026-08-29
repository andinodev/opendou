class_name TestGraphSerializer
extends RefCounted

const OpenDouGraphEditorClass = preload("res://addons/opendou/editor/opendou_graph_editor.gd")
const OpenDouGraphSerializerClass = preload("res://addons/opendou/editor/opendou_graph_serializer.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var editor = OpenDouGraphEditorClass.new()
	
	# Build a composite tree: RandomContainer with 2 physical sound nodes
	var rnd = AudioRandomContainerClass.new()
	rnd.is_shuffle = true
	rnd.pitch_jitter = 0.08
	
	var wav1 = AudioPhysicalNodeClass.new()
	wav1.resource_path = "res://sfx/impact1.wav"
	var wav2 = AudioPhysicalNodeClass.new()
	wav2.resource_path = "res://sfx/impact2.wav"
	
	rnd.children.append(wav1)
	rnd.children.append(wav2)
	
	# Populate graph from composite
	OpenDouGraphSerializerClass.populate_graph_from_composite(rnd, editor)
	
	# Verify visual nodes created (OutputNode + RandomNode + 2 WAV Nodes = 4 nodes)
	var nodes_count = 0
	for c in editor.get_children():
		if c is GraphNode:
			nodes_count += 1
			
	if nodes_count != 4:
		failures.append("Test 1 Failed: Expected 4 visual nodes in GraphEdit, got %d" % nodes_count)
		
	# Verify cable connections
	var conns = editor.get_connection_list()
	if conns.size() < 2:
		failures.append("Test 2 Failed: Expected at least 2 cable connections, got %d" % conns.size())
		
	return failures
