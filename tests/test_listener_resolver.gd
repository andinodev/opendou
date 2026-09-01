class_name TestListenerResolver
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ListenerResolverClass = preload("res://addons/opendou/runtime/listener_resolver.gd")

func run_all_async(tree: SceneTree):
	var a := OpenDouAssertClass.new("listener_resolver")
	var r = ListenerResolverClass.new()

	# Sin viewport ni override no hay oyente, y se dice explicitamente en lugar de
	# devolver el origen del mundo, que era el error original.
	a.eq(r.resolve(null), false, "sin fuentes no resuelve")
	a.eq(r.source, &"none", "la fuente se reporta como none")

	# La Camera3D activa es el oyente por defecto, igual que en Godot.
	var cam := Camera3D.new()
	cam.position = Vector3(5.0, 2.0, -3.0)
	tree.root.add_child(cam)
	cam.make_current()
	await tree.process_frame
	a.eq(r.resolve(tree.root), true, "resuelve con camara activa")
	a.eq(r.source, &"camera_3d", "la fuente es la camara")
	a.approx(r.position.x, 5.0, "toma la X de la camara", 0.001)

	# Un AudioListener3D activo tiene prioridad sobre la camara.
	var listener := AudioListener3D.new()
	listener.position = Vector3(-9.0, 1.0, 0.0)
	tree.root.add_child(listener)
	listener.make_current()
	await tree.process_frame
	a.eq(r.resolve(tree.root), true, "resuelve con AudioListener3D")
	a.eq(r.source, &"audio_listener_3d", "el AudioListener3D gana a la camara")
	a.approx(r.position.x, -9.0, "toma la X del AudioListener3D", 0.001)

	# El override explicito gana a todo.
	r.set_listener_position(Vector3(100.0, 0.0, 0.0))
	a.eq(r.resolve(tree.root), true, "resuelve con override de posicion")
	a.eq(r.source, &"override_position", "el override tiene prioridad maxima")
	a.approx(r.position.x, 100.0, "toma la X del override", 0.001)

	# Un nodo como oyente explicito.
	var rig := Node3D.new()
	rig.position = Vector3(0.0, 0.0, 42.0)
	tree.root.add_child(rig)
	await tree.process_frame
	r.set_listener_node(rig)
	a.eq(r.resolve(tree.root), true, "resuelve con nodo override")
	a.eq(r.source, &"override_node", "la fuente es el nodo override")
	a.approx(r.position.z, 42.0, "toma la Z del nodo override", 0.001)

	r.clear_override()
	a.eq(r.resolve(tree.root), true, "tras limpiar vuelve a la regla de Godot")
	a.eq(r.source, &"audio_listener_3d", "vuelve al AudioListener3D")

	# Los nodos estan en el arbol y han sido make_current(): sacarlos del arbol
	# antes de liberarlos evita que el viewport siga referenciandolos.
	for n in [rig, listener, cam]:
		tree.root.remove_child(n)
		n.free()
	await tree.process_frame
	return a
