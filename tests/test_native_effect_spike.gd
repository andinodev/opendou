class_name TestNativeEffectSpike
extends RefCounted

## Fase 13, spike B5: un AudioEffect por GDExtension funciona en un bus de Godot. Si esto pasa,
## la convolucion y el medidor LUFS nativo pueden ser efectos de bus.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("native_effect_spike")
	if not ClassDB.class_exists("OpenDouGainEffect"):
		print("[OpenDou] extension nativa AUSENTE: spike del efecto omitido")
		return a
	var bus := "SpikeEffectBus"
	if AudioServer.get_bus_index(bus) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
	var bidx: int = AudioServer.get_bus_index(bus)
	var fx = ClassDB.instantiate("OpenDouGainEffect")
	fx.gain_db = -12.0
	AudioServer.add_bus_effect(bidx, fx)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(StringName(bus), 2.0)   # la sonda va DESPUES del efecto
	var player := AudioStreamPlayer.new()
	player.stream = load("res://tests/test_emitter_physics.gd")._tone(1000.0, 2.0)
	player.volume_db = -6.0
	player.bus = bus
	tree.root.add_child(player)
	player.play()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await tree.process_frame
		probe.drain()
	var with_fx: float = await probe.measure_peak_db_over_frames(tree, 30)
	AudioServer.remove_bus_effect(bidx, 0)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await tree.process_frame
		probe.drain()
	var without: float = await probe.measure_peak_db_over_frames(tree, 30)
	print("[OpenDou] spike B5: tono -6 dBFS con OpenDouGainEffect(-12) mide %.1f dBFS; sin efecto %.1f" % [with_fx, without])
	# _tone() tiene pico -6 dBFS y el reproductor -6 dB: -12 nominal.
	a.approx(without, -12.0, "sin efecto el tono mide -12 dBFS", 0.6)
	a.approx(with_fx, without - 12.0, "el efecto nativo aplica -12 dB en el bus", 0.6)
	player.stop()
	tree.root.remove_child(player); player.free()
	probe.teardown()
	return a
