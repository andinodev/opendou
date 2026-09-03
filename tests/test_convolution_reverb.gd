class_name TestConvolutionReverb
extends RefCounted

## Fase 13: reverb por convolucion en el bus de la sala. La cola tras un tono corto dura mas
## en una caja de hormigon que en una de follaje; con wet = 0 no hay cola; sin extension,
## CONVOLUTION deja un AudioEffectReverb de Godot en el bus.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const TestReflectionsThreadClass = preload("res://tests/test_reflections_thread.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const RoomScript = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func _record(tree: SceneTree, probe, ms: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame
		var avail: int = probe._capture.get_frames_available()
		if avail > 0:
			out.append_array(probe._capture.get_buffer(avail))
	return out

static func _rms_db(frames: PackedVector2Array, from: int, to: int) -> float:
	var acc: float = 0.0
	var n: int = 0
	for i in range(maxi(from, 0), mini(to, frames.size())):
		acc += 0.5 * (frames[i].x * frames[i].x + frames[i].y * frames[i].y)
		n += 1
	return linear_to_db(maxf(sqrt(acc / maxf(float(n), 1.0)), 1e-9))

## Caja de `material` con una OpenDouRoom3D en CONVOLUTION; devuelve {tail_db, tone_db, bus, conv}.
static func _measure(tree: SceneTree, backend: String, material: StringName, wet: float) -> Dictionary:
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	cam.global_position = Vector3(0, 1.5, 0)
	var walls: Array = TestReflectionsThreadClass.make_box_room(tree, material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	var room = RoomScript.new()
	room.room_name = &"Caja"
	room.reverb_mode = RoomScript.ReverbMode.CONVOLUTION
	room.reverb_send_amount = 1.0   # el envio de Godot a 0 no manda nada al bus: el wet se fija en el efecto
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 6)
	shape.shape = box
	room.add_child(shape)
	room.set_acoustics_manager(manager.spatial_acoustics)
	tree.root.add_child(room)
	room.global_position = Vector3(0, 1.5, 0)
	var bus: StringName = room.get_assigned_reverb_bus()
	# El manager necesita ver al oyente dentro y al simulador listo; el hilo tarda unos ms.
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and manager.get_room_reverb_times(&"Caja").y <= 0.0:
		await tree.process_frame
	var rt: Vector3 = manager.get_room_reverb_times(&"Caja")
	var conv: bool = manager.spatial_acoustics.reverb_bus_pool.has_convolution(bus)
	manager.spatial_acoustics.reverb_bus_pool.set_convolution_wet(bus, wet)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(bus, 3.0)
	# 200 ms de tono: un click de 50 ms acaba antes de que Godot enrute el anfitrion al bus de reverb.
	var def = AudioEventDefClass.new(&"Click", load("res://tests/test_emitter_physics.gd")._tone(1000.0, 0.2, -3.0))
	def.is_looping = false
	def.stream_length = 0.2
	manager.register_event_definition(def)
	probe.drain()
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(1, 1.5, -1))
	var frames: PackedVector2Array = await _record(tree, probe, 1200)
	var rate: int = int(AudioServer.get_mix_rate())
	# Tono: 0.05-0.2 s; cola: 0.25-0.4 s (con RT60 de 0.4 s en una caja de 6 m, a los 0.5 s ya no
	# queda nada: la IR trazada decae -60 dB en 0.4 s).
	# Ventanas alineadas al inicio real del tono (el arranque de la voz tarda un par de cuadros).
	var onset: int = 0
	for i in range(frames.size()):
		if absf(frames[i].x) > 0.01 or absf(frames[i].y) > 0.01:
			onset = i
			break
	# Godot enruta la voz al bus de reverb del Area3D con hasta un bloque de retraso (obs 49):
	# a veces el tono llega al bus recortado por delante. El FINAL del tono no depende de eso, y
	# las ventanas se alinean a el: tono en [-0.1, -0.02] s y cola en [+0.05, +0.2] s.
	# El final se busca por bloques de 10 ms: el ultimo bloque a menos de 3 dB del mas fuerte
	# (el tono es estable; la cola cae mas de 5 dB en el primer bloque sin tono).
	var block: int = int(rate * 0.01)
	var block_db: Array[float] = []
	var peak_db: float = -180.0
	for b in range(0, frames.size() - block, block):
		var v: float = _rms_db(frames, b, b + block)
		block_db.append(v)
		peak_db = maxf(peak_db, v)
	var end: int = onset
	for b in range(block_db.size() - 1, -1, -1):
		if block_db[b] > peak_db - 3.0:
			end = (b + 1) * block
			break
	var decay: String = ""
	for w in range(0, 6):
		decay += " %.2f:%.1f" % [w * 0.1, _rms_db(frames, onset + int(rate * w * 0.1), onset + int(rate * (w + 1) * 0.1))]
	print("[OpenDou] convolucion %s (%s): inicio %d, fin %d, forma por 100 ms desde el inicio:%s" % [material, backend, onset, end, decay])
	var out := {"tone_db": _rms_db(frames, end - int(rate * 0.1), end - int(rate * 0.02)), "tail_db": _rms_db(frames, end + int(rate * 0.05), end + int(rate * 0.2)), "rt60": rt, "conv": conv, "bus": bus, "samples": frames.size()}
	probe.teardown()
	tree.root.remove_child(room); room.free()
	tree.root.remove_child(bake); bake.free()
	for w in walls:
		tree.root.remove_child(w); w.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "shutdown")
		ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return out

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("convolution_reverb")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouConvolutionReverb"):
		print("[OpenDou] extension nativa AUSENTE: convolucion omitida")
		return a
	var concrete: Dictionary = await _measure(tree, "steam_audio", &"Concrete", 1.0)
	var foliage: Dictionary = await _measure(tree, "steam_audio", &"Foliage", 1.0)
	var dry: Dictionary = await _measure(tree, "steam_audio", &"Concrete", 0.0)
	print("[OpenDou] convolucion: hormigon tono %.1f cola %.1f dB (RT60 %.2f, conv %s, %d muestras) | follaje cola %.1f dB (RT60 %.2f) | wet 0 cola %.1f dB" % [concrete.tone_db, concrete.tail_db, concrete.rt60.y, str(concrete.conv), int(concrete.samples), foliage.tail_db, foliage.rt60.y, dry.tail_db])
	a.ok(concrete.conv, "la sala en CONVOLUTION tiene el efecto nativo en su bus")
	a.gt(concrete.rt60.y, 0.1, "y el hilo trazo su RT60")
	a.gt(concrete.tail_db, foliage.tail_db + 6.0, "la cola del hormigon supera a la del follaje en al menos 6 dB")
	a.lt(dry.tail_db, concrete.tail_db - 15.0, "con wet = 0 no hay cola")
	# El seco pasa: con wet = 1 las reflexiones tempranas suman o restan hasta 4 dB en la ventana
	# del tono (filtro de peine); con wet = 0 el tono queda intacto.
	a.approx(dry.tone_db, concrete.tone_db, "el tono seco pasa (las reflexiones tempranas lo mueven menos de 4 dB)", 4.0)
	# Sin extension (backend godot): CONVOLUTION deja un reverb de Godot y el bus existe.
	# Reflectores como ajuste artistico: en una sala CONVOLUTION con extension no se emiten.
	var mgr = TestParityClass.make_manager(tree, "steam_audio")
	var conv_room = load("res://addons/opendou/runtime/spatial/audio_room.gd").new(&"Conv")
	conv_room.set_bounds(AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10)))
	conv_room.reverb_mode = 2
	mgr.spatial_acoustics.register_room(conv_room)
	var sabine_room = load("res://addons/opendou/runtime/spatial/audio_room.gd").new(&"Sabine")
	sabine_room.set_bounds(AABB(Vector3(20, -5, -5), Vector3(10, 10, 10)))
	mgr.spatial_acoustics.register_room(sabine_room)
	var probe_def = AudioEventDefClass.new(&"Refl", load("res://tests/test_emitter_physics.gd")._tone(500.0, 0.5))
	mgr.register_event_definition(probe_def)
	var in_conv = mgr.post_event(probe_def, null)
	in_conv.set_position(Vector3(0, 1, 0))
	var in_sabine = mgr.post_event(probe_def, null)
	in_sabine.set_position(Vector3(25, 1, 0))
	a.ok(not mgr.reflections_allowed_for(in_conv), "en una sala CONVOLUTION no se emiten reflexiones autoradas")
	a.ok(mgr.reflections_allowed_for(in_sabine), "en una sala Sabine si")
	mgr.reflection_dispatcher.enabled = false
	a.ok(not mgr.reflections_allowed_for(in_sabine), "con el despachador apagado, nunca")
	mgr.stop_all()
	tree.root.remove_child(mgr); mgr.free()
	var fallback: Dictionary = await _measure(tree, "godot", &"Concrete", 1.0)
	a.ok(not fallback.conv, "en godot no hay convolucion nativa (el bus compartido vuelve a Sabine)")
	a.ok(String(fallback.bus) != "" and String(fallback.bus) != "Master", "pero la sala tiene su bus de reverb de Sabine")
	return a
