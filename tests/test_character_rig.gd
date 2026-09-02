class_name TestCharacterRig
extends RefCounted

## El rig de personaje, el oyente y el evento unico de pisada.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const CharacterAudioRigClass = preload("res://scenes/shared/character_audio_rig.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("character_rig")

	# Un manager propio de la suite, no el autoload: asi las instancias de otras suites
	# no interfieren y este test no deja estado global tocado. El rig se ata a el
	# explicitamente con bind_event_manager(), porque por defecto los nodos
	# declarativos resuelven el autoload en _get_manager().
	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# UN solo evento de pisada, con switch container.
	var def = FootstepEventsClass.register(manager)
	a.ok(def != null, "el evento de pisada se registra")
	a.ok(def.root_container != null, "el evento tiene contenedor raiz")
	a.eq(manager.event_registry.size(), 1, "un solo evento, no ocho por superficie")
	for surface in SurfacePatchClass.SURFACES:
		a.ok(not manager.event_registry.has(StringName("Footstep_%s" % str(surface))),
			"no hay evento por nombre para %s" % str(surface))

	# El jugador lleva oyente; el NPC no. Con dos oyentes activos el resolutor de la
	# Fase 1 tendria dos candidatos y el resultado dependeria del orden del arbol.
	# Se instancian las ESCENAS: el jugador y el NPC son arboles de nodos, y crear sus
	# scripts con .new() dejaria camara, oyente y rig en null.
	# Ver .agents/rules/04_scene_composition.md.
	var player_packed: PackedScene = load("res://scenes/shared/player.tscn")
	a.ok(player_packed != null, "la escena del jugador carga")
	var player = player_packed.instantiate()
	tree.root.add_child(player)
	await tree.process_frame
	a.ok(player.listener != null, "el jugador expone un AudioListener3D")

	var npc_packed: PackedScene = load("res://scenes/shared/npc.tscn")
	a.ok(npc_packed != null, "la escena del NPC carga")
	var npc = npc_packed.instantiate()
	tree.root.add_child(npc)
	await tree.process_frame
	var npc_has_listener := false
	for child in npc.get_children():
		if child is AudioListener3D:
			npc_has_listener = true
	a.ok(not npc_has_listener, "el NPC no lleva oyente")

	# Ambos llevan el MISMO rig: es el punto de la composicion.
	a.ok(player.get_node_or_null("CharacterAudioRig") != null, "el jugador lleva rig")
	a.ok(npc.get_node_or_null("CharacterAudioRig") != null, "el NPC lleva rig")

	# El paso se dispara por distancia acumulada.
	var rig = player.get_node("CharacterAudioRig") as CharacterAudioRig
	rig.bind_event_manager(manager)
	a.ok(rig.animation_sync.get_event_manager() == manager,
		"el rig quedo atado al manager de la suite")

	var steps_before: int = rig.steps_taken
	rig.notify_moved(rig.stride_meters * 2.1)
	a.eq(rig.steps_taken, steps_before + 2, "dos zancadas producen dos pasos")

	# Y la asercion que importa: dos superficies distintas suenan DISTINTO.
	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	def.target_bus = probe.bus_name()

	var patches := Node3D.new()
	tree.root.add_child(patches)
	patches.add_child(SurfacePatchClass.make(&"Concrete", Vector3(4, 1, 4), Vector3(0, -0.5, 0)))
	patches.add_child(SurfacePatchClass.make(&"Metal", Vector3(4, 1, 4), Vector3(8, -0.5, 0)))
	await tree.physics_frame
	await tree.physics_frame

	# Los streams de cada rama del switch container, para saber DE DONDE salio la voz.
	#
	# Comparar los picos de las dos pisadas no serviria: el random container aplica
	# jitter de tono y volumen, asi que dos pisadas cualesquiera dan picos distintos
	# aunque el material sea el mismo. Se comprobo con una mutacion -todas las ramas
	# con el mismo material- y la comparacion de picos seguia pasando. Lo que hay que
	# afirmar es de que rama salio el stream.
	var branch_streams: Dictionary = _branch_streams(def.root_container)
	a.eq(branch_streams.size(), SurfacePatchClass.SURFACES.size(),
		"el switch container tiene una rama por superficie")

	var peak_concrete: float = await _step_and_measure(tree, player, probe, Vector3(0, 0.2, 0))
	var stream_concrete = _current_stream(manager, player)
	a.gt(peak_concrete, 0.001, "la pisada sobre hormigon suena")
	a.ok(stream_concrete in branch_streams[&"Concrete"],
		"y el stream salio de la rama Concrete")

	var peak_metal: float = await _step_and_measure(tree, player, probe, Vector3(8, 0.2, 0))
	var stream_metal = _current_stream(manager, player)
	a.gt(peak_metal, 0.001, "la pisada sobre metal suena")
	a.ok(stream_metal in branch_streams[&"Metal"],
		"y el stream salio de la rama Metal, no de la de por defecto")

	# Y el switch quedo en la superficie que se piso, no en la de por defecto.
	a.eq(str(manager.get_switch(&"SurfaceType")), "Metal",
		"la ultima pisada dejo el switch en Metal")

	manager.stop_all()
	probe.teardown()
	tree.root.remove_child(patches); patches.free()

	# La camara y el oyente quedaron current: el viewport los sigue referenciando, asi
	# que sin clear_current() cada uno es una fuga que el ratchet cuenta.
	if player.camera != null:
		player.camera.clear_current()
	if player.listener != null:
		player.listener.clear_current()
	tree.root.remove_child(player); player.free()
	tree.root.remove_child(npc); npc.free()

	tree.root.remove_child(manager); manager.free()
	return a


## El banco arranca, sus tres parches declaran su superficie, y build() no duplica.
static func run_bench_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("rig_bench")

	# Se instancia la ESCENA, no el script: el banco es un arbol de nodos y lo que hay
	# que comprobar es que ese arbol trae lo que dice. Ver
	# .agents/rules/04_scene_composition.md.
	var packed: PackedScene = load("res://scenes/rig_bench/rig_bench.tscn")
	a.ok(packed != null, "la escena del banco carga")
	a.gt(float(packed.get_state().get_node_count()), 10.0,
		"y declara sus nodos en la escena, no en un build()")
	var bench = packed.instantiate()
	tree.root.add_child(bench)
	await tree.process_frame
	await tree.physics_frame

	a.eq(bench.patch_surfaces.size(), 3, "el banco tiene tres parches")
	for surface in bench.patch_surfaces:
		a.ok(surface in SurfacePatchClass.SURFACES,
			"'%s' pertenece al vocabulario de ocho" % str(surface))

	# Cada parche declara su superficie en la metadata que los dos sistemas leen.
	var declared: Array = []
	for child in bench.get_children():
		if child is StaticBody3D and child.has_meta("surface_type"):
			declared.append(child.get_meta("surface_type"))
	for surface in bench.patch_surfaces:
		a.ok(surface in declared, "el parche '%s' declara surface_type" % str(surface))

	# El banco trae un jugador con oyente y un NPC sin el.
	var player: PlayerController = null
	var npc: NpcController = null
	for child in bench.get_children():
		if child is PlayerController:
			player = child
		elif child is NpcController:
			npc = child
	a.ok(player != null, "el banco trae jugador")
	a.ok(npc != null, "el banco trae NPC")
	if player != null:
		a.ok(player.listener != null, "el jugador del banco lleva oyente")

	# Las superficies salen de la METADATA de la escena, no de una constante del script:
	# si alguien cambia un parche en el editor, patch_surfaces lo refleja.
	var from_scene: Array[StringName] = []
	for child in bench.get_children():
		if child is StaticBody3D and child.has_meta("surface_type"):
			from_scene.append(StringName(child.get_meta("surface_type")))
	a.eq(bench.patch_surfaces, from_scene,
		"patch_surfaces se lee de la escena y no de una constante del script")

	# Y el cartel viene instanciado con su tesis puesta desde la escena.
	var hud = bench.get_node_or_null("Hud")
	a.ok(hud != null, "el banco trae su cartel")
	if hud != null:
		a.ok(not str(hud.thesis).is_empty(), "y el cartel declara la tesis del banco")
		a.gt(float(hud.exercises.size()), 0.0, "y lo que la escena ejercita")

	# El autoload sobrevive a la escena: si el banco dejara instancias, la suite
	# siguiente mediria las pisadas de un banco que ya no existe.
	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	if autoload_manager != null:
		autoload_manager.stop_all()
	if player != null:
		if player.camera != null:
			player.camera.clear_current()
		if player.listener != null:
			player.listener.clear_current()
	tree.root.remove_child(bench)
	bench.free()
	await tree.process_frame
	if autoload_manager != null:
		a.eq(autoload_manager.active_instances.size(), 0,
			"el banco no deja instancias en el autoload")
	return a


## Streams de cada rama del switch container, por nombre de superficie.
static func _branch_streams(switch_container) -> Dictionary:
	var out: Dictionary = {}
	for state_name in switch_container.state_mappings:
		var branch = switch_container.state_mappings[state_name]
		var streams: Array = []
		for child in branch.children:
			streams.append(child.stream)
		out[state_name] = streams
	return out


## El stream que esta sonando ahora mismo en la voz del rig.
static func _current_stream(manager, player):
	var instance = player.get_node("CharacterAudioRig").rig_emitter.active_instance
	if instance == null or instance.assigned_channel_id < 0:
		return null
	var ch = manager.voice_pool.get_channel(instance.assigned_channel_id)
	return ch.current_stream if ch != null else null


## Coloca al jugador, dispara un paso y mide el pico en el bus de sonda.
static func _step_and_measure(tree: SceneTree, player, probe, pos: Vector3) -> float:
	player.global_position = pos
	await tree.physics_frame
	await tree.physics_frame
	var rig = player.get_node("CharacterAudioRig")
	probe.drain()
	rig.step()
	return await probe.measure_peak_over_frames(tree, 25)
