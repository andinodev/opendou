@tool
class_name OpenDouAcousticVolume3D
extends Area3D

## Volumen de entorno acustico (Fase 10). Sus formas son los CollisionShape3D hijos; la
## pertenencia del oyente se decide por geometria (caja, esfera, cilindro analiticos; otras
## por su AABB), no por body_entered: el oyente no es un cuerpo.

const AcousticEnvironmentClass = preload("res://addons/opendou/resources/acoustic_environment.gd")

@export var environment: AcousticEnvironment = null
## Entre volumenes que contienen al oyente, manda el de mayor prioridad.
@export var volume_priority: int = 0

var _warned_no_shape: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		m.register_acoustic_volume(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		m.unregister_acoustic_volume(self)

func _shapes() -> Array:
	var out: Array = []
	for c in get_children():
		if c is CollisionShape3D and c.shape != null:
			out.append(c)
	if out.is_empty() and not _warned_no_shape:
		_warned_no_shape = true
		push_warning("[OpenDou] %s no tiene CollisionShape3D: no contiene nada" % name)
	return out

## True si el punto (mundo) cae dentro de alguna forma.
func contains_point(p: Vector3) -> bool:
	for cs in _shapes():
		var local: Vector3 = cs.global_transform.affine_inverse() * p
		var sh: Shape3D = cs.shape
		if sh is BoxShape3D:
			var h: Vector3 = sh.size * 0.5
			if absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z:
				return true
		elif sh is SphereShape3D:
			if local.length() <= sh.radius:
				return true
		elif sh is CylinderShape3D:
			if absf(local.y) <= sh.height * 0.5 and Vector2(local.x, local.z).length() <= sh.radius:
				return true
		else:
			if sh.get_debug_mesh().get_aabb().has_point(local):
				return true
	return false

## Longitud (m) del segmento a->b (mundo) que queda dentro del volumen. Caja y esfera
## analiticas (slab y cuerda); cilindro y otras por su AABB. Si hay varias formas se suma.
func segment_length_inside(a: Vector3, b: Vector3) -> float:
	var total: float = 0.0
	var world_len: float = a.distance_to(b)
	for cs in _shapes():
		var inv: Transform3D = cs.global_transform.affine_inverse()
		var la: Vector3 = inv * a
		var lb: Vector3 = inv * b
		var sh: Shape3D = cs.shape
		if sh is SphereShape3D:
			total += _sphere_chord(la, lb, sh.radius) * world_len
		else:
			var half: Vector3
			if sh is BoxShape3D:
				half = sh.size * 0.5
			elif sh is CylinderShape3D:
				half = Vector3(sh.radius, sh.height * 0.5, sh.radius)
			else:
				var aabb: AABB = sh.get_debug_mesh().get_aabb()
				half = aabb.size * 0.5
				la -= aabb.get_center()
				lb -= aabb.get_center()
			total += _box_slab(la, lb, half) * world_len
	return total

## Fraccion [0,1] del segmento local la->lb dentro de la caja centrada de semilados `half`.
static func _box_slab(la: Vector3, lb: Vector3, half: Vector3) -> float:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector3 = lb - la
	for axis in range(3):
		if absf(d[axis]) < 1e-9:
			if absf(la[axis]) > half[axis]:
				return 0.0
			continue
		var ta: float = (-half[axis] - la[axis]) / d[axis]
		var tb: float = (half[axis] - la[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return 0.0
	return t1 - t0

## Fraccion del segmento dentro de la esfera de radio r centrada en el origen.
static func _sphere_chord(la: Vector3, lb: Vector3, r: float) -> float:
	var d: Vector3 = lb - la
	var aa: float = d.dot(d)
	if aa < 1e-12:
		return 1.0 if la.length() <= r else 0.0
	var bb: float = 2.0 * la.dot(d)
	var cc: float = la.dot(la) - r * r
	var disc: float = bb * bb - 4.0 * aa * cc
	if disc <= 0.0:
		return 0.0
	var sq: float = sqrt(disc)
	var t0: float = clampf((-bb - sq) / (2.0 * aa), 0.0, 1.0)
	var t1: float = clampf((-bb + sq) / (2.0 * aa), 0.0, 1.0)
	return maxf(0.0, t1 - t0)
