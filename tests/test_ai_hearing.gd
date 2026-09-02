class_name TestAIHearing
extends RefCounted

## Fase 10: cuanto de un sonido llega a un punto cualquiera, por grafo de salas y por rayo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const DistanceModelClass = preload("res://addons/opendou/runtime/spatial/distance_model.gd")

static func _loudness_of(manager, name: StringName, pos: Vector3, w3d: World3D = null) -> float:
	for e in manager.get_loudness_at(pos, w3d):
		if e.event_name == name:
			return e.loudness_db
	return -INF

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("ai_hearing")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	var def = AudioEventDefClass.new(&"Disparo", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.hdr_loudness_db = 0.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3.ZERO)
	await tree.process_frame
	var guard := Vector3(0, 0, 20)
	var open_field: float = _loudness_of(manager, &"Disparo", guard)
	a.ok(open_field > -INF, "la consulta devuelve el evento")
	var expected_open: float = DistanceModelClass.attenuation_db(20.0, inst.attenuation_model, inst.unit_size)
	a.approx(open_field, expected_open, "a 20 m, el modelo de distancia de la instancia (%.1f dB)" % expected_open, 0.5)
	# Dos salas y un portal cerrado entre ellas.
	var ac = manager.spatial_acoustics
	var room_a = AudioRoomClass.new(&"A")
	room_a.set_bounds(AABB(Vector3(-5, -5, -5), Vector3(10, 10, 15)))     # z de -5 a 10
	ac.register_room(room_a)
	var room_b = AudioRoomClass.new(&"B")
	room_b.set_bounds(AABB(Vector3(-5, -5, 10), Vector3(10, 10, 15)))     # z de 10 a 25
	ac.register_room(room_b)
	var door = AudioPortalClass.new(&"Puerta", &"A", &"B", Vector3(0, 0, 10), 0.0)
	ac.register_portal(door)
	manager.room_path_dispatcher.clear_cache()
	var closed: float = _loudness_of(manager, &"Disparo", guard)
	door.open_factor = 1.0
	manager.room_path_dispatcher.clear_cache()
	var opened: float = _loudness_of(manager, &"Disparo", guard)
	print("[OpenDou] la IA oye: campo abierto %.1f dB, puerta cerrada %.1f dB, abierta %.1f dB" % [open_field, closed, opened])
	a.lt(closed, open_field - 10.0, "tras la puerta cerrada, al menos 10 dB menos")
	a.gt(opened, closed + 6.0, "al abrirla, sube al menos 6 dB")
	ac.unregister_portal(&"Puerta")
	ac.unregister_room(&"A")
	ac.unregister_room(&"B")
	manager.room_path_dispatcher.clear_cache()
	# Una pared fisica en la misma sala: el rayo la ve.
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 0.5)
	cs.shape = box
	wall.add_child(cs)
	tree.root.add_child(wall)
	wall.global_position = Vector3(0, 0, 10)
	await tree.physics_frame
	await tree.physics_frame
	var w3d: World3D = tree.root.find_world_3d()
	var walled: float = _loudness_of(manager, &"Disparo", guard, w3d)
	a.lt(walled, open_field - 5.0, "tras una pared fisica, al menos 5 dB menos (medido %.1f)" % walled)
	wall.global_position = Vector3(100, 0, 0)
	await tree.physics_frame
	await tree.physics_frame
	a.approx(_loudness_of(manager, &"Disparo", guard, w3d), open_field, "sin pared, igual que en campo abierto", 0.5)
	# El nodo.
	var hearing = load("res://addons/opendou/nodes/opendou_ai_hearing_3d.gd").new()
	hearing.threshold_db = -30.0
	hearing.poll_interval_sec = 0.02
	tree.root.add_child(hearing)
	hearing.set_manager(manager)   # en la suite existe el autoload /root/OpenDou, vacio
	hearing.global_position = Vector3(0, 0, 3)
	var heard: Array = []
	hearing.sound_heard.connect(func(n, l, p): heard.append([n, l, p]))
	var far_def = AudioEventDefClass.new(&"Lejano", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	far_def.is_looping = true
	far_def.stream_length = 1.0
	manager.register_event_definition(far_def)
	var far = manager.post_event(far_def, null)
	far.max_distance = 1000.0
	far.set_position(Vector3(0, 0, 500))
	for i in range(30):
		await tree.process_frame
	a.eq(heard.size(), 1, "el guardia oye el disparo cercano una sola vez")
	if heard.size() >= 1:
		a.eq(String(heard[0][0]), "Disparo", "y sabe cual es")
		a.ok(heard[0][2].is_equal_approx(Vector3.ZERO), "y de donde viene")
	a.eq(hearing.get_last_heard().size(), 2, "la ultima consulta trae las dos voces")
	inst.stop()
	far.stop()
	tree.root.remove_child(hearing); hearing.free()
	tree.root.remove_child(wall); wall.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	return a
