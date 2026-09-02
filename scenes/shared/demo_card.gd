class_name DemoCard
extends PanelContainer

## Una tarjeta del hub: titulo, tesis y un boton de ancho fijo. La escena a la que lleva
## es una propiedad: el hub lee sus tarjetas para saber que ofrece, no una lista aparte.

@export var demo_title: String = ""
@export var thesis: String = ""
@export_file("*.tscn") var scene_path: String = ""

signal launch_requested(scene_path: String)

@onready var _title: Label = $Margin/Column/Title
@onready var _thesis: Label = $Margin/Column/Thesis
@onready var _open: Button = $Margin/Column/ButtonRow/Open

func _ready() -> void:
	_title.text = demo_title
	_thesis.text = thesis
	_open.pressed.connect(func(): launch_requested.emit(scene_path))
