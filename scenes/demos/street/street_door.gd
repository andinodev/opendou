class_name StreetDoor
extends Node3D

## Una puerta con bisagra. Gira sobre su borde y arrastra el open_factor de su portal.
##
## El nodo esta en la bisagra y su hijo Leaf -el cuerpo con colision y malla- esta
## desplazado medio ancho, asi que girar ESTE nodo hace girar la hoja sobre el marco.
## Todo eso vive en la escena; aqui solo esta el movimiento, que es lo dinamico.

## El OpenDouPortal3D que esta puerta abre y cierra.
@export var portal_path: NodePath

## Angulo de apertura, en grados.
@export var open_angle_degrees: float = 95.0

## Velocidad del giro, en unidades de 1/s.
@export var swing_speed: float = 4.0

var is_open: bool = false

var _portal = null
var _target_angle: float = 0.0

func _ready() -> void:
	_portal = get_node_or_null(portal_path)
	if _portal != null:
		_portal.open_factor = 0.0

## Abre o cierra.
func toggle() -> void:
	is_open = not is_open
	_target_angle = deg_to_rad(open_angle_degrees) if is_open else 0.0

func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_angle, clampf(swing_speed * delta, 0.0, 1.0))
	# El portal sigue a la hoja: medio abierta es medio abierto. Asi la difraccion cambia
	# de forma continua mientras la puerta gira, no de golpe.
	if _portal != null:
		_portal.open_factor = clampf(absf(rotation.y) / deg_to_rad(open_angle_degrees), 0.0, 1.0)
