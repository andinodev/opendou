class_name TestDemoScenes
extends RefCounted

## Aserciones de las tres demos. Cada una prueba SU tesis, no que la escena arranque.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")

## Las tres demos y el hub. Cada bloque se anade en su propia tarea.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new()
	a.absorb(await run_keel_async(tree))
	return a


## «Bajo la quilla»: el mismo emisor cambia de caracter solo por geometria.
static func run_keel_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("keel_demo")

	# La demo usa el autoload -sus nodos declarativos lo resuelven solos-, asi que la
	# suite mide contra el mismo y limpia al salir.
	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")

	var KeelClass = load("res://scenes/demos/keel/keel_demo.gd")
	var demo = KeelClass.new()
	tree.root.add_child(demo)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	# Los tres recintos existen y tienen bus de reverb propio por perfil.
	a.eq(demo.rooms.size(), 3, "la demo tiene tres recintos")
	for room_name in demo.rooms:
		var room = demo.rooms[room_name]
		var bus: String = String(room.get_assigned_reverb_bus())
		a.ok(not bus.is_empty(), "el recinto '%s' tiene bus de reverb" % str(room_name))
		a.ok(bus != "Master", "el bus de '%s' no quedo coaccionado a Master" % str(room_name))

	# La sala de maquinas (Metal, RT60 alto) y la bahia (Water, RT60 bajo) no pueden
	# compartir bus: si lo hicieran, el escalonado por RT60 no estaria funcionando.
	var engine_bus: String = String(demo.rooms[&"EngineRoom"].get_assigned_reverb_bus())
	var bay_bus: String = String(demo.rooms[&"FloodedBay"].get_assigned_reverb_bus())
	a.ok(engine_bus != bay_bus, "metal y agua caen en escalones de RT60 distintos")

	# El bake encontro geometria. Si los mamparos se hubieran anadido al grupo como
	# cuerpos en lugar de como mallas, esto seria cero y nada avisaria.
	var bake = demo.get_node_or_null("AcousticBake")
	a.ok(bake != null, "la demo tiene bake de geometria acustica")
	if bake != null:
		a.gt(float(bake.get_baked_triangle_count()), 0.0,
			"el bake encontro triangulos en los mamparos")

	# LA TESIS: el mismo emisor, sin tocarlo, produce energia en el bus de reverb de su
	# sala y no en el de las otras.
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(StringName(engine_bus), 2.0),
		"la sonda se engancha al bus de la sala de maquinas")
	probe.drain()
	var peak_engine: float = await probe.measure_peak_over_frames(tree, 50)
	a.gt(peak_engine, 0.001, "la valvula alimenta el reverb de la sala de maquinas")
	probe.teardown()

	var probe_bay = OpenDouAudioProbeClass.new()
	a.ok(probe_bay.attach_to_existing_bus(StringName(bay_bus), 2.0),
		"la sonda se engancha al bus de la bahia")
	probe_bay.drain()
	var peak_bay: float = await probe_bay.measure_peak_over_frames(tree, 50)
	a.lt(peak_bay, peak_engine * 0.5,
		"la valvula NO alimenta el reverb de una sala en la que no esta")
	probe_bay.teardown()

	# Cerrar la escotilla baja el corte de difraccion del camino directo.
	demo.hatch_open_factor = 1.0
	var lpf_open: float = demo.hatch.get_diffraction_lpf()
	demo.hatch_open_factor = 0.05
	var lpf_closed: float = demo.hatch.get_diffraction_lpf()
	a.lt(lpf_closed, lpf_open * 0.5, "cerrar la escotilla baja el corte de difraccion")
	a.approx(demo.hatch.runtime_portal.open_factor, 0.05,
		"asignar hatch_open_factor propaga al portal en runtime", 0.001)

	# El depurador acustico se puede alternar.
	a.ok(demo.toggle_debugger(), "el depurador se activa")
	a.ok(not demo.toggle_debugger(), "y se desactiva")

	# build() idempotente.
	var before: int = demo.get_child_count()
	demo.build()
	a.eq(demo.get_child_count(), before, "build() es idempotente")

	_release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	await tree.process_frame
	if manager != null:
		a.eq(manager.active_instances.size(), 0, "la suite no deja instancias en el autoload")
	return a


## Suelta camaras y oyentes antes de liberar la escena: el viewport los sigue
## referenciando y cada uno seria una fuga.
static func _release_current(node: Node) -> void:
	if node is Camera3D and node.is_current():
		node.clear_current()
	elif node is AudioListener3D and node.is_current():
		node.clear_current()
	for child in node.get_children():
		_release_current(child)
