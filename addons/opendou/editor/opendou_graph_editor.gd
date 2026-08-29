@tool
class_name OpenDouGraphEditor
extends GraphEdit

## Main visual node graph canvas for designing AudioLogicNode trees with Quick Search, Drag & Drop, and live visual feedback.

const OpenDouBaseGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_base_graph_node.gd")
const OpenDouBlendGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_blend_graph_node.gd")
const OpenDouRandomGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_random_graph_node.gd")
const OpenDouSwitchGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_switch_graph_node.gd")
const OpenDouAudioFileGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_audio_file_graph_node.gd")
const OpenDouOutputGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_output_graph_node.gd")
const OpenDouConvolutionGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_convolution_graph_node.gd")
const OpenDouGranularGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_granular_graph_node.gd")
const OpenDouBinauralGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_binaural_graph_node.gd")

var context_menu: PopupMenu
var click_spawn_position: Vector2 = Vector2(200, 200)

func _init() -> void:
	right_disconnects = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	_setup_context_menu()
	load_event_preset(0)

func _setup_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.add_item("🎵 Add WAV (Audio File)", 1)
	context_menu.add_item("🎲 Add Random / Shuffle Container", 2)
	context_menu.add_item("🔀 Add Switch Container", 3)
	context_menu.add_item("📈 Add Blend (RTPC) Container", 4)
	context_menu.add_item("🌊 Add Convolution Reverb", 6)
	context_menu.add_item("✨ Add Granular Synthesizer", 7)
	context_menu.add_item("🎧 Add Binaural 3D Spatializer", 8)
	context_menu.add_item("🔴 Add Output Bus Node", 5)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

## Loads a fully cohesive, responsive graph preset according to the selected event.
func load_event_preset(preset_id: int) -> void:
	clear_graph()
	
	match preset_id:
		0:
			# 🎯 Battlefield_Gunfire.tres
			var node_wav1 = OpenDouAudioFileGraphNodeClass.new()
			node_wav1.name = "WAV_Gunfire_Var1"
			node_wav1.position_offset = Vector2(60, 40)
			node_wav1.set_audio_asset("res://sfx/gunfire_var1.wav", 1.2)
			add_child(node_wav1)
			
			var node_wav2 = OpenDouAudioFileGraphNodeClass.new()
			node_wav2.name = "WAV_Gunfire_Var2"
			node_wav2.position_offset = Vector2(60, 230)
			node_wav2.set_audio_asset("res://sfx/gunfire_var2.wav", 1.4)
			add_child(node_wav2)
			
			var node_random = OpenDouRandomGraphNodeClass.new()
			node_random.name = "Shuffle_Gunfire_Bag"
			node_random.position_offset = Vector2(350, 120)
			add_child(node_random)
			
			var node_output = OpenDouOutputGraphNodeClass.new()
			node_output.name = "Master_Output"
			node_output.position_offset = Vector2(650, 140)
			add_child(node_output)
			
			connect_node(node_wav1.name, 0, node_random.name, 0)
			connect_node(node_wav2.name, 0, node_random.name, 0)
			connect_node(node_random.name, 0, node_output.name, 0)
			
		1:
			# 🎯 Vehicle_Engine_RPM.tres
			var node_idle = OpenDouAudioFileGraphNodeClass.new()
			node_idle.name = "WAV_Engine_Idle"
			node_idle.position_offset = Vector2(60, 20)
			node_idle.set_audio_asset("res://sfx/engine_idle_loop.wav", 2.0)
			add_child(node_idle)
			
			var node_mid = OpenDouAudioFileGraphNodeClass.new()
			node_mid.name = "WAV_Engine_Mid"
			node_mid.position_offset = Vector2(60, 200)
			node_mid.set_audio_asset("res://sfx/engine_mid_growl.wav", 2.0)
			add_child(node_mid)
			
			var node_high = OpenDouAudioFileGraphNodeClass.new()
			node_high.name = "WAV_Engine_High"
			node_high.position_offset = Vector2(60, 380)
			node_high.set_audio_asset("res://sfx/engine_redline.wav", 2.0)
			add_child(node_high)
			
			var node_blend = OpenDouBlendGraphNodeClass.new()
			node_blend.name = "Blend_RPM_Crossfade"
			node_blend.position_offset = Vector2(350, 180)
			add_child(node_blend)
			
			var node_output = OpenDouOutputGraphNodeClass.new()
			node_output.name = "Master_Output"
			node_output.position_offset = Vector2(650, 200)
			add_child(node_output)
			
			connect_node(node_idle.name, 0, node_blend.name, 0)
			connect_node(node_mid.name, 0, node_blend.name, 0)
			connect_node(node_high.name, 0, node_blend.name, 0)
			connect_node(node_blend.name, 0, node_output.name, 0)
			
		2:
			# 🎯 Footstep_Surface.tres
			var node_concrete = OpenDouAudioFileGraphNodeClass.new()
			node_concrete.name = "WAV_Step_Concrete"
			node_concrete.position_offset = Vector2(60, 30)
			node_concrete.set_audio_asset("res://sfx/concrete_step.wav", 0.4)
			add_child(node_concrete)
			
			var node_mud = OpenDouAudioFileGraphNodeClass.new()
			node_mud.name = "WAV_Step_Mud"
			node_mud.position_offset = Vector2(60, 220)
			node_mud.set_audio_asset("res://sfx/mud_step.wav", 0.4)
			add_child(node_mud)
			
			var node_metal = OpenDouAudioFileGraphNodeClass.new()
			node_metal.name = "WAV_Step_Metal"
			node_metal.position_offset = Vector2(60, 410)
			node_metal.set_audio_asset("res://sfx/metal_step.wav", 0.4)
			add_child(node_metal)
			
			var node_switch = OpenDouSwitchGraphNodeClass.new()
			node_switch.name = "Switch_Surface_Router"
			node_switch.position_offset = Vector2(350, 190)
			add_child(node_switch)
			
			var node_output = OpenDouOutputGraphNodeClass.new()
			node_output.name = "Master_Output"
			node_output.position_offset = Vector2(650, 210)
			add_child(node_output)
			
			connect_node(node_concrete.name, 0, node_switch.name, 0)
			connect_node(node_mud.name, 0, node_switch.name, 0)
			connect_node(node_metal.name, 0, node_switch.name, 0)
			connect_node(node_switch.name, 0, node_output.name, 0)

func clear_graph() -> void:
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			child.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		click_spawn_position = (event.position + scroll_offset) / zoom
		context_menu.position = Vector2i(get_screen_position() + event.position)
		context_menu.popup()
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB or event.keycode == KEY_SPACE:
			click_spawn_position = (get_local_mouse_position() + scroll_offset) / zoom
			context_menu.position = Vector2i(get_screen_position() + get_local_mouse_position())
			context_menu.popup()
		elif event.keycode == KEY_D and event.ctrl_pressed:
			_duplicate_selected_nodes()
		elif event.keycode == KEY_F:
			# Frame center
			scroll_offset = Vector2.ZERO

func _duplicate_selected_nodes() -> void:
	var nodes_to_dup: Array[GraphNode] = []
	for child in get_children():
		if child is GraphNode and child.selected:
			nodes_to_dup.append(child)
			
	for n in nodes_to_dup:
		var dup = n.duplicate() as GraphNode
		dup.position_offset += Vector2(30, 30)
		dup.name = "%s_Copy" % n.name
		add_child(dup)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "files":
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("files"):
		var files = data["files"] as PackedStringArray
		var offset_pos = (at_position + scroll_offset) / zoom
		for f in files:
			if f.ends_with(".wav") or f.ends_with(".ogg"):
				var new_wav = OpenDouAudioFileGraphNodeClass.new()
				new_wav.name = f.get_file().get_basename()
				new_wav.position_offset = offset_pos
				new_wav.set_audio_asset(f)
				add_child(new_wav)
				offset_pos += Vector2(30, 40)

func _on_context_menu_id_pressed(id: int) -> void:
	var new_node: OpenDouBaseGraphNode = null
	match id:
		1: new_node = OpenDouAudioFileGraphNodeClass.new()
		2: new_node = OpenDouRandomGraphNodeClass.new()
		3: new_node = OpenDouSwitchGraphNodeClass.new()
		4: new_node = OpenDouBlendGraphNodeClass.new()
		5: new_node = OpenDouOutputGraphNodeClass.new()
		6: new_node = OpenDouConvolutionGraphNodeClass.new()
		7: new_node = OpenDouGranularGraphNodeClass.new()
		8: new_node = OpenDouBinauralGraphNodeClass.new()
		
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
