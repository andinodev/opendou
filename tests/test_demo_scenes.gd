class_name TestDemoScenes
extends RefCounted

## Aserciones de las tres demos. Cada una prueba SU tesis, no que la escena arranque.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")

## Las tres demos y el hub. Cada bloque se anade en su propia tarea.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new()
	a.absorb(await run_keel_async(tree))
	a.absorb(await run_monsoon_async(tree))
	return a


## «El monzon»: 200 emisores contra 32 voces fisicas.
static func run_monsoon_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("monsoon_demo")

	# La demo usa el autoload, asi que este test toca estado global: el presupuesto de
	# voces se restaura al liberarla, y eso mismo se comprueba al final.
	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload_manager != null, "el autoload OpenDou existe")
	var budget_before: int = autoload_manager.voice_pool.max_physical_voices

	var MonsoonClass = load("res://scenes/demos/monsoon/monsoon_demo.gd")
	var demo = MonsoonClass.new()
	# Menos emisores que en la escena real: 200 instancias por suite multiplican el
	# tiempo del runner sin cambiar lo que se afirma. El presupuesto es el mismo.
	demo.emitter_count = 120
	demo.physical_voice_budget = 16
	# En headless el bucle corre a maxima velocidad, asi que el tiempo logico avanza
	# muy poco por frame: un trueno de cuatro segundos no llega a terminar en ninguna
	# cantidad razonable de frames. Se acorta para poder afirmar que TERMINA.
	demo.thunder_seconds = 0.25
	tree.root.add_child(demo)
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame

	var manager = demo.event_manager
	a.ok(manager == autoload_manager, "la demo usa el manager autoload, no una copia")
	a.eq(manager.voice_pool.max_physical_voices, 16, "el presupuesto se aplico al pool")

	# Se posteo el campo completo.
	a.gt(float(manager.active_instances.size()), 100.0,
		"hay mas de cien instancias activas")

	# LA TESIS: el conteo fisico NUNCA supera el presupuesto, en ningun frame.
	var max_physical: int = 0
	var saw_virtual := false
	for i in range(40):
		await tree.process_frame
		var phys: int = manager.voice_pool.get_active_physical_count()
		max_physical = maxi(max_physical, phys)
		if manager.voice_pool.get_active_virtual_count(manager.active_instances) > 0:
			saw_virtual = true
	a.lt(float(max_physical), 17.0, "el conteo fisico nunca supero el presupuesto de 16")
	a.gt(float(max_physical), 0.0, "y no es cero: hay voces suenando de verdad")
	a.ok(saw_virtual, "hay instancias virtualizadas, no solo las fisicas")

	# El presupuesto de raycasts de oclusion aguanta con 120 instancias.
	var scheduler = manager.occlusion_scheduler
	a.ok(scheduler != null, "hay planificador de oclusion")
	a.lt(float(scheduler.raycasts_this_frame), float(scheduler.raycasts_per_frame) + 0.5,
		"los raycasts de un frame no superan su presupuesto")

	# El LOD excluye lo lejano de la oclusion fisica: sin esto, 120 emisores competirian
	# por el presupuesto de raycasts aunque esten a 200 m.
	var lod = scheduler.lod_controller
	var near_lod: int = lod.get_lod_level(5.0)
	var far_lod: int = lod.get_lod_level(200.0)
	a.ok(bool(lod.get_lod_features(near_lod).get("enable_physics_occlusion", false)),
		"lo cercano si entra en oclusion fisica")
	a.ok(not bool(lod.get_lod_features(far_lod).get("enable_physics_occlusion", false)),
		"lo lejano no entra en oclusion fisica")

	# active_instances no crece de forma monotona: el trueno entra y sale.
	var baseline: int = manager.active_instances.size()
	for i in range(4):
		demo.strike_thunder()
	a.gt(float(manager.active_instances.size()), float(baseline),
		"los truenos anaden instancias")
	for i in range(2000):
		await tree.process_frame
		if manager.active_instances.size() <= baseline:
			break
	a.lt(float(manager.active_instances.size()), float(baseline) + 1.0,
		"las instancias terminadas se retiran: el conteo vuelve a su linea base")

	# El ambiente SUENA de verdad en su bus.
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(demo.ambience_bus, 2.0),
		"la sonda se engancha al bus de ambiente")
	probe.drain()
	var peak_ambience: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(peak_ambience, 0.0005, "el campo de emisores suena en su bus")
	probe.teardown()

	# EL DUCKING HDR, medido en la ATENUACION que el motor aplica y no en el pico del
	# bus.
	#
	# El pico del bus no sirve aqui: con 120 instancias y 16 voces, el voice stealing
	# rota cada frame que 16 suenan, asi que el pico fluctua por si solo y una
	# comparacion antes/despues no distingue el ducking del ruido de esa rotacion. Lo
	# que se afirma es el valor exacto que _apply_voices() suma al volumen de cada voz.
	# El ducking AUDIBLE con audio real esta probado en run_hdr_ducking_async, con dos
	# voces controladas donde no hay rotacion que lo enmascare.
	var hdr = manager.hdr_engine
	a.ok(hdr != null, "el motor HDR existe")
	var gain_quiet: float = hdr.calculate_voice_gain_db(-14.0)
	var top_quiet: float = hdr.hdr_window_top_db

	demo.strike_thunder()
	# El trueno declara +18 dB de sonoridad y la ventana sube a 200 dB/s, asi que unos
	# pocos frames bastan.
	for i in range(6):
		await tree.process_frame
	var gain_thunder: float = hdr.calculate_voice_gain_db(-14.0)
	var top_thunder: float = hdr.hdr_window_top_db

	a.gt(top_thunder, top_quiet + 1.0, "el trueno sube el techo de la ventana HDR")
	a.lt(gain_thunder, gain_quiet - 1.0,
		"y con la ventana arriba el ambiente recibe menos ganancia: se hunde")

	# La telemetria informa de lo mismo que el test acaba de medir.
	var telemetry: Dictionary = demo.get_telemetry()
	for key in ["instances", "physical", "virtual", "raycasts"]:
		a.ok(telemetry.has(key), "la telemetria informa de '%s'" % key)
	a.eq(int(telemetry["instances"]), manager.active_instances.size(),
		"el conteo de la telemetria coincide con el real")

	# build() idempotente.
	var before: int = demo.get_child_count()
	demo.build()
	a.eq(demo.get_child_count(), before, "build() es idempotente")

	_release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	await tree.process_frame

	# Y el estado global vuelve a como estaba: sin esto, la suite siguiente correria con
	# 16 voces y sus mediciones dependerian del orden de ejecucion.
	a.eq(autoload_manager.voice_pool.max_physical_voices, budget_before,
		"liberar la demo restaura el presupuesto de voces")
	a.eq(autoload_manager.active_instances.size(), 0,
		"y no deja instancias huerfanas de una escena que ya no existe")
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
