@tool
class_name OpenDouGameSyncsPanel
extends PanelContainer

## Sidebar manager for Game Syncs (RTPCs, States, Switches, and Triggers) in OpenDou Studio with persistent JSON storage across editor sessions.

signal rtpc_selected(param_name: StringName, min_val: float, max_val: float, def_val: float)
signal rtpc_value_changed(rtpc_name: StringName, value: float)
signal state_changed(group: StringName, state: StringName)
signal switch_changed(group: StringName, sw: StringName)
signal syncs_updated()

const SYNCS_FILE_PATH: String = "res://opendou_syncs.json"

var tab_container: TabContainer
var rtpc_tree: Tree
var state_tree: Tree
var switch_tree: Tree

# Persistent Project Game Syncs Registry
var rtpcs: Dictionary = {}
var states: Dictionary = {}
var switches: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	load_syncs_from_disk()
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
	rtpc_tree.set_column_title(0, "Parameter")
	rtpc_tree.set_column_title(1, "Range")
	rtpc_tree.set_column_title(2, "Default Value")
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

## Loads persistent game syncs registry from project disk file.
func load_syncs_from_disk() -> void:
	if FileAccess.file_exists(SYNCS_FILE_PATH):
		var file = FileAccess.open(SYNCS_FILE_PATH, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_str)
			if parsed is Dictionary:
				_deserialize_syncs(parsed)
				return
				
	# Default Initial Preset if no file exists
	rtpcs = {
		&"RPM": { "min": 0.0, "max": 8000.0, "default": 1000.0 },
		&"Health": { "min": 0.0, "max": 100.0, "default": 100.0 },
		&"Distance": { "min": 0.0, "max": 100.0, "default": 0.0 },
		&"Speed": { "min": 0.0, "max": 50.0, "default": 0.0 }
	}
	states = {
		&"GameState": ["Exploration", "Combat", "Stealth", "Defeat"],
		&"Environment": ["Outdoor", "Cave", "Underwater", "Space"]
	}
	switches = {
		&"SurfaceType": ["Asphalt", "Mud", "Metal", "Stone", "Wood", "Water"],
		&"WeaponType": ["Pistol", "Rifle", "Shotgun", "RocketLauncher"]
	}
	save_syncs_to_disk()

## Saves current game syncs registry permanently to project disk file.
func save_syncs_to_disk() -> void:
	var file = FileAccess.open(SYNCS_FILE_PATH, FileAccess.WRITE)
	if file:
		var data = _serialize_syncs()
		file.store_string(JSON.stringify(data, "\t"))
		file.flush()
		file.close()

func _serialize_syncs() -> Dictionary:
	var rtpcs_data: Dictionary = {}
	for k in rtpcs.keys():
		rtpcs_data[str(k)] = rtpcs[k]
		
	var states_data: Dictionary = {}
	for k in states.keys():
		states_data[str(k)] = states[k]
		
	var switches_data: Dictionary = {}
	for k in switches.keys():
		switches_data[str(k)] = switches[k]
		
	return {
		"rtpcs": rtpcs_data,
		"states": states_data,
		"switches": switches_data
	}

func _deserialize_syncs(data: Dictionary) -> void:
	rtpcs.clear()
	var r_data = data.get("rtpcs", {})
	for k in r_data.keys():
		rtpcs[StringName(k)] = {
			"min": float(r_data[k].get("min", 0.0)),
			"max": float(r_data[k].get("max", 100.0)),
			"default": float(r_data[k].get("default", 0.0))
		}
		
	states.clear()
	var s_data = data.get("states", {})
	for k in s_data.keys():
		var arr: Array = []
		for item in s_data[k]: arr.append(str(item))
		states[StringName(k)] = arr
		
	switches.clear()
	var sw_data = data.get("switches", {})
	for k in sw_data.keys():
		var arr: Array = []
		for item in sw_data[k]: arr.append(str(item))
		switches[StringName(k)] = arr

func _refresh_trees() -> void:
	if not rtpc_tree or not state_tree or not switch_tree:
		return
		
	# 1. RTPC Tree
	rtpc_tree.clear()
	var rtpc_root = rtpc_tree.create_item()
	for param in rtpcs.keys():
		var data = rtpcs[param]
		var item = rtpc_tree.create_item(rtpc_root)
		item.set_text(0, str(param))
		item.set_text(1, "%.0f - %.0f" % [data["min"], data["max"]])
		item.set_text(2, "%.1f" % data["default"])
		item.set_metadata(0, param)
		
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
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func _on_add_state_pressed() -> void:
	var new_grp = "StateGroup_%d" % (states.size() + 1)
	states[StringName(new_grp)] = ["State_A", "State_B"]
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func _on_add_switch_pressed() -> void:
	var new_grp = "SwitchGroup_%d" % (switches.size() + 1)
	switches[StringName(new_grp)] = ["Switch_1", "Switch_2"]
	save_syncs_to_disk()
	_refresh_trees()
	syncs_updated.emit()

func simulate_rtpc_override(rtpc_name: StringName, value: float) -> void:
	if rtpcs.has(rtpc_name):
		rtpcs[rtpc_name]["default"] = value
		rtpc_value_changed.emit(rtpc_name, value)

func get_all_rtpc_names() -> Array[StringName]:
	var res: Array[StringName] = []
	for k in rtpcs.keys():
		res.append(k)
	return res
