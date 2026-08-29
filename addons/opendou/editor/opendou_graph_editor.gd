class_name OpenDouGraphEditor
extends GraphEdit

## Main visual node graph canvas for designing AudioLogicNode trees.

const OpenDouBaseGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_base_graph_node.gd")
const OpenDouBlendGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_blend_graph_node.gd")
const OpenDouRandomGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_random_graph_node.gd")
const OpenDouSwitchGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_switch_graph_node.gd")
const OpenDouAudioFileGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_audio_file_graph_node.gd")
const OpenDouOutputGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_output_graph_node.gd")

var context_menu: PopupMenu
var click_spawn_position: Vector2 = Vector2(200, 200)

func _init() -> void:
	right_disconnects = true
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	_setup_context_menu()

func _setup_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.add_item("Add WAV (Audio File)", 1)
	context_menu.add_item("Add Random (SFX) Container", 2)
	context_menu.add_item("Add Switch (GameSync) Container", 3)
	context_menu.add_item("Add Blend (RTPC) Container", 4)
	context_menu.add_item("Add Output Node", 5)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		click_spawn_position = (event.position + scroll_offset) / zoom
		context_menu.position = Vector2i(get_screen_position() + event.position)
		context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	var new_node: OpenDouBaseGraphNode = null
	match id:
		1: new_node = OpenDouAudioFileGraphNodeClass.new()
		2: new_node = OpenDouRandomGraphNodeClass.new()
		3: new_node = OpenDouSwitchGraphNodeClass.new()
		4: new_node = OpenDouBlendGraphNodeClass.new()
		5: new_node = OpenDouOutputGraphNodeClass.new()
		
	if new_node:
		new_node.position_offset = click_spawn_position
		add_child(new_node)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for n_name in nodes:
		var node = get_node_or_null(NodePath(n_name))
		if node:
			# Disconnect all connected cables
			for conn in get_connection_list():
				if conn["from_node"] == n_name or conn["to_node"] == n_name:
					disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
			node.queue_free()

## Highlights active signal flow during live auditioning.
func highlight_active_branch(active_node_names: Array[StringName]) -> void:
	for child in get_children():
		if child is OpenDouBaseGraphNode:
			var is_act = active_node_names.has(child.name)
			child.set_active_highlight(is_act)
