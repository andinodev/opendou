class_name DemoHud
extends CanvasLayer

## Cartel de una demo: que demuestra, que teclas tiene, y que de OpenDou ejercita.
##
## La ESTRUCTURA vive en demo_hud.tscn como nodos. El CONTENIDO lo pone cada demo en su
## propia escena, sobre esta instancia, porque es lo unico que cambia entre ellas.
## Ver .agents/rules/04_scene_composition.md.

## Titulo de la demo.
@export var demo_title: String = "OpenDou"

## Lo que la demo tiene que poder demostrar. Una frase.
@export var thesis: String = ""

## Teclas, una por linea. Formato libre: "E — abrir y cerrar la escotilla".
@export var controls: Array[String] = []

## Que de OpenDou ejercita la escena, una por linea.
@export var exercises: Array[String] = []

## Tecla que muestra y oculta el cartel.
@export var toggle_key: Key = KEY_F1

@onready var _title: Label = $Panel/Margin/Column/Title
@onready var _thesis: Label = $Panel/Margin/Column/Thesis
@onready var _controls: Label = $Panel/Margin/Column/Controls
@onready var _exercises: Label = $Panel/Margin/Column/Exercises
@onready var _hint: Label = $Panel/Margin/Column/Hint
@onready var _panel: PanelContainer = $Panel

func _ready() -> void:
	_title.text = demo_title
	_thesis.text = thesis
	_controls.text = "CONTROLES\n" + ("\n".join(controls) if not controls.is_empty() else "—")
	_exercises.text = "ESTA ESCENA EJERCITA\n" + ("\n".join(exercises) if not exercises.is_empty() else "—")
	_hint.text = "%s — mostrar u ocultar este cartel" % OS.get_keycode_string(toggle_key)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		_panel.visible = not _panel.visible
