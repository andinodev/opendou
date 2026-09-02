class_name TestListener3D
extends RefCounted

## Fase 10: el oyente como nodo. Parte A: radio de cabeza y velocidad del sonido en el C++.
## Parte B: el nodo OpenDouListener3D y el resolver.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const BUS: StringName = &"ListenerProbe"

static func _native() -> bool:
	return ClassDB.class_exists("OpenDouSpatialStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

static func run_head_radius_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("listener_head_radius")
	if not _native():
		print("[OpenDou] extension nativa AUSENTE: radio de cabeza omitido")
		return a
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_head_radius_m")), 0.0875, "radio por defecto 8.75 cm", 0.0001)
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_speed_of_sound_mps")), 343.0, "velocidad por defecto 343", 0.01)
	if AudioServer.get_bus_index(String(BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(BUS))
		AudioServer.set_bus_send(idx, "Master")
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	stream.spatialize = true
	stream.spatial_blend = 1.0
	stream.direction = Vector3(1, 0, 0)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(BUS)
	player.volume_db = -6.0
	tree.root.add_child(player)
	player.play()
	var base := await TestBinauralClass._capture(tree, probe)
	var itd_base: float = stream.get_last_applied_itd_ms()
	var lag_base: int = TestBinauralClass._itd_lag(base.left, base.right)
	a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.175, 343.0)), "se acepta el radio doble")
	var doubled := await TestBinauralClass._capture(tree, probe)
	var itd_doubled: float = stream.get_last_applied_itd_ms()
	var lag_doubled: int = TestBinauralClass._itd_lag(doubled.left, doubled.right)
	print("[OpenDou] radio de cabeza: 8.75 cm -> ITD %.3f ms (lag %d); 17.5 cm -> %.3f ms (lag %d)" % [itd_base, lag_base, itd_doubled, lag_doubled])
	a.approx(itd_doubled / maxf(itd_base, 1e-6), 2.0, "el ITD aplicado a 90 grados se dobla", 0.1)
	a.ok(lag_doubled >= int(1.15 * lag_base), "y el retardo medido en la salida crece con el (%d -> %d muestras)" % [lag_base, lag_doubled])
	a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.0875, 1480.0)), "se acepta el agua")
	await TestBinauralClass._capture(tree, probe)
	var itd_water: float = stream.get_last_applied_itd_ms()
	a.lt(itd_water / maxf(itd_base, 1e-6), 0.25, "bajo el agua el ITD cae a menos de un cuarto (medido %.3f ms)" % itd_water)
	ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.0875, 343.0)
	a.eq(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 5.0, 343.0)), false, "un radio absurdo se rechaza")
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_head_radius_m")), 0.0875, "y no cambia nada", 0.0001)
	player.stop()
	tree.root.remove_child(player)
	player.free()
	probe.teardown()
	return a
