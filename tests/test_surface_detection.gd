class_name TestSurfaceDetection
extends RefCounted

## La deteccion de superficie y la conexion de AnimationSync con OpenDou.
##
## Observaciones 25, 27 y 28. Las tres viven en opendou_animation_sync.gd y la suite
## que ya cubria ese nodo no podia detectar ninguna: instanciaba el nodo fuera del
## arbol y no afirmaba nada.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("surface_detection")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)

	# Tres parches contiguos, TODOS fuera de cualquier Room3D: si la deteccion
	# funciona solo por floor_surface de la sala, este test no puede pasar.
	var root := Node3D.new()
	tree.root.add_child(root)
	root.add_child(SurfacePatchClass.make(&"Concrete", Vector3(4, 1, 4), Vector3(0, -0.5, 0)))
	root.add_child(SurfacePatchClass.make(&"Metal", Vector3(4, 1, 4), Vector3(6, -0.5, 0)))
	root.add_child(SurfacePatchClass.make(&"Water", Vector3(4, 1, 4), Vector3(12, -0.5, 0)))
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	var world := root.get_world_3d()

	# detect_surface_at CON mundo lee la metadata.
	a.eq(manager.spatial_acoustics.detect_surface_at(Vector3(0, 0.2, 0), world), &"Concrete",
		"sobre el parche de hormigon detecta Concrete")
	a.eq(manager.spatial_acoustics.detect_surface_at(Vector3(6, 0.2, 0), world), &"Metal",
		"sobre el parche de metal detecta Metal")
	a.eq(manager.spatial_acoustics.detect_surface_at(Vector3(12, 0.2, 0), world), &"Water",
		"sobre el parche de agua detecta Water")

	# Sin nada debajo, cae al ultimo recurso.
	a.eq(manager.spatial_acoustics.detect_surface_at(Vector3(100, 0.2, 0), world), &"Concrete",
		"sin suelo debajo devuelve Concrete")

	# Observacion 28: un AnimationSync dentro del arbol resuelve el autoload, no una
	# copia huerfana. Sin esto, set_switch iba a un manager que nadie lee.
	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload_manager != null, "el autoload OpenDou existe")
	var wired := Node3D.new()
	tree.root.add_child(wired)
	var wired_sync = AnimationSyncClass.new()
	wired.add_child(wired_sync)
	await tree.process_frame
	a.ok(wired_sync.get_event_manager() == autoload_manager,
		"un AnimationSync en el arbol resuelve el autoload")
	tree.root.remove_child(wired)
	wired.free()

	# Y lo que de verdad importa: AnimationSync tiene que fijar el switch correcto.
	# Antes invocaba detect_surface_at sin el mundo, asi que nunca raycasteaba y los
	# tres parches daban el mismo switch.
	var walker := Node3D.new()
	root.add_child(walker)
	var sync = AnimationSyncClass.new()
	walker.add_child(sync)
	# DESPUES de add_child: _ready() resuelve el manager, asi que fijarlo antes se
	# perderia. Se fija a mano para medir contra el manager de este test y no contra el
	# autoload, que otras suites comparten.
	sync.set_event_manager(manager)
	await tree.process_frame

	walker.global_position = Vector3(6, 0.2, 0)
	await tree.physics_frame
	sync.trigger_footstep(0)
	a.eq(manager.get_switch(&"SurfaceType"), &"Metal", "una pisada sobre metal fija el switch Metal")

	walker.global_position = Vector3(12, 0.2, 0)
	await tree.physics_frame
	sync.trigger_footstep(0)
	a.eq(manager.get_switch(&"SurfaceType"), &"Water", "una pisada sobre agua fija el switch Water")

	# Observacion 27: AnimationSync SIN emisor atado tiene que poder postear.
	var lone_parent := Node3D.new()
	lone_parent.position = Vector3(3.0, 1.0, -2.0)
	tree.root.add_child(lone_parent)
	var lone_sync = AnimationSyncClass.new()
	lone_parent.add_child(lone_sync)
	await tree.process_frame
	lone_sync.set_event_manager(manager)

	var lone_def = AudioEventDefClass.new(&"LoneBeep", AudioSynthesizerClass.create_tone(440.0, 0.2, 0.5))
	lone_def.stream_length = 0.2
	manager.register_event_definition(lone_def)

	var before_count: int = manager.active_instances.size()
	lone_sync.trigger_audio_event(&"LoneBeep")
	a.eq(manager.active_instances.size(), before_count + 1,
		"un AnimationSync sin emisor postea su evento")
	var posted = manager.active_instances[manager.active_instances.size() - 1]
	a.approx(posted.emitter_position.x, 3.0, "y la instancia lleva la posicion del padre", 0.01)
	a.ok(posted.has_spatial_position, "marcada como espacial")

	tree.root.remove_child(lone_parent)
	lone_parent.free()

	manager.stop_all()
	tree.root.remove_child(root)
	root.free()
	tree.root.remove_child(manager)
	manager.free()
	return a
