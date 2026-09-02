class_name OpenDouTriangleBVH
extends RefCounted

## Arbol de cajas por mediana sobre triangulos (Fase 11): punto mas cercano sobre la
## superficie de una malla, con poda por distancia a la caja. Hojas de hasta 8 triangulos.

const LEAF_SIZE: int = 8

var _faces: PackedVector3Array = PackedVector3Array()
var _centroids: PackedVector3Array = PackedVector3Array()
var _order: PackedInt32Array = PackedInt32Array()   # indices de triangulo, reordenados
var _node_aabb: Array = []            # AABB por nodo
var _node_left: PackedInt32Array = PackedInt32Array()
var _node_right: PackedInt32Array = PackedInt32Array()
var _node_start: PackedInt32Array = PackedInt32Array()
var _node_count: PackedInt32Array = PackedInt32Array()

func triangle_count() -> int:
	return _faces.size() / 3

func build(faces: PackedVector3Array) -> void:
	_faces = faces
	var n: int = faces.size() / 3
	_centroids.resize(n)
	_order.resize(n)
	for i in range(n):
		_centroids[i] = (faces[3 * i] + faces[3 * i + 1] + faces[3 * i + 2]) / 3.0
		_order[i] = i
	_node_aabb.clear()
	_node_left = PackedInt32Array()
	_node_right = PackedInt32Array()
	_node_start = PackedInt32Array()
	_node_count = PackedInt32Array()
	if n > 0:
		_build_node(0, n)

func _tri_aabb(t: int) -> AABB:
	var b := AABB(_faces[3 * t], Vector3.ZERO)
	b = b.expand(_faces[3 * t + 1])
	return b.expand(_faces[3 * t + 2])

## Construye el nodo del rango [start, start+count) de _order y devuelve su indice.
func _build_node(start: int, count: int) -> int:
	var box: AABB = _tri_aabb(_order[start])
	for i in range(start + 1, start + count):
		box = box.merge(_tri_aabb(_order[i]))
	var idx: int = _node_aabb.size()
	_node_aabb.append(box)
	_node_left.append(-1)
	_node_right.append(-1)
	_node_start.append(start)
	_node_count.append(count)
	if count <= LEAF_SIZE:
		return idx
	# Eje mas largo y mediana de centroides: pares [coordenada, triangulo] con sort() nativo.
	var axis: int = box.get_longest_axis_index()
	var pairs: Array = []
	pairs.resize(count)
	for i in range(count):
		var t: int = _order[start + i]
		pairs[i] = [_centroids[t][axis], t]
	pairs.sort()
	for i in range(count):
		_order[start + i] = pairs[i][1]
	var half: int = count / 2
	var left: int = _build_node(start, half)
	var right: int = _build_node(start + half, count - half)
	_node_left[idx] = left
	_node_right[idx] = right
	return idx

## Punto mas cercano de la superficie a p.
func closest_point(p: Vector3) -> Vector3:
	if _node_aabb.is_empty():
		return p
	var best: Array = [INF, p]
	_query(0, p, best)
	return best[1]

func _query(node: int, p: Vector3, best: Array) -> void:
	if _box_dist2(_node_aabb[node], p) >= best[0]:
		return
	if _node_left[node] < 0:
		var start: int = _node_start[node]
		for i in range(start, start + _node_count[node]):
			var t: int = _order[i]
			var c: Vector3 = closest_point_on_triangle(p, _faces[3 * t], _faces[3 * t + 1], _faces[3 * t + 2])
			var d: float = c.distance_squared_to(p)
			if d < best[0]:
				best[0] = d
				best[1] = c
		return
	# Primero el hijo mas cercano: poda mas.
	var l: int = _node_left[node]
	var r: int = _node_right[node]
	if _box_dist2(_node_aabb[l], p) <= _box_dist2(_node_aabb[r], p):
		_query(l, p, best)
		_query(r, p, best)
	else:
		_query(r, p, best)
		_query(l, p, best)

static func _box_dist2(box: AABB, p: Vector3) -> float:
	var e: Vector3 = box.end
	var c := Vector3(clampf(p.x, box.position.x, e.x), clampf(p.y, box.position.y, e.y), clampf(p.z, box.position.z, e.z))
	return c.distance_squared_to(p)

## Punto mas cercano a p sobre el triangulo abc (Ericson, Real-Time Collision Detection 5.1.5).
static func closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
