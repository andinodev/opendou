@tool
class_name OpenDouGameSyncsPanel
extends PanelContainer

## Sidebar manager for Game Syncs (RTPCs, States, Switches, and Triggers) in OpenDou Studio.

signal rtpc_selected(param_name: StringName, min_val: float, max_val: float, def_val: float)
signal syncs_updated()

var tab_container: TabContainer
var rtpc_tree: Tree
var state_tree: Tree
var switch_tree: Tree

# In-Memory Project Game Syncs Registry
var rtpcs: Dictionary = {
	&"RPM": { "min": 0.0, "max": 8000.0, "default": 1000.0 },
	&"Health": { "min": 0.0, "max": 100.0, "default": 100.0 },
	&"Distance": { "min": 0.0, "max": 100.0, "default": 0.0 },
	&"Speed": { "min": 0.0, "max": 50.0, "default": 0.0 }
}

var states: Dictionary = {
	&"GameState": ["Exploration", "Combat", "Stealth", "Defeat"],
	&"Environment": ["Outdoor", "Cave", "Underwater", "Space"]
}

var switches: Dictionary = {
	&"SurfaceType": ["Asphalt", "Mud", "Metal", "Stone", "Wood", "Water"],
	&"WeaponType": ["Pistol", "Rifle", "Shotgun", "RocketLauncher"]
}

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 6)
	add_child(v_box)
	
	# Header
	var title_lbl = Label.new()
	title_lbl.text = " 🎮 Game Syncs Manager"
	title_lbl.add_theme_font_size_override("font_size", 12)
	v_box.add_child(title_lbl)
	
	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_child(tab_container)
	
	# Tab 1: RTPCs
	var rtpc_box = VBoxContainer.new()
	rtpc_box.name = "📈 RTPCs"
	rtpc_box.add_theme_constant_override("separation", 4)
	
	rtpc_tree = Tree.new()
	rtpc_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtpc_tree.columns = 3
	rtpc_tree.set_column_title(0, "Param")
	rtpc_tree.set_column_title(1, "Range")
	rtpc_tree.set_column_title(2, "Default")
	rtpc_tree.set_column_expand(0, true)
	rtpc_tree.set_column_expand(1, true)
	rtpc_tree.set_column_expand(2, true)
	rtpc_tree.set_column_custom_minimum_width(0, 75)
	rtpc_tree.set_column_custom_minimum_width(1, 75)
	rtpc_tree.set_column_custom_minimum_width(2, 60)
	rtpc_tree.column_titles_visible = true
	rtpc_tree.item_activated.connect(_on_rtpc_activated)
	rtpc_box.add_child(rtpc_tree)
	
	var btn_add_rtpc = Button.new()
	btn_add_rtpc.text = "➕ Add RTPC"
	btn_add_rtpc.custom_minimum_size = Vector2(0, 24)
	btn_add_rtpc.pressed.connect(_on_add_rtpc_pressed)
	rtpc_box.add_child(btn_add_rtpc)
	tab_container.add_child(rtpc_box)
	
	# Tab 2: States
	var state_box = VBoxContainer.new()
	state_box.name = "🏷️ States"
	state_box.add_theme_constant_override("separation", 4)
	
	state_tree = Tree.new()
	state_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_tree.set_column_title(0, "Group / State")
	state_tree.column_titles_visible = true
	state_box.add_child(state_tree)
	
	var btn_add_state = Button.new()
	btn_add_state.text = "➕ Add State Group"
	btn_add_state.custom_minimum_size = Vector2(0, 24)
	btn_add_state.pressed.connect(_on_add_state_pressed)
	state_box.add_child(btn_add_state)
	tab_container.add_child(state_box)
	
	# Tab 3: Switches
	var switch_box = VBoxContainer.new()
	switch_box.name = "🔀 Switches"
	switch_box.add_theme_constant_override("separation", 4)
	
	switch_tree = Tree.new()
	switch_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	switch_tree.set_column_title(0, "Group / Switch")
	switch_tree.column_titles_visible = true
	switch_box.add_child(switch_tree)
	
	var btn_add_switch = Button.new()
	btn_add_switch.text = "➕ Add Switch Group"
	btn_add_switch.custom_minimum_size = Vector2(0, 24)
	btn_add_switch.pressed.connect(_on_add_switch_pressed)
	switch_box.add_child(btn_add_switch)
	tab_container.add_child(switch_box)
	
	_refresh_trees()

func _refresh_trees() -> void:
	# 1. RTPC Tree
	rtpc_tree.clear()
	var rtpc_root = rtpc_tree.create_item()
	for param in rtpcs.keys():
		var data = rtpcs[param]
		var item = rtpc_tree.create_item(rtpc_root)
		item.set_text(0, str(param))
		item.set_text(1, "%.0f - %.0f" % [data["min"], data["max"]])
		item.set_text(2, "%.1f" % data["default"])
		
	# 2. State Tree
	state_tree.clear()
	var state_root = state_tree.create_item()
	for grp in states.keys():
		var grp_item = state_tree.create_item(state_root)
		grp_item.set_text(0, "📁 %s" % str(grp))
		for st in states[grp]:
			var st_item = state_tree.create_item(grp_item)
			st_item.set_text(0, "  ▫️ %s" % str(st))
			
	# 3. Switch Tree
	switch_tree.clear()
	var switch_root = switch_tree.create_item()
	for grp in switches.keys():
		var grp_item = switch_tree.create_item(switch_root)
		grp_item.set_text(0, "📁 %s" % str(grp))
		for sw in switches[grp]:
			var sw_item = switch_tree.create_item(grp_item)
			sw_item.set_text(0, "  🔲 %s" % str(sw))

func _on_rtpc_activated() -> void:
	var item = rtpc_tree.get_selected()
	if item:
		var p_name = StringName(item.get_text(0))
		if rtpcs.has(p_name):
			var d = rtpcs[p_name]
			rtpc_selected.emit(p_name, d["min"], d["max"], d["default"])

func _on_add_rtpc_pressed() -> void:
	var new_id = "RTPC_%d" % (rtpcs.size() + 1)
	rtpcs[StringName(new_id)] = { "min": 0.0, "max": 100.0, "default": 50.0 }
	_refresh_trees()
	syncs_updated.emit()

func _on_add_state_pressed() -> void:
	var new_grp = "StateGroup_%d" % (states.size() + 1)
	states[StringName(new_grp)] = ["State_A", "State_B"]
	_refresh_trees()
	syncs_updated.emit()

func _on_add_switch_pressed() -> void:
	var new_grp = "SwitchGroup_%d" % (switches.size() + 1)
	switches[StringName(new_grp)] = ["Switch_1", "Switch_2"]
	_refresh_trees()
	syncs_updated.emit()

func get_all_rtpc_names() -> Array[StringName]:
	var res: Array[StringName] = []
	for k in rtpcs.keys():
		res.append(k)
	return res
