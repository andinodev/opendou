class_name OpenDouBankPanel
extends VBoxContainer

## Editor panel for packaging audio assets, configuring RAM prefetch slices, and compiling monolithic SoundBanks.

const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")

var bank_name_edit: LineEdit
var output_path_edit: LineEdit
var prefetch_spin: SpinBox
var file_list: ItemList
var status_label: Label
var compile_button: Button

func _init() -> void:
	custom_minimum_size = Vector2(260, 220)
	_build_ui()

func _build_ui() -> void:
	# 1. Header
	var title_lbl = Label.new()
	title_lbl.text = "SoundBank Compiler (.bank)"
	title_lbl.add_theme_font_size_override("font_size", 14)
	add_child(title_lbl)
	
	# 2. Bank Name
	var name_box = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "Bank Name:"
	bank_name_edit = LineEdit.new()
	bank_name_edit.text = "Main_Bank"
	bank_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_lbl)
	name_box.add_child(bank_name_edit)
	add_child(name_box)
	
	# 3. Output Path
	var out_box = HBoxContainer.new()
	var out_lbl = Label.new()
	out_lbl.text = "Output File:"
	output_path_edit = LineEdit.new()
	output_path_edit.text = "user://main.bank"
	output_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out_box.add_child(out_lbl)
	out_box.add_child(output_path_edit)
	add_child(out_box)
	
	# 4. Prefetch Slice Size
	var pre_box = HBoxContainer.new()
	var pre_lbl = Label.new()
	pre_lbl.text = "Prefetch (KB):"
	prefetch_spin = SpinBox.new()
	prefetch_spin.min_value = 4.0
	prefetch_spin.max_value = 512.0
	prefetch_spin.value = 64.0
	prefetch_spin.step = 4.0
	pre_box.add_child(pre_lbl)
	pre_box.add_child(prefetch_spin)
	add_child(pre_box)
	
	# 5. Audio Streams File List
	var list_lbl = Label.new()
	list_lbl.text = "Packaged Audio Files:"
	add_child(list_lbl)
	
	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(0, 80)
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(file_list)
	
	# 6. Action buttons (Add File, Remove, Compile)
	var btn_box = HBoxContainer.new()
	var add_btn = Button.new()
	add_btn.text = "+ Add Stream"
	add_btn.pressed.connect(_on_add_stream_pressed)
	
	var rem_btn = Button.new()
	rem_btn.text = "- Remove"
	rem_btn.pressed.connect(_on_remove_stream_pressed)
	
	compile_button = Button.new()
	compile_button.text = "⚡ Compile .bank"
	compile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compile_button.pressed.connect(compile_soundbank)
	
	btn_box.add_child(add_btn)
	btn_box.add_child(rem_btn)
	btn_box.add_child(compile_button)
	add_child(btn_box)
	
	# 7. Status Label
	status_label = Label.new()
	status_label.text = "Ready."
	add_child(status_label)

func _on_add_stream_pressed() -> void:
	var dummy_id = file_list.item_count + 1
	file_list.add_item("res://sfx/stream_sample_%d.wav" % dummy_id)

func _on_remove_stream_pressed() -> void:
	var sel = file_list.get_selected_items()
	if not sel.is_empty():
		file_list.remove_item(sel[0])

## Compiles the current soundbank list into a binary .bank file.
func compile_soundbank() -> bool:
	var compiler = SoundBankCompilerClass.new()
	var bank_name = StringName(bank_name_edit.text)
	var out_path = output_path_edit.text
	var prefetch_bytes = int(prefetch_spin.value * 1024)
	
	for i in range(file_list.item_count):
		var path = file_list.get_item_text(i)
		# Add simulated or real stream buffers
		var dummy_data = PackedByteArray()
		dummy_data.resize(prefetch_bytes + 2048)
		compiler.add_audio_stream(StringName(path.get_file()), dummy_data, prefetch_bytes)
		
	var err = compiler.compile_to_file(out_path, bank_name)
	if err == OK:
		status_label.text = "✅ Bank compiled successfully: %s" % out_path
		return true
	else:
		status_label.text = "❌ Compilation error: %d" % err
		return false
