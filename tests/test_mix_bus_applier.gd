class_name TestMixBusApplier
extends RefCounted

## Fase 8: las instantaneas, el ducking y el area de parametros NUNCA escribian en el
## AudioServer. Ahora si, con el modelo base + delta + ducking, y se afirma leyendo el
## servidor y capturando el bus. Los buses son propios de este test para no pelear con el
## autoload, que solo gestiona los buses que nombran sus propias instantaneas.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioMixSnapshotClass = preload("res://addons/opendou/core/audio_mix_snapshot.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func _make_bus(name: String) -> int:
	var idx: int = AudioServer.get_bus_index(name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

static func _wait_ms(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func _find_effect(bus_idx: int, mark: String) -> Dictionary:
	for e in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, e)
		if fx != null and fx.resource_name == mark:
			return {"effect": fx, "enabled": AudioServer.is_bus_effect_enabled(bus_idx, e)}
	return {}

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_bus_applier")
	var music_idx: int = _make_bus("MixTestMusic")
	_make_bus("MixTestVoice")
	AudioServer.set_bus_volume_db(music_idx, -3.0)
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	await tree.process_frame

	var snap = AudioMixSnapshotClass.new(&"TestDuck", {
		&"MixTestMusic": {"volume_db": -18.0, "lpf_hz": 500.0, "hpf_hz": 20.0, "mute": false},
	}, 0.2)
	manager.mix.snapshots.register_snapshot(snap)
	var neutral = AudioMixSnapshotClass.new(&"TestNeutral", {
		&"MixTestMusic": {"volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false},
	}, 0.2)
	manager.mix.snapshots.register_snapshot(neutral)
	manager.mix.snapshots.apply_snapshot_instant(&"TestNeutral")
	a.ok(&"MixTestMusic" in manager.mix.managed_buses(), "el bus de la instantanea es gestionado")
	await tree.process_frame
	a.approx(manager.get_bus_base_volume_db(&"MixTestMusic"), -3.0, "la base capturada es el volumen que tenia el bus", 0.01)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -3.0, "sin instantanea activa el bus se queda en su base", 0.01)

	# push: el volumen REAL baja con el fundido y el filtro aparece.
	manager.push_snapshot(&"TestDuck", 0.2)
	await _wait_ms(tree, 500)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -21.0, "push: base -3 + delta -18 = -21 dB en el AudioServer", 0.2)
	var lpf: Dictionary = _find_effect(music_idx, "OpenDou_Mix_LPF")
	a.ok(not lpf.is_empty() and bool(lpf["enabled"]), "push: hay un paso-bajo marcado y habilitado en el bus")
	if not lpf.is_empty():
		a.approx(lpf["effect"].cutoff_hz, 500.0, "y esta en 500 Hz", 5.0)

	# El jugador mueve la base con la instantanea activa: el aplicado se mueve lo mismo.
	manager.set_bus_base_volume_db(&"MixTestMusic", -6.0)
	await tree.process_frame
	await tree.process_frame
	a.approx(AudioServer.get_bus_volume_db(music_idx), -24.0, "mover la base -3 dB mueve lo aplicado -3 dB", 0.2)

	# pop: vuelve a la base y el filtro se deshabilita (no se quita).
	# pop sin tiempo usaria el fundido por defecto de la instantanea destino (1 s): se pide 0.2.
	manager.pop_snapshot(&"TestDuck", 0.2)
	await _wait_ms(tree, 500)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "pop: vuelve a la base", 0.2)
	lpf = _find_effect(music_idx, "OpenDou_Mix_LPF")
	a.ok(not lpf.is_empty() and not bool(lpf["enabled"]), "pop: el paso-bajo queda deshabilitado, no se quita")

	# Sin transiciones ni ducking: cero escrituras por frame.
	await tree.process_frame
	await tree.process_frame
	a.eq(manager.mix.writes_last_frame, 0, "en reposo no se escribe nada en el AudioServer")

	# Ducking: una regla propia; activar la fuente baja el destino de verdad.
	manager.mix.ducking.add_rule(&"MixTestVoice", &"MixTestMusic", -9.0, 0.02, 0.1)
	manager.mix.ducking.set_bus_active(&"MixTestVoice", true)
	await _wait_ms(tree, 250)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -15.0, "ducking: base -6 + (-9) = -15 dB", 0.3)
	manager.mix.ducking.set_bus_active(&"MixTestVoice", false)
	await _wait_ms(tree, 500)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "sin fuente activa, vuelve", 0.3)

	# Y se OYE. Ojo: Godot aplica el volumen de un bus AL ENVIARLO al siguiente, despues de sus
	# efectos, asi que una captura dentro del bus no ve su volumen. Y un bus solo puede enviar
	# a otro de indice MENOR, asi que la sonda va en Master, al que MixTestMusic ya envia y
	# donde en este momento no suena nada mas.
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var tone: AudioStreamWAV = SynthClass.create_rain_ambient_loop(1.0)
	var p := AudioStreamPlayer.new()
	p.stream = tone
	p.bus = "MixTestMusic"
	tree.root.add_child(p)
	p.play()
	await _wait_ms(tree, 250)
	probe.drain()
	var peak_base: float = await probe.measure_peak_over_frames(tree, 20)
	manager.push_snapshot(&"TestDuck", 0.1)
	await _wait_ms(tree, 500)
	probe.drain()
	var peak_ducked: float = await probe.measure_peak_over_frames(tree, 20)
	print("[OpenDou] mezcla al servidor: pico base %.4f, con instantanea %.4f" % [peak_base, peak_ducked])
	a.lt(peak_ducked, peak_base * 0.3, "la instantanea se oye: el pico cae mas de 10 dB")
	manager.pop_snapshot(&"TestDuck", 0.1)
	await _wait_ms(tree, 300)
	p.stop()
	tree.root.remove_child(p)
	p.free()
	probe.teardown()

	# El manager de test se va antes de probar el area, que resuelve el autoload.
	manager.mix.snapshots.registered_snapshots.erase(&"TestDuck")
	manager.mix.snapshots.registered_snapshots.erase(&"TestNeutral")
	tree.root.remove_child(manager)
	manager.free()

	# Area de parametros: por fin hace algo. Trabaja con el autoload, que es quien resuelve.
	var autoload = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload != null and "mix" in autoload, "el autoload tiene aplicador de mezcla")
	autoload.mix.snapshots.register_snapshot(snap)
	autoload.mix.set_bus_base_volume_db(&"MixTestMusic", -6.0)
	var AreaScript = load("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
	var area = AreaScript.new()
	area.target_snapshot = &"TestDuck"
	tree.root.add_child(area)
	# El area usa sus fundidos propios (fade_in_time 0.5, fade_out_time 0.8).
	area._activate_snapshot()
	await _wait_ms(tree, 1000)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -24.0, "el area de parametros empuja la instantanea de verdad", 0.3)
	area._release_snapshot()
	await _wait_ms(tree, 1300)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "y la suelta al salir", 0.3)
	tree.root.remove_child(area)
	area.free()
	autoload.mix.snapshots.registered_snapshots.erase(&"TestDuck")
	return a

## Un estado del juego apila su instantanea mientras dura, y la suelta al salir.
static func run_state_binding_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_state_binding")
	var idx: int = _make_bus("MixTestMusic")
	AudioServer.set_bus_volume_db(idx, 0.0)
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	manager.mix.snapshots.register_snapshot(AudioMixSnapshotClass.new(&"LowHealthMix", {
		&"MixTestMusic": {"volume_db": -10.0, "lpf_hz": 600.0, "hpf_hz": 20.0, "mute": false}}, 0.1))
	manager.mix.snapshots.register_snapshot(AudioMixSnapshotClass.new(&"TestNeutral2", {
		&"MixTestMusic": {"volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false}}, 0.1))
	manager.mix.snapshots.apply_snapshot_instant(&"TestNeutral2")
	await tree.process_frame
	var BindingClass = load("res://addons/opendou/resources/mix_state_binding.gd")
	var b = BindingClass.new()
	b.state_group = &"Player"
	b.state_name = &"LowHealth"
	b.snapshot_name = &"LowHealthMix"
	b.blend_sec = 0.1
	manager.register_mix_state_binding(b)
	manager.sync_manager.set_state(&"Player", &"LowHealth")
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(idx), -10.0, "entrar en el estado apila su instantanea: -10 dB reales", 0.3)
	manager.sync_manager.set_state(&"Player", &"Normal")
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(idx), 0.0, "salir del estado la desapila", 0.3)
	manager.unregister_mix_state_binding(b)
	manager.sync_manager.set_state(&"Player", &"LowHealth")
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(idx), 0.0, "sin vinculacion, el estado no toca la mezcla (control)", 0.3)
	manager.sync_manager.set_state(&"Player", &"Normal")
	tree.root.remove_child(manager)
	manager.free()
	return a
