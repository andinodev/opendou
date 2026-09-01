class_name TestEarlyReflections
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ReflectionDispatcherClass = preload("res://addons/opendou/runtime/reflection_dispatcher.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("early_reflections")

	var pool = NativePlayerPoolClass.new(16)
	tree.root.add_child(pool)

	# Una sala cerrada de cuerpos estaticos para que haya superficies que reflejar.
	var room := Node3D.new()
	tree.root.add_child(room)
	for spec in [
		{"pos": Vector3(0, 0, -6), "size": Vector3(12, 6, 0.5)},
		{"pos": Vector3(0, 0, 6), "size": Vector3(12, 6, 0.5)},
		{"pos": Vector3(-6, 0, 0), "size": Vector3(0.5, 6, 12)},
		{"pos": Vector3(6, 0, 0), "size": Vector3(0.5, 6, 12)},
	]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec["size"]
		shape.shape = box
		body.position = spec["pos"]
		body.add_child(shape)
		room.add_child(body)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	var dispatcher = ReflectionDispatcherClass.new()
	dispatcher.set_player_pool(pool)
	dispatcher.max_reflections_per_voice = 2
	dispatcher.max_total_reflections = 4
	dispatcher.min_retrace_interval_sec = 0.0

	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.6, false)
	var def = AudioEventDefClass.new(&"Reflected", tone)
	var inst = EventInstanceClass.new(def)
	inst.set_position(Vector3.ZERO)
	inst.play()

	var emitted: int = dispatcher.dispatch(inst, Vector3(2.0, 0.0, 2.0), room.get_world_3d())
	a.gt(float(emitted), 0.0, "se emite al menos una reflexion en una sala cerrada")
	a.ok(emitted <= dispatcher.max_reflections_per_voice, "se respeta el techo por voz")

	# El techo global no se puede superar por muchas voces que haya.
	for i in range(10):
		var d2 = AudioEventDefClass.new(&"R2", tone)
		var i2 = EventInstanceClass.new(d2)
		i2.set_position(Vector3(1.0, 0.0, 1.0))
		i2.play()
		dispatcher.dispatch(i2, Vector3(2.0, 0.0, 2.0), room.get_world_3d())
	a.ok(dispatcher.active_reflection_count <= dispatcher.max_total_reflections,
		"se respeta el techo global de reflexiones")

	# Sin mundo fisico no se emite nada, en lugar de fallar.
	dispatcher.release_all()
	a.eq(dispatcher.dispatch(inst, Vector3.ZERO, null), 0, "sin mundo 3D no emite reflexiones")

	dispatcher.release_all()
	a.eq(dispatcher.active_reflection_count, 0, "release_all devuelve todas las voces")

	tree.root.remove_child(room)
	room.free()
	tree.root.remove_child(pool)
	pool.free()
	return a
