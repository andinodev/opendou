class_name OpenDouTransformUtils
extends RefCounted

## Utilidades de transform para los nodos espaciales de OpenDou.
##
## Existe porque `_get_world_position_fallback()` estaba duplicado en tres
## archivos (room, portal y multi-position) y en los tres sumaba los `position`
## de los nodos padres ignorando rotacion y escala: un nodo bajo un padre rotado
## 90 grados reportaba una posicion mundial equivocada, y con ella limites
## acusticos equivocados.

## Transform mundial de un Node3D, tambien cuando esta fuera del arbol.
##
## Dentro del arbol delega en global_transform. Fuera, compone los transform de
## la jerarquia de verdad en lugar de sumar posiciones.
static func world_transform_of(node: Node3D) -> Transform3D:
	if node == null:
		return Transform3D()
	if node.is_inside_tree():
		return node.global_transform
	var xform: Transform3D = node.transform
	var cur: Node = node.get_parent()
	while cur != null and cur is Node3D:
		xform = (cur as Node3D).transform * xform
		cur = cur.get_parent()
	return xform

## Posicion mundial de un Node3D, tambien fuera del arbol.
static func world_position_of(node: Node3D) -> Vector3:
	return world_transform_of(node).origin

## AABB que envuelve las ocho esquinas de una caja local tras aplicarle un
## transform.
##
## Un AABB no puede representar exactamente una caja rotada, asi que el resultado
## es conservador: mas grande que la caja real. Es la unica opcion mientras
## AudioRoom guarde un AABB y no un Transform3D.
static func enclosing_aabb(xform: Transform3D, box_size: Vector3) -> AABB:
	var half: Vector3 = box_size * 0.5
	var result := AABB()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector3 = xform * Vector3(half.x * sx, half.y * sy, half.z * sz)
				if first:
					result = AABB(corner, Vector3.ZERO)
					first = false
				else:
					result = result.expand(corner)
	return result
