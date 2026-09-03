class_name TestReverbSend
extends RefCounted

## Fase 15 (C1): envio de reverb propio en steam_audio. La voz dentro de una sala vuelve a su
## target_bus; el bus de reverb recibe solo el envio (cola sin seco); con envio 0, calla.
## Control: en el backend godot sigue mandando el Area3D (observacion 49).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const TestReflectionsThreadClass = preload("res://tests/test_reflections_thread.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const RoomScript = preload("res://addons/opendou/nodes/opendou_room_3d.gd")

static func _rms_db(frames: PackedVector2Array, from: int, to: int) -> float:
	from = maxi(from, 0)
	to = mini(to, frames.size())
	if to <= from:
		return -180.0
	var acc: float = 0.0
	for i in range(from, to):
		acc += frames[i].x * frames[i].x + frames[i].y * frames[i].y
	return linear_to_db(maxf(sqrt(acc / float(2 * (to - from))), 1e-9))

## {target_db, reverb_tone_db, reverb_tail_db, send, routed_by_godot}
static func _measure(tree: SceneTree, backend: String, send_amount: float, wet: float = 1.0) -> Dictionary:
	var previous_backend = ProjectSettings.get_setting("opendou/spatial/backend", "auto")
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	cam.global_position = Vector3(0, 1.5, 0)
	var walls: Array = TestReflectionsThreadClass.make_box_room(tree, &"Concrete")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	var room = RoomScript.new()
	room.room_name = &"Caja"
	room.reverb_mode = RoomScript.ReverbMode.CONVOLUTION
	room.reverb_send_amount = send_amount
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 6)
	shape.shape = box
	room.add_child(shape)
	room.set_acoustics_manager(manager.spatial_acoustics)
	tree.root.add_child(room)
	room.global_position = Vector3(0, 1.5, 0)
	var bus: StringName = room.get_assigned_reverb_bus()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and manager.get_room_reverb_times(&"Caja").y <= 0.0 and backend == "steam_audio":
		await tree.process_frame
	if backend == "steam_audio":
		manager.spatial_acoustics.reverb_bus_pool.set_convolution_wet(bus, wet)
	TestParityClass.ensure_bus()
	var target_probe = OpenDouAudioProbeClass.new()
	target_probe.attach_to_existing_bus(TestParityClass.BUS, 3.0)
	var reverb_probe = OpenDouAudioProbeClass.new()
	reverb_probe.attach_to_existing_bus(bus, 3.0)
	var def = AudioEventDefClass.new(&"SendTone", load("res://tests/test_emitter_physics.gd")._tone(1000.0, 0.3, -3.0))
	def.is_looping = false
	def.stream_length = 0.3
	def.target_bus = TestParityClass.BUS
	manager.register_event_definition(def)
	target_probe.drain()
	reverb_probe.drain()
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(1, 1.5, -1))
	var target := PackedVector2Array()
	var reverb := PackedVector2Array()
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1200:
		await tree.process_frame
		var a1: int = target_probe._capture.get_frames_available()
		if a1 > 0:
			target.append_array(target_probe._capture.get_buffer(a1))
		var a2: int = reverb_probe._capture.get_frames_available()
		if a2 > 0:
			reverb.append_array(reverb_probe._capture.get_buffer(a2))
	var rate: int = int(AudioServer.get_mix_rate())
	# Fin del tono en el bus destino (bloques de 10 ms, ultimo a -3 dB del mas fuerte).
	var block: int = int(rate * 0.01)
	var peak_db: float = -180.0
	var block_db: Array[float] = []
	for b in range(0, target.size() - block, block):
		var v: float = _rms_db(target, b, b + block)
		block_db.append(v)
		peak_db = maxf(peak_db, v)
	var end: int = 0
	for b in range(block_db.size() - 1, -1, -1):
		if block_db[b] > peak_db - 3.0:
			end = (b + 1) * block
			break
	var n: int = mini(target.size(), reverb.size())
	var out := {
		"target_db": _rms_db(target, end - int(rate * 0.15), end - int(rate * 0.02)),
		"reverb_tone_db": _rms_db(reverb, end - int(rate * 0.15), end - int(rate * 0.02)),
		"reverb_tail_db": _rms_db(reverb, end + int(rate * 0.05), end + int(rate * 0.2)),
		"reverb_peak_db": peak_db,
		"send": room.runtime_room.send_id if room.runtime_room != null else -1,
		"routed_by_godot": room.reverb_bus_enabled,
		"bus": bus,
		"samples": n,
	}
	target_probe.teardown()
	reverb_probe.teardown()
	tree.root.remove_child(room); room.free()
	tree.root.remove_child(bake); bake.free()
	for w in walls:
		tree.root.remove_child(w); w.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "shutdown")
		ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	ProjectSettings.set_setting("opendou/spatial/backend", previous_backend)
	return out

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("reverb_send")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSendStream"):
		print("[OpenDou] extension nativa AUSENTE: envio propio omitido")
		return a
	var on: Dictionary = await _measure(tree, "steam_audio", 1.0)
	var off: Dictionary = await _measure(tree, "steam_audio", 0.0)
	print("[OpenDou] envio propio: send %d (Godot enruta: %s) | destino %.1f dB | reverb durante el tono %.1f, cola %.1f dB | con envio 0: destino %.1f, reverb cola %.1f dB" % [int(on.send), str(on.routed_by_godot), on.target_db, on.reverb_tone_db, on.reverb_tail_db, off.target_db, off.reverb_tail_db])
	a.ok(int(on.send) >= 0 and not bool(on.routed_by_godot), "la sala steam_audio usa envio propio y no el Area3D")
	a.gt(float(on.target_db), -20.0, "la voz dentro de la sala suena en su target_bus")
	a.gt(float(on.reverb_tail_db), -45.0, "el bus de reverb tiene cola tras el tono")
	# El bus de reverb no lleva el seco: con el efecto en wet = 0 (y el envio a 1) calla del todo.
	var wet0: Dictionary = await _measure(tree, "steam_audio", 1.0, 0.0)
	print("[OpenDou] envio propio, wet 0: destino %.1f dB, reverb durante el tono %.1f, cola %.1f" % [wet0.target_db, wet0.reverb_tone_db, wet0.reverb_tail_db])
	a.lt(float(wet0.reverb_tone_db), -60.0, "con wet = 0 el bus de reverb no lleva el seco aunque el envio este a 1")
	a.approx(float(wet0.target_db), float(on.target_db), "y el destino no cambia", 1.0)
	a.approx(float(off.target_db), float(on.target_db), "el envio no cambia el nivel del destino", 1.0)
	a.lt(float(off.reverb_tail_db), -80.0, "con envio 0 el bus de reverb calla")
	var godot: Dictionary = await _measure(tree, "godot", 1.0)
	print("[OpenDou] envio propio, control godot: send %d, Godot enruta %s, destino %.1f dB, reverb tono %.1f" % [int(godot.send), str(godot.routed_by_godot), godot.target_db, godot.reverb_tone_db])
	a.ok(int(godot.send) < 0 and bool(godot.routed_by_godot), "en godot sigue enrutando el Area3D")
	a.lt(float(godot.target_db), -60.0, "y el target_bus sigue mudo (observacion 49, acotada a ese backend)")
	await tree.create_timer(0.3).timeout
	return a
