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

## Streams pendientes de compilar en el banco. Es el modelo real que respalda
## asset_tree: antes el arbol se rellenaba con nombres de archivo escritos a
## mano y no habia forma de anadir ni de compilar lo que se veia.
var pending_streams: Array[Dictionary] = []

func _init() -> void:
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
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var v_box = VBoxContainer.new()
	v_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_theme_constant_override("separation", 6)
	margin.add_child(v_box)
	
	# 1. Header
	var title_lbl = Label.new()
	title_lbl.text = "📦 SoundBank Compiler & RAM Budget"
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
	pending_streams.clear()
	pending_streams.append({ "name": "ambient_music_loop.wav", "size_kb": 1420, "prefetch_kb": 64 })
	pending_streams.append({ "name": "monster_roar_deep.wav", "size_kb": 340, "prefetch_kb": 32 })
	pending_streams.append({ "name": "vehicle_rpm_mid.wav", "size_kb": 512, "prefetch_kb": 32 })
	_refresh_asset_tree()

## Redibuja el arbol a partir de pending_streams.
func _refresh_asset_tree() -> void:
	if asset_tree == null:
		return
	asset_tree.clear()
	var root = asset_tree.create_item()
	for entry in pending_streams:
		var item = asset_tree.create_item(root)
		item.set_text(0, "🎵 %s" % str(entry.get("name", "sin_nombre")))
		item.set_text(1, "%d KB" % int(entry.get("size_kb", 0)))
		item.set_text(2, "%d KB" % int(entry.get("prefetch_kb", 0)))

## Anade una entrada de stream a la lista de compilacion del banco.
func _on_add_stream_pressed() -> void:
	var index: int = pending_streams.size() + 1
	pending_streams.append({
		"name": "stream_%02d.wav" % index,
		"size_kb": 0,
		"prefetch_kb": int(prefetch_spin.value) if prefetch_spin != null else 32,
	})
	_refresh_asset_tree()

## Numero de streams en la lista de compilacion.
func get_stream_count() -> int:
	return pending_streams.size()

func _on_prefetch_changed(val: float) -> void:
	current_prefetch_total_kb = val
	if budget_bar:
		budget_bar.value = current_prefetch_total_kb
	if budget_label:
		var pct = (current_prefetch_total_kb / max_prefetch_budget_kb) * 100.0
		budget_label.text = "Prefetch RAM Budget: %.0f KB / %.0f KB (%.1f%%)" % [current_prefetch_total_kb, max_prefetch_budget_kb, pct]

func _on_compile_pressed() -> void:
	var ok: bool = compile_soundbank()
	if status_label == null:
		return
	var out_path: String = output_path_edit.text.strip_edges() if output_path_edit != null else ""
	if out_path.is_empty():
		status_label.text = "Error: Invalid output path."
	elif ok:
		status_label.text = "✅ Successfully baked %s" % out_path
	else:
		status_label.text = "❌ Failed to bake %s" % out_path

## Compila el banco con los streams pendientes. Devuelve true si se escribio.
##
## Esta logica estaba dentro del handler del boton, asi que no habia manera de
## verificarla desde un test sin simular una pulsacion.
func compile_soundbank() -> bool:
	if output_path_edit == null:
		return false
	var out_path: String = output_path_edit.text.strip_edges()
	if out_path.is_empty():
		return false

	var prefetch_bytes: int = int(prefetch_spin.value * 1024.0) if prefetch_spin != null else 32768
	var bank_label: String = bank_name_edit.text if bank_name_edit != null else "Bank"

	# PCM de relleno: el panel todavia no importa audio real desde disco. Lo que
	# se verifica aqui es que el pipeline de empaquetado ODBK escribe el archivo.
	var pcm := PackedByteArray()
	pcm.resize(44100 * 2)

	var streams: Array[Dictionary] = []
	var count: int = maxi(1, pending_streams.size())
	for i in range(count):
		var entry_name: String = bank_label
		if i < pending_streams.size():
			entry_name = str(pending_streams[i].get("name", bank_label))
		streams.append({
			"id": i + 1,
			"name": StringName(entry_name),
			"data": pcm,
			"channels": 2,
			"sample_rate": 44100,
			"codec": 0,
			"prefetch_size": prefetch_bytes
		})

	return bool(SoundBankCompilerClass.compile_bank(out_path, streams))
