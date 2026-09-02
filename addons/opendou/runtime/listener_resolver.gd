class_name OpenDouListenerResolver
extends RefCounted

## Determina la posicion y la orientacion del oyente.
##
## Replica la regla de Godot en lugar de inventar una propia: el AudioListener3D
## activo del viewport y, en su defecto, la Camera3D activa. Un override explicito
## tiene prioridad sobre ambos, para juegos con el oyente desacoplado de la camara.
##
## Existe porque nadie invocaba set_listener_position() y active_listener_position
## se quedaba en Vector3.ZERO de forma permanente: el voice-stealing medía
## distancias desde el origen del mundo y el rayo de oclusion apuntaba a (0,0,0)
## en lugar de al oyente.

var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY

## De donde se resolvio: &"override_position", &"override_node", &"opendou_listener_3d",
## &"audio_listener_3d", &"camera_3d" o &"none".
var source: StringName = &"none"

var _override_node_ref: WeakRef = null
var _opendou_listener_ref: WeakRef = null
var _override_position: Vector3 = Vector3.ZERO
var _has_override_position: bool = false

## Fija un nodo como oyente explicito. Pasar null lo desactiva.
func set_listener_node(node: Node3D) -> void:
	_override_node_ref = weakref(node) if node != null else null
	if node != null:
		_has_override_position = false

## Fija el OpenDouListener3D registrado (Fase 10). Va entre los overrides y la regla de Godot.
func set_opendou_listener(node: Node3D) -> void:
	_opendou_listener_ref = weakref(node) if node != null else null

## Fija una posicion fija de oyente. Tiene prioridad sobre todo lo demas.
func set_listener_position(pos: Vector3) -> void:
	_override_position = pos
	_has_override_position = true
	_override_node_ref = null

## Elimina cualquier override y vuelve a la regla de Godot.
func clear_override() -> void:
	_override_node_ref = null
	_has_override_position = false

## Resuelve el oyente para este frame. Devuelve true si encontro alguno.
func resolve(viewport: Viewport) -> bool:
	if _has_override_position:
		position = _override_position
		basis = Basis.IDENTITY
		source = &"override_position"
		return true

	if _override_node_ref != null:
		var n = _override_node_ref.get_ref()
		if n != null and is_instance_valid(n) and n is Node3D and n.is_inside_tree():
			position = n.global_position
			basis = n.global_transform.basis
			source = &"override_node"
			return true

	if _opendou_listener_ref != null:
		var l = _opendou_listener_ref.get_ref()
		if l != null and is_instance_valid(l) and l is Node3D and l.is_inside_tree():
			position = l.global_position
			basis = l.get_effective_basis()
			source = &"opendou_listener_3d"
			return true

	if viewport != null:
		var listener := viewport.get_audio_listener_3d()
		if listener != null and is_instance_valid(listener) and listener.is_inside_tree():
			position = listener.global_position
			basis = listener.global_transform.basis
			source = &"audio_listener_3d"
			return true
		var cam := viewport.get_camera_3d()
		if cam != null and is_instance_valid(cam) and cam.is_inside_tree():
			position = cam.global_position
			basis = cam.global_transform.basis
			source = &"camera_3d"
			return true

	source = &"none"
	return false
