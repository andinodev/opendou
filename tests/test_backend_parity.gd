class_name TestBackendParity
extends RefCounted

## Paridad entre backends y correccion de la observacion 42.
##
## El panner de Godot atenua respecto a SU oyente (la camara o el AudioListener3D del
## viewport), no al de OpenDou: por eso cada medida pone una Camera3D en el origen mirando
## a -Z, que es donde OpenDou tambien coloca su oyente. Sin ella, AudioStreamPlayer3D no
## atenua nada en headless y el test afirmaria sobre una cadena que no es la del juego.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")
const SpikeClass = preload("res://tests/test_binaural.gd")   # por _periodic_noise y _pinna_band_ratio

const BUS: StringName = &"ParityProbe"

## Crea un manager con el backend pedido. Quien llama restaura el ajuste al terminar.
static func make_manager(tree: SceneTree, backend: String) -> Node:
	ProjectSettings.set_setting(BackendClass.SETTING, backend)
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	return manager

static func ensure_bus() -> void:
	if AudioServer.get_bus_index(String(BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(BUS))
		AudioServer.set_bus_send(idx, "Master")

## Camara en el origen mirando a -Z: el oyente de Godot. Quien la pide la libera.
static func make_listener_camera(tree: SceneTree) -> Camera3D:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.global_position = Vector3.ZERO
	cam.make_current()
	return cam

## Nivel RMS (dB) y relacion de banda del pabellon (5-10 kHz / 1-4 kHz) de una voz posteada
## a `distance` metros delante del oyente, tras asentarse.
static func measure_voice(tree: SceneTree, manager: Node, probe, distance: float) -> Dictionary:
	var noise := SpikeClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"ParityVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = BUS
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -distance))
	for i in range(10):
		await tree.process_frame
		probe.drain()
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	for i in range(30):
		await tree.process_frame
		var avail: int = probe._capture.get_frames_available()
		if avail > 0:
			for v in probe._capture.get_buffer(avail):
				l.append(v.x)
				r.append(v.y)
	inst.stop()
	await probe.await_silence(tree, 0.002, 30)
	var acc: float = 0.0
	var n: int = mini(l.size(), r.size())
	for i in range(n):
		acc += 0.5 * (l[i] * l[i] + r[i] * r[i])
	var rms: float = sqrt(acc / maxf(float(n), 1.0))
	return {
		"rms_db": linear_to_db(maxf(rms, 1e-9)),
		"high_ratio": SpikeClass._pinna_band_ratio({"left": l, "right": r}, AudioServer.get_mix_rate()),
		"samples": n,
	}

static func run_godot_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("backend_godot")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var cam := make_listener_camera(tree)
	var manager = make_manager(tree, "godot")
	await tree.process_frame
	a.eq(manager.spatial_backend, &"godot", "el manager quedo en el backend de Godot")

	var near := await measure_voice(tree, manager, probe, 10.0)
	var far := await measure_voice(tree, manager, probe, 40.0)
	a.gt(float(near.samples), 4096.0, "se capturo audio a 10 m")
	# Observacion 42: a 40 m con unit_size 10 el multiplicador es 0.25 y el shelf de Godot
	# vale -18 dB por encima de 5 kHz. Antes de la correccion, OpenDou pisaba el corte con
	# 20 kHz y la banda alta NO caia.
	a.lt(far.high_ratio, near.high_ratio * 0.5, "a 40 m la banda alta cae al menos a la mitad respecto a 10 m (obs 42 corregida)")
	# Nivel: inversa a la distancia, 10 -> 40 m son -12 dB, con margen por el shelf.
	a.lt(far.rms_db - near.rms_db, -9.0, "a 40 m el nivel cae al menos 9 dB")
	print("[OpenDou] godot: 10 m %.1f dB ratio %.3f | 40 m %.1f dB ratio %.3f" % [near.rms_db, near.high_ratio, far.rms_db, far.high_ratio])

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
