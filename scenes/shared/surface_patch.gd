class_name SurfacePatch
extends RefCounted

## Crea suelos con su material acustico declarado en la metadata.
##
## La clave es `surface_type` porque es la que leen los DOS sistemas:
## SpatialAcousticsManager.detect_surface_at() la busca para las pisadas, y
## AcousticReflectorEngine la acepta como alternativa a acoustic_material para las
## reflexiones. El suelo dice lo que es una vez.

## Los ocho nombres que entienden a la vez las pisadas y el registro acustico.
##
## create_footstep() acepta ademas Grass, Mud y Tile, pero el registro acustico no
## los conoce: usarlos daria pisadas de hierba con acustica de hormigon.
const SURFACES: Array[StringName] = [
	&"Concrete", &"Stone", &"Metal", &"Glass",
	&"Wood", &"Foliage", &"Water", &"Asphalt",
]

## Color por superficie, para que el suelo se VEA de que es. Solo presentacion.
const SURFACE_COLORS: Dictionary = {
	&"Concrete": Color(0.55, 0.55, 0.53),
	&"Stone": Color(0.45, 0.43, 0.40),
	&"Metal": Color(0.62, 0.66, 0.72),
	&"Glass": Color(0.55, 0.75, 0.80),
	&"Wood": Color(0.52, 0.36, 0.20),
	&"Foliage": Color(0.24, 0.44, 0.22),
	&"Water": Color(0.16, 0.35, 0.52),
	&"Asphalt": Color(0.20, 0.20, 0.22),
}

## Cuerpo estatico con forma de caja, malla visible y su superficie declarada.
##
## La malla se llama "Mesh" y no es decorativa: OpenDouAcousticGeometryBake recolecta
## MeshInstance3D, no cuerpos, asi que sin ella un parche no puede formar parte del
## bake. Ver mark_as_acoustic_obstacle().
static func make(surface: StringName, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Patch_%s" % str(surface)
	body.position = position
	body.set_meta("surface_type", surface)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = SURFACE_COLORS.get(surface, Color(0.5, 0.5, 0.5))
	mesh.material_override = material
	body.add_child(mesh)

	return body

## Marca un parche como geometria acustica para el bake.
##
## Anade al GRUPO la malla hija, no el cuerpo. _collect_group_meshes() exige que el
## nodo del grupo sea el propio MeshInstance3D: un StaticBody3D en el grupo produce un
## bake de cero triangulos sin ningun aviso.
static func mark_as_acoustic_obstacle(body: StaticBody3D, group: StringName = &"AcousticObstacle") -> void:
	var mesh := body.get_node_or_null("Mesh")
	if mesh != null:
		mesh.add_to_group(group)
