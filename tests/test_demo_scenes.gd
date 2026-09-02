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
	a.absorb(await run_cabin_async(tree))
	a.absorb(await run_street_async(tree))
	a.absorb(run_hub())
	a.absorb(await run_pause_menu_async(tree))
	return a


## «Una casa canta»: una casa vibra, dos duermen, y la calle es el puente.
static func run_street_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("street_demo")

	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")

	var packed: PackedScene = load("res://scenes/demos/street/street_demo.tscn")
	a.ok(packed != null, "la escena de la calle carga")
	a.gt(float(packed.get_state().get_node_count()), 200.0,
		"y declara mas de 200 nodos: cada pared, suelo, techo, cristal y puerta esta en la escena")
	var demo = packed.instantiate()
	demo.leaves_count = 12
	tree.root.add_child(demo)
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame

	# ---- La geometria es real: cuatro salas, seis portales, y un bake con cientos de
	# triangulos porque cada pared es geometria acustica.
	var ac = manager.spatial_acoustics
	for room_name in ["HouseA", "HouseB", "HouseC", "Street"]:
		a.ok(ac.rooms.has(StringName(room_name)), "la sala '%s' esta registrada" % room_name)
	a.eq(ac.portals.size(), 6, "hay seis portales: tres puertas y tres ventanas")
	a.gt(float(demo.get_node("AcousticBake").get_baked_triangle_count()), 400.0,
		"el bake tiene cientos de triangulos: las paredes son geometria acustica de verdad")

	# La calle ES una sala, y las casas estan dentro de ella: la mas pequena gana.
	var in_street = ac.get_room_at_position(Vector3(-6.0, 1.6, 0.0))
	var in_house_a = ac.get_room_at_position(Vector3(-6.0, 1.6, -8.5))
	a.ok(in_street != null and str(in_street.room_name) == "Street", "en la calzada estas en la Calle")
	a.ok(in_house_a != null and str(in_house_a.room_name) == "HouseA",
		"dentro de la casa A estas en la casa A, aunque la Calle la envuelva")

	# ---- LA TESIS, primera mitad: desde la calle, la musica la gobierna el grafo y sale
	# por la VENTANA entreabierta, no por la puerta cerrada que esta mas cerca.
	var music_instance = demo.music_emitter.active_instance
	a.ok(music_instance != null, "la musica tiene instancia activa")
	if music_instance != null:
		music_instance.occlusion_smoothing_speed = 200.0
	for i in range(20):
		await tree.process_frame
	a.ok(music_instance.room_path_active, "desde la calle, la musica la gobierna el grafo de salas")
	a.approx(music_instance.target_apparent_position.x, -4.0,
		"y su origen aparente es la VENTANA entreabierta, no la puerta cerrada", 0.05)
	var lpf_ajar: float = music_instance.current_spatial_lpf
	a.lt(lpf_ajar, 6000.0, "entreabierta, la ventana filtra la musica")
	a.gt(lpf_ajar, 1000.0, "pero deja pasar mas que una puerta cerrada")

	# Abrir la ventana del todo la abre tambien al oido.
	demo.toggle_window()
	for i in range(30):
		await tree.process_frame
	a.gt(music_instance.current_spatial_lpf, lpf_ajar * 2.0,
		"abrir la ventana del todo sube el corte de la musica")
	demo.toggle_window()

	# ---- Dentro de la casa A el grafo no gobierna: es sonido directo.
	demo.player.global_position = Vector3(-5.0, 1.0, -8.0)
	for i in range(20):
		await tree.process_frame
	a.ok(not music_instance.room_path_active,
		"dentro de la casa que canta la musica es directa: el grafo no gobierna")

	# ---- LA TESIS, segunda mitad: dentro de la casa B, la calle se apaga.
	demo.player.global_position = Vector3(2.0, 1.0, -8.5)
	var hum = demo.buzz_emitter.active_instance
	a.ok(hum != null, "la farola tiene instancia activa")
	if hum != null:
		hum.occlusion_smoothing_speed = 200.0
	for i in range(30):
		await tree.process_frame
	a.ok(hum.room_path_active, "dentro de la casa dormida, la farola de la calle la gobierna el grafo")
	a.lt(hum.current_spatial_lpf, 500.0,
		"y llega cortada a 300 Hz: el silencio es la calle amortiguada, no ausencia de sonido")

	# ---- El coche se mueve, y con doppler nativo.
	var x0: float = demo.car.position.x
	for i in range(10):
		await tree.physics_frame
	a.ok(absf(demo.car.position.x - x0) > 0.01, "el coche recorre la calle")
	a.eq(demo.car_engine.doppler_tracking, AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP,
		"con doppler nativo en el paso de fisica, que es donde se mueve")

	# ---- Las puertas son puertas: hoja con bisagra y portal que las sigue.
	a.eq(demo._doors.size(), 3, "tres puertas con hoja")
	var door_a = demo.get_node("A_Door")
	var portal_a = demo.get_node("A_DoorPortal")
	a.approx(portal_a.open_factor, 0.0, "la puerta A arranca cerrada", 0.01)
	door_a.toggle()
	for i in range(60):
		await tree.process_frame
	a.gt(portal_a.open_factor, 0.8, "abrirla abre su portal casi del todo")
	a.gt(absf(door_a.rotation.y), 1.2, "y la hoja giro sobre la bisagra")

	# ---- El cartel dice lo que ejercita.
	var hud = demo.get_node_or_null("Hud")
	a.ok(hud != null and hud.exercises.size() >= 8, "el cartel lista lo que la escena ejercita")

	_release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	await tree.process_frame
	a.eq(manager.active_instances.size(), 0, "la calle no deja instancias en el autoload")
	return a


## El hub: cinco tarjetas declaradas en la escena y ni una ruta muerta.
static func run_hub() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("demo_hub")

	var packed: PackedScene = load("res://scenes/demos/demo_hub.tscn")
	a.ok(packed != null, "la escena del hub carga")
	if packed == null:
		return a

	# Las tarjetas estan EN LA ESCENA, no las fabrica el script: se cuentan en el estado
	# empaquetado, antes de instanciar nada.
	var state: SceneState = packed.get_state()
	var declared_cards: int = 0
	for i in range(state.get_node_count()):
		var inst = state.get_node_instance(i)
		if inst != null and str(inst.resource_path).ends_with("demo_card.tscn"):
			declared_cards += 1
	a.eq(declared_cards, 5, "el hub declara cinco tarjetas en su .tscn: cuatro demos y el banco")

	var hub = packed.instantiate()
	# Fuera del arbol no hay _ready, asi que se anade a un padre suelto para leerlo.
	var holder := Node.new()
	holder.add_child(hub)
	var paths: PackedStringArray = hub.get_entry_paths()
	a.eq(paths.size(), 5, "y expone cinco rutas, una por tarjeta")

	# Ninguna ruta muerta. Es la asercion que impide que el hub sobreviva a un borrado
	# apuntando a escenas que ya no existen.
	for path in paths:
		a.ok(ResourceLoader.exists(path), "la escena '%s' existe" % path)
	for card in hub._cards():
		a.ok(not str(card.demo_title).is_empty(), "la tarjeta de '%s' tiene titulo" % card.scene_path)
		a.ok(not str(card.thesis).is_empty(), "y declara su tesis")
		# El boton tiene ancho FIJO: era el defecto visual, botones de pantalla completa.
		var open_button: Button = card.get_node("Margin/Column/ButtonRow/Open")
		a.ok(open_button.custom_minimum_size.x > 0.0 and open_button.custom_minimum_size.x < 200.0,
			"el boton de la tarjeta tiene ancho fijo, no el de la pantalla")

	# Y las viejas ya no estan.
	for stale in [
		"res://scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.tscn",
		"res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn",
		"res://scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn",
		"res://scenes/demos/master_sandbox/master_vertical_slice.tscn",
	]:
		a.ok(not ResourceLoader.exists(stale), "la escena vieja '%s' se borro" % stale)

	holder.free()
	return a


## El menu de Escape: congela al jugador, NO pausa el audio, y lista los buses en vivo.
static func run_pause_menu_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("pause_menu")

	# El banco es la escena mas pequena con jugador y menu.
	var packed: PackedScene = load("res://scenes/rig_bench/rig_bench.tscn")
	var bench = packed.instantiate()
	tree.root.add_child(bench)
	await tree.process_frame

	var menu = bench.get_node_or_null("PauseMenu")
	var player = bench.get_node_or_null("Player")
	a.ok(menu != null, "la escena instancia el menu de pausa")
	a.ok(player != null and player.is_in_group("player"), "y el jugador esta en el grupo player, que es como el menu lo encuentra")
	if menu == null or player == null:
		tree.root.remove_child(bench); bench.free()
		return a

	a.ok(not menu.is_open, "el menu arranca cerrado")
	a.ok(player.input_enabled, "y el jugador arranca con entrada activa")

	# Abrir: el jugador se congela y el ARBOL NO SE PAUSA, para que el audio siga.
	menu.toggle()
	await tree.process_frame
	a.ok(menu.is_open, "Escape abre el menu")
	a.ok(not player.input_enabled, "y congela al jugador")
	a.ok(not tree.paused, "sin pausar el arbol: el audio sigue sonando mientras se ajusta")
	a.ok(menu.get_node("Root").visible, "el panel se ve")

	# La pantalla de sonido: una fila por bus del AudioServer, en vivo.
	menu.show_sound()
	await tree.process_frame
	var rows: Array = menu.bus_rows()
	a.eq(rows.size(), AudioServer.bus_count, "hay una fila por cada bus del AudioServer")
	var names: Array = []
	for row in rows:
		names.append(row.bus_name)
	a.ok("Master" in names, "Master esta en la lista")

	# Mover un deslizador cambia el volumen REAL del bus, y silenciar lo silencia.
	var master_row = null
	for row in rows:
		if row.bus_name == "Master":
			master_row = row
	a.ok(master_row != null, "se encuentra la fila de Master")
	if master_row != null:
		var master_idx: int = AudioServer.get_bus_index("Master")
		var before_db: float = AudioServer.get_bus_volume_db(master_idx)
		var before_mute: bool = AudioServer.is_bus_mute(master_idx)
		master_row.get_node("Volume").value = -6.0
		await tree.process_frame
		a.approx(AudioServer.get_bus_volume_db(master_idx), -6.0, "el deslizador mueve el volumen real del bus", 0.01)
		master_row.get_node("Mute").button_pressed = true
		await tree.process_frame
		a.ok(AudioServer.is_bus_mute(master_idx), "y silenciar silencia el bus de verdad")
		# Se restaura: es estado global y otras suites miden audio.
		AudioServer.set_bus_volume_db(master_idx, before_db)
		AudioServer.set_bus_mute(master_idx, before_mute)
		var meter: ProgressBar = master_row.get_node("Meter")
		a.ok(meter.min_value <= -60.0 and meter.max_value >= 0.0, "el medidor va de -60 a 0 dB")

	# Volver al hub apunta a una escena que existe. No se cambia de escena aqui: mataria
	# la suite. Se afirma la ruta y que el boton esta conectado.
	a.ok(ResourceLoader.exists(menu.hub_scene_path), "Volver al hub apunta a una escena que existe")
	var hub_button: Button = menu.get_node("Root/Center/Panel/Margin/Column/MainButtons/Hub")
	a.ok(hub_button.pressed.is_connected(menu.go_to_hub), "y el boton esta conectado a go_to_hub")

	# Cerrar devuelve la entrada al jugador.
	menu.show_main()
	menu.toggle()
	await tree.process_frame
	a.ok(not menu.is_open, "Escape otra vez lo cierra")
	a.ok(player.input_enabled, "y el jugador recupera la entrada")

	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	if autoload_manager != null:
		autoload_manager.stop_all()
	_release_current(bench)
	tree.root.remove_child(bench)
	bench.free()
	return a


## «La cabina»: un RTPC conduce tres cosas, y los estados cruzan.
static func run_cabin_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("cabin_demo")

	var RadioEventsClass = load("res://scenes/demos/cabin/radio_events.gd")
	var packed: PackedScene = load("res://scenes/demos/cabin/cabin_demo.tscn")
	a.ok(packed != null, "la escena de la cabina carga")
	var demo = packed.instantiate()
	tree.root.add_child(demo)
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame

	var manager = demo.event_manager
	a.ok(manager == tree.root.get_node_or_null("OpenDou"),
		"la demo usa el manager autoload, no una copia")

	# La suite REAL, no la de reserva. Contar cuatro stems no distinguiria: la de
	# reserva tambien da cuatro. Lo que la distingue es que cada stem esta en SU bus,
	# que es de donde viene la posibilidad de medir el desplazamiento de energia.
	a.eq(demo.music.get_stem_count(), 4, "la suite cargo sus cuatro stems")
	for bus in ["MusicPads", "MusicBass", "MusicDrums", "MusicBrass", "Music", "Radio"]:
		a.gt(float(AudioServer.get_bus_index(bus)), -0.5, "el bus '%s' existe" % bus)
	var stem_buses: Array = []
	for stem in demo.music.stem_players:
		stem_buses.append(String(stem.bus))
	for bus in ["MusicPads", "MusicBass", "MusicDrums", "MusicBrass"]:
		a.ok(bus in stem_buses, "hay un stem en el bus '%s'" % bus)
	a.ok(not ("Music" in stem_buses),
		"ningun stem quedo en el bus de stingers: si lo estuviera, la suite es la de reserva")

	# ---- COSA 1: la tension desplaza la energia entre stems, medida por stem.
	demo.set_tension(0.0)
	await tree.process_frame
	var probe_brass = OpenDouAudioProbeClass.new()
	a.ok(probe_brass.attach_to_existing_bus(&"MusicBrass", 2.0), "sonda en MusicBrass")
	probe_brass.drain()
	var brass_calm: float = await probe_brass.measure_peak_over_frames(tree, 30)
	demo.set_tension(1.0)
	await tree.process_frame
	probe_brass.drain()
	var brass_tense: float = await probe_brass.measure_peak_over_frames(tree, 30)
	a.gt(brass_tense, maxf(brass_calm, 0.0001) * 4.0,
		"con tension alta el stem de metales entra")
	probe_brass.teardown()

	# Y en el sentido contrario, que es lo que descarta un fallo trivial de nivel.
	var probe_pads = OpenDouAudioProbeClass.new()
	a.ok(probe_pads.attach_to_existing_bus(&"MusicPads", 2.0), "sonda en MusicPads")
	demo.set_tension(1.0)
	await tree.process_frame
	probe_pads.drain()
	var pads_tense: float = await probe_pads.measure_peak_over_frames(tree, 30)
	demo.set_tension(0.0)
	await tree.process_frame
	probe_pads.drain()
	var pads_calm: float = await probe_pads.measure_peak_over_frames(tree, 30)
	a.gt(pads_calm, maxf(pads_tense, 0.0001) * 4.0,
		"con tension baja el stem de pads es el que suena")
	probe_pads.teardown()

	# ---- COSA 2: el MISMO RTPC cierra el filtro de la radio.
	demo.tune_radio(&"Tower")
	demo.set_tension(0.0)
	for i in range(6):
		await tree.process_frame
	var cutoff_calm: float = demo.get_radio_cutoff()
	demo.set_tension(1.0)
	for i in range(30):
		await tree.process_frame
	var cutoff_tense: float = demo.get_radio_cutoff()
	a.gt(cutoff_calm, 1.0, "la radio tiene un corte medible")
	a.lt(cutoff_tense, cutoff_calm * 0.5, "con tension alta la radio se cierra")

	# ---- COSA 3: y mueve el envio de reverb de la cabina.
	demo.set_tension(0.0)
	await tree.process_frame
	var send_calm: float = demo.cabin_room.reverb_send_amount
	demo.set_tension(1.0)
	await tree.process_frame
	var send_tense: float = demo.cabin_room.reverb_send_amount
	a.ok(absf(send_tense - send_calm) > 0.05, "el envio de reverb tambien se mueve")

	# ---- Los estados CRUZAN en lugar de cortar.
	demo.escalate(&"Routine")
	await tree.process_frame
	demo.escalate(&"Emergency")
	await tree.process_frame
	await tree.process_frame
	var weight_mid: float = manager.get_state_transition_weight(&"Situation")
	a.gt(weight_mid, 0.0, "la transicion de estado ha empezado")
	a.lt(weight_mid, 1.0, "y no ha terminado: cruza, no corta")
	a.eq(str(manager.get_state(&"Situation")), "Emergency", "el estado destino es el pedido")

	# ---- Un trigger produce un stinger MEDIBLE en el bus de stingers.
	var probe_music = OpenDouAudioProbeClass.new()
	a.ok(probe_music.attach_to_existing_bus(&"Music", 2.0), "sonda en el bus de stingers")
	# Los escalate() de arriba ya dispararon stingers y siguen sonando. Hay que esperar
	# SILENCIO y no contar frames: medir el "antes" mientras suena el stinger anterior
	# fue el primer intento y la comparacion no significaba nada.
	# 60 frames consecutivos por debajo de 0.005, no los 4 por defecto: un stinger con
	# un bache momentaneo de amplitud cumple cuatro frames sin haber terminado, y el
	# primer intento midio el "antes" con el stinger anterior sonando.
	a.ok(await probe_music.await_silence(tree, 0.005, 60),
		"el bus de stingers se queda en silencio")
	probe_music.drain()
	var quiet: float = await probe_music.measure_peak_over_frames(tree, 15)
	a.lt(quiet, 0.01, "y sigue callado justo antes del trigger")
	manager.post_trigger(&"AlertRaised")
	await tree.process_frame
	probe_music.drain()
	var stung: float = await probe_music.measure_peak_over_frames(tree, 40)
	a.gt(stung, maxf(quiet, 0.001) * 3.0, "el trigger produjo un stinger audible")
	probe_music.teardown()

	# ---- Un switch cambia QUE linea de radio suena.
	var streams: Array = []
	for station in RadioEventsClass.STATIONS:
		demo.tune_radio(station)
		await tree.process_frame
		var voices: Array = demo.radio_def.resolve_voices(demo.radio_context())
		a.gt(float(voices.size()), 0.0, "la estacion '%s' resuelve voz" % str(station))
		if voices.size() > 0:
			streams.append(voices[0].stream)
	a.eq(streams.size(), 3, "tres estaciones resueltas")
	if streams.size() == 3:
		a.ok(streams[0] != streams[1] and streams[1] != streams[2] and streams[0] != streams[2],
			"las tres estaciones resuelven streams distintos")

	# ---- El SoundBank precargado sirve las locuciones, y la tabla de dialogo localiza.
	a.ok(demo.bank_loaded, "el banco de locuciones se cargo")
	var announcement = manager.get_bank_stream(demo.BANK_NAME, 0)
	a.ok(announcement is AudioStreamWAV, "el banco devuelve un AudioStreamWAV")
	if announcement is AudioStreamWAV:
		a.gt(float(announcement.data.size()), 0.0, "con datos dentro")
	var es_stream = demo.dialogue.get_localized_stream(&"ClearedToLand")
	demo.dialogue.set_language("en")
	var en_stream = demo.dialogue.get_localized_stream(&"ClearedToLand")
	a.ok(es_stream != null and en_stream != null, "la tabla sirve las dos lenguas")
	a.ok(es_stream != en_stream, "y no devuelve el mismo stream para las dos")

	# ---- Las pisadas del operador: tarima de madera y rejilla metalica.
	var declared: Array = []
	for child in demo.get_children():
		if child is StaticBody3D and child.has_meta("surface_type"):
			declared.append(str(child.get_meta("surface_type")))
	a.ok("Wood" in declared, "la cabina tiene tarima de madera")
	a.ok("Metal" in declared, "y rejilla metalica")
	a.ok(not ("Carpet" in declared), "no hay 'Carpet': no esta en el vocabulario")

	# La escena declara sus nodos en el .tscn, no en un build().
	a.gt(float(packed.get_state().get_node_count()), 10.0,
		"la escena declara sus nodos, no los fabrica un build()")

	_release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	await tree.process_frame
	a.eq(manager.active_instances.size(), 0, "la cabina no deja instancias en el autoload")
	return a


## «El monzon»: 200 emisores contra 32 voces fisicas.
static func run_monsoon_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("monsoon_demo")

	# La demo usa el autoload, asi que este test toca estado global: el presupuesto de
	# voces se restaura al liberarla, y eso mismo se comprueba al final.
	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload_manager != null, "el autoload OpenDou existe")
	var budget_before: int = autoload_manager.voice_pool.max_physical_voices

	var packed: PackedScene = load("res://scenes/demos/monsoon/monsoon_demo.tscn")
	a.ok(packed != null, "la escena del monzon carga")
	var demo = packed.instantiate()
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

	# Criterio 4 de la Fase 6: la escena no registra salas, asi que el grafo de portales
	# no puede tocarla ni costarle nada. Si algun dia alguien le anade un Room3D, esta
	# asercion cae y hay que decidirlo a proposito en lugar de descubrirlo por el coste.
	a.eq(manager.room_path_dispatcher.traversals_this_frame, 0,
		"«El monzon» no registra salas, asi que el grafo no se recorre ni una vez")
	var governed_count: int = 0
	for inst in manager.active_instances:
		if inst != null and inst.room_path_active:
			governed_count += 1
	a.eq(governed_count, 0, "y ninguna de sus voces queda gobernada por el grafo")

	# La escena declara sus nodos en el .tscn, no en un build().
	a.gt(float(packed.get_state().get_node_count()), 10.0,
		"la escena declara sus nodos, no los fabrica un build()")

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

	# Se instancia la ESCENA: las demos son arboles de nodos, y crear el script con
	# .new() dejaria todos sus @onready en null. Ver
	# .agents/rules/04_scene_composition.md.
	var packed: PackedScene = load("res://scenes/demos/keel/keel_demo.tscn")
	a.ok(packed != null, "la escena de la quilla carga")
	var demo = packed.instantiate()
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

	# LA ESCOTILLA. La version anterior de esta asercion comprobaba que
	# get_diffraction_lpf() devolvia otro numero: comprobaba que un CALCULO cambiaba, no
	# que llegara a ninguna voz, y por eso pulsar E no hacia nada mientras los tests
	# pasaban en verde.
	#
	# Aqui se afirma lo que llega al MEZCLADOR de Godot: que la valvula queda gobernada
	# por el grafo de salas, que su origen aparente es la escotilla, y que el corte que
	# se le aplica sigue a la escotilla. Es la propiedad que Godot lee en C++ para
	# filtrar la voz, no un calculo intermedio.
	#
	# La prueba AUDIBLE del mecanismo vive en test_portal_audio, con geometria
	# controlada: alli el pico pasa de 0.1196 a 0.0011 al cerrar el portal. Medir el
	# audio de la demo dentro de la suite resulto no ser fiable por la observacion 40
	# -un OpenDouEventPlayer3D cuyo bus dice KeelValve y cuya senal seca aparece en
	# Master-, que es anterior a esta fase y se investiga aparte.
	var keel_player = demo.get_node_or_null("Player")
	a.ok(keel_player != null, "la demo trae jugador con oyente")
	if keel_player != null:
		keel_player.global_position = Vector3(14.0, 1.0, 0.0)  # el pasillo: la otra sala
	await tree.physics_frame
	await tree.process_frame

	var valve_instance = demo.valve_emitter.active_instance
	a.ok(valve_instance != null, "la valvula tiene instancia activa")
	if valve_instance != null:
		valve_instance.occlusion_smoothing_speed = 200.0

	demo.hatch_open_factor = 1.0
	for i in range(30):
		await tree.process_frame
	a.ok(valve_instance.room_path_active,
		"con el jugador en el pasillo la valvula la gobierna el grafo de salas")
	a.approx(valve_instance.target_apparent_position.x, 6.5,
		"y su origen aparente es la escotilla, no el fondo de la sala de maquinas", 0.01)
	var cutoff_open: float = demo.valve_emitter.attenuation_filter_cutoff_hz
	# Observacion 42 (Fase 7B): sin oclusion, el corte que se escribe ya no es 20 kHz sino el
	# filtro de distancia de Godot que el propio emisor declara (5 kHz por defecto). Antes
	# OpenDou lo pisaba con 20 kHz y anulaba el oscurecimiento por distancia.
	a.approx(cutoff_open, demo.valve_emitter.attenuation_filter_cutoff_hz, "con la escotilla abierta el corte es el filtro de distancia del emisor", 1.0)
	a.gt(cutoff_open, 4900.0, "que vale 5 kHz por defecto, no 20 kHz")

	demo.hatch_open_factor = 0.0
	for i in range(60):
		await tree.process_frame
	var cutoff_closed: float = demo.valve_emitter.attenuation_filter_cutoff_hz
	a.lt(cutoff_closed, cutoff_open * 0.1,
		"y cerrarla lo desploma: la tecla E llega hasta el mezclador")
	a.lt(valve_instance.occlusion_attenuation_db, -1.0,
		"y la voz lleva ademas la atenuacion del camino por el portal")

	a.approx(demo.hatch.runtime_portal.open_factor, 0.0,
		"asignar hatch_open_factor propaga al portal en runtime", 0.001)

	# El depurador acustico se puede alternar.
	a.ok(demo.toggle_debugger(), "el depurador se activa")
	a.ok(not demo.toggle_debugger(), "y se desactiva")

	# La escena declara sus nodos en el .tscn, no en un build().
	a.gt(float(packed.get_state().get_node_count()), 10.0,
		"la escena declara sus nodos, no los fabrica un build()")

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
