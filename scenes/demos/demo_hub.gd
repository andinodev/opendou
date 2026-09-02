class_name DemoHub
extends Control

## Lanzador de las demos de OpenDou.
##
## LAS TARJETAS VIVEN EN LA ESCENA, una por demo, con su titulo, su tesis y su ruta como
## propiedades. Este script solo conecta los botones. Antes construia la UI en codigo con
## botones de ancho completo, que es justo lo que .agents/rules/04_scene_composition.md
## prohibe y lo que la guarda no cubria porque solo miraba las demos.

const HUB_SCENE: String = "res://scenes/demos/demo_hub.tscn"

func _ready() -> void:
	for card in _cards():
		card.launch_requested.connect(_on_launch_requested)

## Rutas declaradas por las tarjetas, para comprobar que ninguna esta muerta.
func get_entry_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for card in _cards():
		paths.append(card.scene_path)
	return paths

## Las tarjetas de la rejilla, en el orden de la escena.
func _cards() -> Array:
	var out: Array = []
	for child in $Margin/Column/Center/Grid.get_children():
		if child is DemoCard:
			out.append(child)
	return out

func _on_launch_requested(scene_path: String) -> void:
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
