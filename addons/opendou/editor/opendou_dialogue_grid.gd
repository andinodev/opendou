@tool
class_name OpenDouDialogueGrid
extends PanelContainer

## Spreadsheet-style dialogue and localization manager supporting multi-language asset mapping, instant audio auditioning, and popout window detach for multi-monitor setups.

signal locale_selected(locale_code: String)
signal dialogue_audition_requested(dialogue_key: StringName, locale_code: String)

const AudioDialogueTableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const AudioDialogueManagerClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_manager.gd")

var dialogue_table: AudioDialogueTable
var dialogue_manager: AudioDialogueManager

var locale_selector: OptionButton
var grid_tree: Tree
var popout_btn: Button

var is_popped_out: bool = false
var detached_window: Window = null

const LOCALES = ["EN", "ES", "JA", "ZH"]

func _init() -> void:
	dialogue_table = AudioDialogueTableClass.new()
	dialogue_manager = AudioDialogueManagerClass.new("en", dialogue_table)
	
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)
	
	# Top Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	
	var title_lbl = Label.new()
	title_lbl.text = "🗣️ Voice Localization & Dialogue Grid"
	title_lbl.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(title_lbl)
	
	toolbar.add_child(VSeparator.new())
	
	var loc_lbl = Label.new()
	loc_lbl.text = "Active Audition Locale:"
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
	btn_add_key.text = "➕ Add Key"
	btn_add_key.tooltip_text = "Add new dialogue entry key"
	toolbar.add_child(btn_add_key)
	
	popout_btn = Button.new()
	popout_btn.text = "🗗 Popout Window"
	popout_btn.tooltip_text = "Open dialogue spreadsheet in detached multi-monitor window"
	popout_btn.pressed.connect(toggle_popout_window)
	toolbar.add_child(popout_btn)
	
	main_vbox.add_child(toolbar)
	
	# Spreadsheet Grid Table (Tree)
	grid_tree = Tree.new()
	grid_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_tree.columns = 6
	grid_tree.column_titles_visible = true
	grid_tree.set_column_title(0, "Dialogue ID Key")
	grid_tree.set_column_title(1, "English (EN)")
	grid_tree.set_column_title(2, "Spanish (ES)")
	grid_tree.set_column_title(3, "Japanese (JA)")
	grid_tree.set_column_title(4, "Chinese (ZH)")
	grid_tree.set_column_title(5, "Audition")
	
	grid_tree.set_column_custom_minimum_width(0, 160)
	grid_tree.set_column_custom_minimum_width(1, 130)
	grid_tree.set_column_custom_minimum_width(2, 130)
	grid_tree.set_column_custom_minimum_width(3, 130)
	grid_tree.set_column_custom_minimum_width(4, 130)
	grid_tree.set_column_custom_minimum_width(5, 75)
	
	for col in range(6):
		grid_tree.set_column_expand(col, true)
		
	main_vbox.add_child(grid_tree)
	_populate_dialogue_samples()

func _populate_dialogue_samples() -> void:
	grid_tree.clear()
	var root = grid_tree.create_item()
	
	var rows = [
		{ "key": "HERO_GREETING_01", "en": "hero_greet_en.wav", "es": "hero_greet_es.wav", "ja": "hero_greet_ja.wav", "zh": "hero_greet_zh.wav" },
		{ "key": "HERO_ATTACK_SHOUT", "en": "hero_atk_en.wav", "es": "hero_atk_es.wav", "ja": "hero_atk_ja.wav", "zh": "hero_atk_zh.wav" },
		{ "key": "NPC_WARNING_LOW_HP", "en": "npc_warn_en.wav", "es": "npc_warn_es.wav", "ja": "npc_warn_ja.wav", "zh": "npc_warn_zh.wav" },
		{ "key": "BOSS_TAUNT_PHASE2", "en": "boss_taunt_en.wav", "es": "boss_taunt_es.wav", "ja": "boss_taunt_ja.wav", "zh": "boss_taunt_zh.wav" }
	]
	
	for r in rows:
		var item = grid_tree.create_item(root)
		item.set_text(0, "🗣️ " + r["key"])
		item.set_text(1, r["en"])
		item.set_text(2, r["es"])
		item.set_text(3, r["ja"])
		item.set_text(4, r["zh"])
		item.set_text(5, "▶ Audition")
		item.set_metadata(0, r["key"])

func _on_locale_selected(idx: int) -> void:
	if idx >= 0 and idx < LOCALES.size():
		var loc = LOCALES[idx].to_lower()
		if dialogue_manager:
			dialogue_manager.set_language(loc)
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
		popout_btn.text = "📥 Embed Grid"
		detached_window.popup_centered()
	else:
		is_popped_out = false
		if detached_window:
			popout_btn.text = "🗗 Popout Window"
			detached_window.queue_free()
			detached_window = null
