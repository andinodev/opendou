class_name PauseMenu
extends CanvasLayer

## El menu de Escape de toda demo: volver al juego, sonido, volver al hub.
##
## NO PAUSA EL AUDIO, a proposito. Congela al jugador -sin movimiento ni camara mientras
## esta abierto- pero la escena sigue: el coche pasa, la musica suena. Si la pausa
## silenciara todo, la pantalla de sonido seria inutil: ajustarias deslizadores a ciegas.
## Un menu de pausa "normal" pausa el mundo; este a proposito no.
##
## La ESTRUCTURA vive en pause_menu.tscn. La lista de buses es la unica parte que se
## construye en codigo, porque es dato de tiempo de ejecucion -cuantos buses hay y como
## se llaman lo decide el AudioServer-, y aun asi cada fila es una subescena.

const BusRowScene = preload("res://scenes/shared/bus_row.tscn")

## A donde vuelve "Volver al hub".
@export_file("*.tscn") var hub_scene_path: String = "res://scenes/demos/demo_hub.tscn"

## Tecla que abre y cierra el menu.
@export var toggle_key: Key = KEY_ESCAPE

@onready var _root: Control = $Root
@onready var _main: VBoxContainer = $Root/Center/Panel/Margin/Column/MainButtons
@onready var _sound: VBoxContainer = $Root/Center/Panel/Margin/Column/SoundPanel
@onready var _bus_list: VBoxContainer = $Root/Center/Panel/Margin/Column/SoundPanel/BusList
@onready var _resume: Button = $Root/Center/Panel/Margin/Column/MainButtons/Resume
@onready var _sound_button: Button = $Root/Center/Panel/Margin/Column/MainButtons/Sound
@onready var _hub: Button = $Root/Center/Panel/Margin/Column/MainButtons/Hub
@onready var _back: Button = $Root/Center/Panel/Margin/Column/SoundPanel/Back
@onready var _backend_label: Label = $Root/Center/Panel/Margin/Column/SoundPanel/BackendLabel
@onready var _blend: HSlider = $Root/Center/Panel/Margin/Column/SoundPanel/BlendRow/BlendSlider
@onready var _output: CheckButton = $Root/Center/Panel/Margin/Column/SoundPanel/OutputToggle
@onready var _sofa: Button = $Root/Center/Panel/Margin/Column/SoundPanel/SofaRow/SofaButton
@onready var _sofa_reset: Button = $Root/Center/Panel/Margin/Column/SoundPanel/SofaRow/SofaResetButton
@onready var _sofa_dialog: FileDialog = $Root/Center/Panel/Margin/Column/SoundPanel/SofaDialog

var is_open: bool = false

func _ready() -> void:
	_root.visible = false
	_sound.visible = false
	_resume.pressed.connect(close)
	_sound_button.pressed.connect(show_sound)
	_hub.pressed.connect(go_to_hub)
	_back.pressed.connect(show_main)
	_blend.value_changed.connect(_on_blend_changed)
	_output.toggled.connect(_on_output_toggled)
	_sofa.pressed.connect(_sofa_dialog.popup_centered)
	_sofa_dialog.file_selected.connect(_on_sofa_selected)
	_sofa_reset.pressed.connect(_on_sofa_reset)
	_refresh_spatial()

func open() -> void:
	is_open = true
	_root.visible = true
	show_main()
	_set_player_input(false)

func close() -> void:
	is_open = false
	_root.visible = false
	_set_player_input(true)

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

## La pantalla de sonido: una fila por bus del AudioServer, en vivo.
func show_sound() -> void:
	_main.visible = false
	_sound.visible = true
	_rebuild_bus_rows()
	_refresh_spatial()

func show_main() -> void:
	_sound.visible = false
	_main.visible = true

func go_to_hub() -> void:
	_set_player_input(true)
	if ResourceLoader.exists(hub_scene_path):
		get_tree().change_scene_to_file(hub_scene_path)

## Filas de bus que hay ahora mismo en la lista.
func bus_rows() -> Array:
	return _bus_list.get_children()

func _rebuild_bus_rows() -> void:
	for child in _bus_list.get_children():
		_bus_list.remove_child(child)
		child.free()
	for i in range(AudioServer.bus_count):
		var row = BusRowScene.instantiate()
		row.bus_name = AudioServer.get_bus_name(i)
		_bus_list.add_child(row)

## El manager del juego, si esta como autoload.
func _manager() -> Node:
	return get_node_or_null("/root/OpenDou")

## Refleja el backend y los ajustes vigentes; con godot, todo deshabilitado y dicho.
func _refresh_spatial() -> void:
	var m: Node = _manager()
	var native: bool = m != null and m.has_method("is_steam_audio_backend") and m.is_steam_audio_backend()
	_backend_label.text = "Backend: %s" % (m.spatial_backend_label() if m != null and m.has_method("spatial_backend_label") else "sin manager")
	_blend.editable = native
	_output.disabled = not native
	_sofa.disabled = not native
	_sofa_reset.disabled = not native
	if m != null and "spatial_settings" in m and m.spatial_settings != null:
		_blend.set_value_no_signal(m.spatial_settings.blend)
		_output.set_pressed_no_signal(m.spatial_settings.output == "speakers")

## Los controles del bloque de espacializacion, para la suite.
func spatial_controls() -> Dictionary:
	return {"backend": _backend_label, "blend": _blend, "output": _output, "sofa": _sofa, "reset": _sofa_reset}

func _on_blend_changed(value: float) -> void:
	var m: Node = _manager()
	if m != null and "spatial_settings" in m:
		m.spatial_settings.set_blend(value)

func _on_output_toggled(on: bool) -> void:
	var m: Node = _manager()
	if m != null and "spatial_settings" in m:
		m.spatial_settings.set_output("speakers" if on else "headphones")

func _on_sofa_selected(path: String) -> void:
	var m: Node = _manager()
	if m != null and "spatial_settings" in m:
		m.spatial_settings.set_hrtf(path)
	_refresh_spatial()

func _on_sofa_reset() -> void:
	var m: Node = _manager()
	if m != null and "spatial_settings" in m:
		m.spatial_settings.set_hrtf("default")
	_refresh_spatial()

## El jugador, si la escena tiene uno: es quien se congela.
func _set_player_input(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "input_enabled" in player:
		player.input_enabled = enabled

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		toggle()
		get_viewport().set_input_as_handled()
