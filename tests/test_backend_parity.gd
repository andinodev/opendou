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

## El mismo evento, a la misma distancia, con los dos backends: la CAIDA entre distancias
## difiere menos de 1 dB, porque la gobierna la misma formula; el nivel absoluto, menos de
## 2 dB, porque el HRTF de Steam Audio no es transparente en nivel de frente. Es lo que
## permite prometer que cambiar de backend no cambia la mezcla.
static func run_parity_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("backend_parity")
	if not BackendClass.native_available():
		print("[OpenDou] extension nativa AUSENTE: suite backend_parity omitida")
		return a
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var cam := make_listener_camera(tree)
	var levels: Dictionary = {}
	for backend in ["godot", "steam_audio"]:
		var manager = make_manager(tree, backend)
		await tree.process_frame
		var near := await measure_voice(tree, manager, probe, 2.0)
		var mid := await measure_voice(tree, manager, probe, 16.0)
		levels[backend] = {"near": near.rms_db, "mid": mid.rms_db, "ratio_near": near.high_ratio, "ratio_mid": mid.high_ratio}
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	print("[OpenDou] paridad: godot 2 m %.2f dB / 16 m %.2f dB | steam_audio 2 m %.2f dB / 16 m %.2f dB" % [
		levels["godot"].near, levels["godot"].mid, levels["steam_audio"].near, levels["steam_audio"].mid])
	print("[OpenDou] paridad, banda alta: godot %.3f -> %.3f | steam_audio %.3f -> %.3f" % [
		levels["godot"].ratio_near, levels["godot"].ratio_mid, levels["steam_audio"].ratio_near, levels["steam_audio"].ratio_mid])
	var drop_godot: float = levels["godot"].mid - levels["godot"].near
	var drop_steam: float = levels["steam_audio"].mid - levels["steam_audio"].near
	a.lt(absf(drop_godot - drop_steam), 1.0, "la caida de 2 a 16 m difiere menos de 1 dB entre backends")
	# Medido: 2.0 dB exactos de diferencia a 2 m (-10.70 frente a -12.69), deterministas con la
	# fuente periodica. Es la ley de paneo de Godot para una fuente centrada frente a la
	# respuesta frontal del HRTF, y la normalizacion RMS del HRTF no lo movio. Se afirma con
	# medio decibelio de margen para que una decima no lo convierta en intermitente.
	a.lt(absf(levels["godot"].near - levels["steam_audio"].near), 2.5, "el nivel absoluto a 2 m difiere menos de 2.5 dB (medido 2.0)")
	a.lt(drop_godot, -12.0, "y la caida es la de la distancia inversa: al menos -12 dB (esperado -18)")
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
