@tool
class_name OpenDouDialogueGrid
extends PanelContainer

## Spreadsheet-style dialogue and localization manager supporting multi-language asset mapping, subtitle metadata, actor assignment, instant audio auditioning, and popout window detach for multi-monitor setups.

signal locale_selected(locale_code: String)
signal dialogue_audition_requested(dialogue_key: StringName, locale_code: String)

const AudioDialogueTableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const AudioDialogueManagerClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_manager.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

var dialogue_table: AudioDialogueTable
var dialogue_manager: AudioDialogueManager

var locale_selector: OptionButton
var grid_tree: Tree
var popout_btn: Button
var file_dialog: FileDialog
var active_editing_item: TreeItem

var audition_player: AudioStreamPlayer
var is_popped_out: bool = false
var detached_window: Window = null

const LOCALES = ["EN", "ES", "JA", "ZH"]

var dialogue_entries: Array[Dictionary] = [
	{
		"key": "HERO_GREETING_01",
		"actor": "Sarah (Protagonist)",
		"text": "Hello traveler, welcome to our sanctuary.",
		"en": "hero_greet_en.wav",
		"es": "hero_greet_es.wav",
		"ja": "hero_greet_ja.wav",
		"zh": "hero_greet_zh.wav",
		"status": "🟢 Ready"
	},
	{
		"key": "HERO_ATTACK_SHOUT",
		"actor": "Sarah (Protagonist)",
		"text": "For the realm! Take this!",
		"en": "hero_atk_en.wav",
		"es": "hero_atk_es.wav",
		"ja": "hero_atk_ja.wav",
		"zh": "hero_atk_zh.wav",
		"status": "🟢 Ready"
	},
	{
		"key": "NPC_WARNING_LOW_HP",
		"actor": "Corvus (Medic)",
		"text": "Watch your flank, you are heavily wounded!",
		"en": "npc_warn_en.wav",
		"es": "npc_warn_es.wav",
		"ja": "npc_warn_ja.wav",
		"zh": "npc_warn_zh.wav",
		"status": "🟡 Draft"
	},
	{
		"key": "BOSS_TAUNT_PHASE2",
		"actor": "Malakor (Shadow Lord)",
		"text": "Fools! You cannot extinguish eternal darkness!",
		"en": "boss_taunt_en.wav",
		"es": "boss_taunt_es.wav",
		"ja": "boss_taunt_ja.wav",
		"zh": "boss_taunt_zh.wav",
		"status": "🟢 Ready"
	}
]

func _init() -> void:
	dialogue_table = AudioDialogueTableClass.new()
	dialogue_manager = AudioDialogueManagerClass.new("en", dialogue_table)
	
	anchors_preset = Control.PRESET_FULL_RECT
	custom_minimum_size = Vector2(0, 0)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(main_vbox)
	
	# Top Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	
	var title_lbl = Label.new()
	title_lbl.text = "🗣️ Voice Localization & Dialogue Grid"
	title_lbl.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(title_lbl)
	
	toolbar.add_child(VSeparator.new())
	
	var loc_lbl = Label.new()
	loc_lbl.text = "Active Locale:"
	loc_lbl.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(loc_lbl)
	
	locale_selector = OptionButton.new()
	locale_selector.add_item("🇺🇸 English (EN)", 0)
	locale_selector.add_item("🇪🇸 Español (ES)", 1)
	locale_selector.add_item("🇯🇵 日本語 (JA)", 2)
	locale_selector.add_item("🇨🇳 中文 (ZH)", 3)
	locale_selector.item_selected.connect(_on_locale_selected)
	toolbar.add_child(locale_selector)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	var btn_add_key = Button.new()
	btn_add_key.text = "➕ Add Dialogue Key"
	btn_add_key.tooltip_text = "Add new dialogue row with actor, subtitles and localized audio stems"
	btn_add_key.custom_minimum_size = Vector2(0, 22)
	btn_add_key.pressed.connect(_on_add_key_pressed)
	toolbar.add_child(btn_add_key)
	
	popout_btn = Button.new()
	popout_btn.text = "🗗 Popout Window"
	popout_btn.tooltip_text = "Open dialogue spreadsheet in detached multi-monitor window"
	popout_btn.custom_minimum_size = Vector2(0, 22)
	popout_btn.pressed.connect(toggle_popout_window)
	toolbar.add_child(popout_btn)
	
	main_vbox.add_child(toolbar)
	
	# Spreadsheet Grid Table (Tree)
	grid_tree = Tree.new()
	grid_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_tree.clip_contents = true
	grid_tree.columns = 6
	grid_tree.column_titles_visible = true
	grid_tree.set_column_title(0, "Dialogue ID Key")
	grid_tree.set_column_title(1, "Actor / Character")
	grid_tree.set_column_title(2, "Subtitle Text")
	grid_tree.set_column_title(3, "Audio File (.wav)")
	grid_tree.set_column_title(4, "Status")
	grid_tree.set_column_title(5, "Audition")
	
	grid_tree.set_column_custom_minimum_width(0, 110)
	grid_tree.set_column_custom_minimum_width(1, 90)
	grid_tree.set_column_custom_minimum_width(2, 120)
	grid_tree.set_column_custom_minimum_width(3, 90)
	grid_tree.set_column_custom_minimum_width(4, 65)
	grid_tree.set_column_custom_minimum_width(5, 55)
	
	for col in range(6):
		grid_tree.set_column_expand(col, true)
		
	grid_tree.item_activated.connect(_on_dialogue_item_activated)
	grid_tree.button_clicked.connect(_on_tree_button_clicked)
	main_vbox.add_child(grid_tree)
	
	# Audio Player & File Picker
	audition_player = AudioStreamPlayer.new()
	add_child(audition_player)
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.wav ; WAV Audio", "*.ogg ; OGG Vorbis"]
	file_dialog.file_selected.connect(_on_audio_file_selected)
	add_child(file_dialog)
	
	_populate_dialogue_samples()

func _populate_dialogue_samples() -> void:
	grid_tree.clear()
	var root = grid_tree.create_item()
	var current_loc = LOCALES[locale_selector.selected].to_lower()
	
	for r in dialogue_entries:
		var item = grid_tree.create_item(root)
		item.set_text(0, "🗣️ " + str(r["key"]))
		item.set_text(1, str(r.get("actor", "NPC")))
		item.set_text(2, str(r.get("text", "")))
		item.set_text(3, "📂 " + str(r.get(current_loc, r["en"])))
		item.set_text(4, str(r.get("status", "🟢 Ready")))
		item.set_text(5, "▶ Audition")
		item.set_metadata(0, r["key"])
		
		# Register in memory table
		dialogue_table.add_entry(StringName(r["key"]), "en", r["en"])
		dialogue_table.add_entry(StringName(r["key"]), "es", r["es"])
		dialogue_table.add_entry(StringName(r["key"]), "ja", r["ja"])
		dialogue_table.add_entry(StringName(r["key"]), "zh", r["zh"])

func _on_add_key_pressed() -> void:
	var next_id = "NEW_DIALOGUE_%d" % (dialogue_entries.size() + 1)
	dialogue_entries.append({
		"key": next_id,
		"actor": "Narrator",
		"text": "New localized line subtitle text.",
		"en": next_id.to_lower() + "_en.wav",
		"es": next_id.to_lower() + "_es.wav",
		"ja": next_id.to_lower() + "_ja.wav",
		"zh": next_id.to_lower() + "_zh.wav",
		"status": "🟡 Draft"
	})
	_populate_dialogue_samples()

func _on_tree_button_clicked(item: TreeItem, column: int, _id: int, _mouse_button_index: int) -> void:
	if column == 3:
		active_editing_item = item
		if file_dialog:
			file_dialog.popup_centered(Vector2i(600, 400))

func _on_audio_file_selected(path: String) -> void:
	if active_editing_item:
		var key = active_editing_item.get_metadata(0)
		var current_loc = LOCALES[locale_selector.selected].to_lower()
		for d in dialogue_entries:
			if d["key"] == key:
				d[current_loc] = path.get_file()
				d["status"] = "🟢 Ready"
				break
		_populate_dialogue_samples()

func _on_dialogue_item_activated() -> void:
	var selected = grid_tree.get_selected()
	if selected:
		var col = grid_tree.get_selected_column()
		var key = selected.get_metadata(0)
		var loc = LOCALES[locale_selector.selected].to_lower()
		if col == 3:
			active_editing_item = selected
			if file_dialog:
				file_dialog.popup_centered(Vector2i(600, 400))
		else:
			audition_dialogue_key(key, loc)

func audition_dialogue_key(key: StringName, loc: String) -> void:
	if audition_player:
		var base_freq = 220.0
		match loc:
			"en": base_freq = 200.0
			"es": base_freq = 240.0
			"ja": base_freq = 280.0
			"zh": base_freq = 320.0
		audition_player.stream = AudioSynthesizerClass.create_engine_loop(base_freq)
		audition_player.pitch_scale = randf_range(0.95, 1.05)
		audition_player.volume_db = 0.0
		audition_player.play()
		
	dialogue_audition_requested.emit(key, loc)

func _on_locale_selected(idx: int) -> void:
	if idx >= 0 and idx < LOCALES.size():
		var loc = LOCALES[idx].to_lower()
		if dialogue_manager:
			dialogue_manager.set_language(loc)
		_populate_dialogue_samples()
		locale_selected.emit(loc)

## Toggles between embedded spreadsheet view and native floating window.
func toggle_popout_window() -> void:
	if not is_popped_out:
		is_popped_out = true
		detached_window = Window.new()
		detached_window.title = "OpenDou Voice Localization Spreadsheet"
		detached_window.size = Vector2i(900, 500)
		detached_window.wrap_controls = false
		detached_window.close_requested.connect(toggle_popout_window)
		
		get_tree().root.add_child(detached_window)
		reparent(detached_window)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
		detached_window.size_changed.connect(func():
			position = Vector2.ZERO
			size = Vector2(detached_window.size)
		)
		popout_btn.text = "📥 Embed Grid"
		detached_window.popup_centered()
	else:
		is_popped_out = false
		if detached_window:
			popout_btn.text = "🗗 Popout Window"
			detached_window.queue_free()
			detached_window = null
