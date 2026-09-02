@tool
class_name OpenDouListener3D
extends Node3D

## El oyente como nodo propio (Fase 10). El resolver lo prefiere sobre AudioListener3D y la
## camara. Lleva la cabeza (radio para el ITD), un HRTF por jugador y la orientacion externa
## de un giroscopio o un visor. Sin extension nativa solo aporta posicion y orientacion.

signal listener_changed

enum OutputMode { INHERIT, HEADPHONES, SPEAKERS }

## Radio de la cabeza esferica (Woodworth). Escala el ITD.
@export_range(0.02, 0.2, 0.0005) var head_radius_m: float = 0.0875:
	set(v):
		head_radius_m = clampf(v, 0.02, 0.2)
		listener_changed.emit()
## Ruta a un SOFA que manda sobre el ajuste del jugador. Vacio = el del jugador.
@export_file("*.sofa") var hrtf_override: String = "":
	set(v):
		hrtf_override = v
		listener_changed.emit()
## Salida que manda sobre el ajuste del jugador. INHERIT = la del jugador.
@export var output_mode: OutputMode = OutputMode.INHERIT:
	set(v):
		output_mode = v
		listener_changed.emit()
## Si esta activo, la orientacion viene de set_external_orientation(); la posicion sigue
## siendo la del nodo.
@export var use_external_orientation: bool = false:
	set(v):
		use_external_orientation = v
		listener_changed.emit()

var _external_basis: Basis = Basis.IDENTITY

## Orientacion inyectada por un giroscopio o un visor.
func set_external_orientation(basis: Basis) -> void:
	_external_basis = basis.orthonormalized()

func get_effective_basis() -> Basis:
	return _external_basis if use_external_orientation else global_transform.basis

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	# El autoload puede no existir (tests); si existe, el metodo es nuestro y se llama directo.
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		m.register_listener(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		m.unregister_listener(self)
