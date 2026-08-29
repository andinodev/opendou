@tool
class_name OpenDouBankPanel
extends PanelContainer

## Editor panel for packaging audio assets, configuring RAM prefetch budgets, and compiling monolithic SoundBanks.

const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")

var bank_name_edit: LineEdit
var output_path_edit: LineEdit
var prefetch_spin: SpinBox
var budget_bar: ProgressBar
var budget_label: Label
var asset_tree: Tree
var status_label: Label
var compile_button: Button

var max_prefetch_budget_kb: float = 512.0
var current_prefetch_total_kb: float = 64.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui() -> void:
	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 6)
	add_child(v_box)
	
	# 1. Header
	var title_lbl = Label.new()
	title_lbl.text = " 📦 SoundBank Compiler & RAM Budget"
	title_lbl.add_theme_font_size_override("font_size", 13)
	v_box.add_child(title_lbl)
	
	# 2. Bank Name & Output Path
	var name_box = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "Bank:"
	bank_name_edit = LineEdit.new()
	bank_name_edit.text = "Main_Bank"
	bank_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_lbl)
	name_box.add_child(bank_name_edit)
	v_box.add_child(name_box)
	
	var out_box = HBoxContainer.new()
	var out_lbl = Label.new()
	out_lbl.text = "Output:"
	output_path_edit = LineEdit.new()
	output_path_edit.text = "user://main.bank"
	output_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out_box.add_child(out_lbl)
	out_box.add_child(output_path_edit)
	v_box.add_child(out_box)
	
	# 3. RAM Budget Bar
	var budget_box = VBoxContainer.new()
	budget_box.add_theme_constant_override("separation", 2)
	
	budget_label = Label.new()
	budget_label.text = "Prefetch RAM Budget: 64 KB / 512 KB (12.5%)"
	budget_box.add_child(budget_label)
	
	budget_bar = ProgressBar.new()
	budget_bar.max_value = max_prefetch_budget_kb
	budget_bar.value = current_prefetch_total_kb
	budget_bar.show_percentage = false
	budget_box.add_child(budget_bar)
	v_box.add_child(budget_box)
	
	# 4. Prefetch Slice per stream
	var pre_box = HBoxContainer.new()
	var pre_lbl = Label.new()
	pre_lbl.text = "Stream Prefetch (KB):"
	prefetch_spin = SpinBox.new()
	prefetch_spin.min_value = 4.0
	prefetch_spin.max_value = 256.0
	prefetch_spin.value = 64.0
	prefetch_spin.step = 4.0
	prefetch_spin.value_changed.connect(_on_prefetch_changed)
	pre_box.add_child(pre_lbl)
	pre_box.add_child(prefetch_spin)
	v_box.add_child(pre_box)
	
	# 5. Asset Tree
	var tree_lbl = Label.new()
	tree_lbl.text = "Assets Included in Bank:"
	v_box.add_child(tree_lbl)
	
	asset_tree = Tree.new()
	asset_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asset_tree.columns = 3
	asset_tree.set_column_title(0, "Asset")
	asset_tree.set_column_title(1, "Size")
	asset_tree.set_column_title(2, "Prefetch")
	asset_tree.column_titles_visible = true
	v_box.add_child(asset_tree)
	
	# 6. Status & Bake Button
	status_label = Label.new()
	status_label.text = "Ready to compile."
	v_box.add_child(status_label)
	
	compile_button = Button.new()
	compile_button.text = "🔥 Bake SoundBank (.bank)"
	compile_button.custom_minimum_size = Vector2(0, 32)
	compile_button.pressed.connect(_on_compile_pressed)
	v_box.add_child(compile_button)
	
	_populate_sample_assets()

func _populate_sample_assets() -> void:
	asset_tree.clear()
	var root = asset_tree.create_item()
	
	var sample_files = [
		{ "name": "ambient_music_loop.wav", "size": "1,420 KB", "pre": "64 KB" },
		{ "name": "monster_roar_deep.wav", "size": "340 KB", "pre": "32 KB" },
		{ "name": "vehicle_rpm_mid.wav", "size": "512 KB", "pre": "32 KB" }
	]
	
	for s in sample_files:
		var item = asset_tree.create_item(root)
		item.set_text(0, "🎵 %s" % s["name"])
		item.set_text(1, s["size"])
		item.set_text(2, s["pre"])

func _on_prefetch_changed(val: float) -> void:
	current_prefetch_total_kb = val
	if budget_bar:
		budget_bar.value = current_prefetch_total_kb
	if budget_label:
		var pct = (current_prefetch_total_kb / max_prefetch_budget_kb) * 100.0
		budget_label.text = "Prefetch RAM Budget: %.0f KB / %.0f KB (%.1f%%)" % [current_prefetch_total_kb, max_prefetch_budget_kb, pct]

func _on_compile_pressed() -> void:
	var out_path = output_path_edit.text.strip_edges()
	if out_path.is_empty():
		status_label.text = "Error: Invalid output path."
		return
		
	status_label.text = "Compiling %s..." % out_path
	
	# Synthesize dummy PCM for demonstration compilation
	var pcm = PackedByteArray()
	pcm.resize(44100 * 2)
	
	var streams: Array[Dictionary] = [
		{
			"id": 1,
			"name": StringName(bank_name_edit.text),
			"data": pcm,
			"channels": 2,
			"sample_rate": 44100,
			"codec": 0,
			"prefetch_size": int(prefetch_spin.value * 1024)
		}
	]
	
	var ok = SoundBankCompilerClass.compile_bank(out_path, streams)
	if ok:
		status_label.text = "✅ Successfully baked %s" % out_path
	else:
		status_label.text = "❌ Failed to bake %s" % out_path
