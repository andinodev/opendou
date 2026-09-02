class_name DemoHub
extends Control

## Lanzador de las demos de OpenDou.
##
## La UI se construye desde ENTRIES en lugar de vivir en el .tscn con un @onready por
## boton. La version anterior tenia diez NodePath hardcodeados y dos de ellos con
## fallback ternario porque las tarjetas se habian movido de sitio: anadir una demo
## costaba editar el .tscn, el script y los dos.

## Las cuatro entradas. Cada demo declara SU tesis: es lo que hay que poder demostrar.
const ENTRIES: Array[Dictionary] = [
	{
		"title": "Bajo la quilla",
		"thesis": "El mismo emisor suena de cuatro maneras distintas solo por geometria.",
		"scene": "res://scenes/demos/keel/keel_demo.tscn",
	},
	{
		"title": "El monzon",
		"thesis": "200 emisores contra 32 voces fisicas, y el trueno hunde el ambiente.",
		"scene": "res://scenes/demos/monsoon/monsoon_demo.tscn",
	},
	{
		"title": "La cabina",
		"thesis": "Un RTPC conduce tres cosas a la vez, y los estados cruzan.",
		"scene": "res://scenes/demos/cabin/cabin_demo.tscn",
	},
	{
		"title": "Una casa canta",
		"thesis": "Una casa vibra, dos duermen, y la calle es el puente: la musica sale por la ventana.",
		"scene": "res://scenes/demos/street/street_demo.tscn",
	},
	{
		"title": "Banco del rig",
		"thesis": "Tres materiales, un jugador con oyente y un NPC sin el.",
		"scene": "res://scenes/rig_bench/rig_bench.tscn",
	},
]

func _ready() -> void:
	_build_ui()

## Lanza la demo por indice.
func launch(index: int) -> void:
	if index < 0 or index >= ENTRIES.size():
		return
	var path: String = str(ENTRIES[index].get("scene", ""))
	if not path.is_empty():
		get_tree().change_scene_to_file(path)

## Rutas declaradas, para comprobar que ninguna esta muerta.
func get_entry_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for entry in ENTRIES:
		paths.append(str(entry.get("scene", "")))
	return paths

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "OpenDou — demos"
	column.add_child(heading)

	var subheading := Label.new()
	subheading.text = "Cada demo demuestra una cosa. Si no se oye, esta roto."
	subheading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subheading)

	for i in range(ENTRIES.size()):
		column.add_child(_build_card(i))

func _build_card(index: int) -> Control:
	var entry: Dictionary = ENTRIES[index]

	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "%d. %s" % [index + 1, str(entry.get("title", ""))]
	box.add_child(title)

	var thesis := Label.new()
	thesis.text = str(entry.get("thesis", ""))
	thesis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(thesis)

	var button := Button.new()
	button.text = "Abrir"
	button.pressed.connect(func(): launch(index))
	box.add_child(button)

	return panel
