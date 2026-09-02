class_name TestAreaTrigger
extends RefCounted

## Fase 11: el area de parametros dispara un evento al entrar un cuerpo del grupo, con
## probabilidad, recarga y "una sola vez".

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AreaScript = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")

static func _body(tree: SceneTree, group: String) -> Node3D:
	var b := CharacterBody3D.new()
	if not group.is_empty():
		b.add_to_group(group)
	tree.root.add_child(b)
	return b

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("area_trigger")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var def = AudioEventDefClass.new(&"Bell", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.stream_length = 0.5
	manager.register_event_definition(def)
	var area = AreaScript.new()
	area.trigger_event = &"Bell"
	area.trigger_group = &"player"
	area.trigger_cooldown_sec = 0.3
	tree.root.add_child(area)
	area.set_event_manager(manager)
	var fired: Array = []
	area.triggered.connect(func(e, t): fired.append([e, t]))
	var player := _body(tree, "player")
	var crate := _body(tree, "")
	area.register_target_entered(player)
	a.eq(fired.size(), 1, "un cuerpo del grupo player dispara")
	a.eq(manager.active_instances.size(), 1, "y el evento suena")
	area.register_target_exited(player)
	area.register_target_entered(player)
	a.eq(fired.size(), 1, "volver a entrar antes de la recarga no dispara")
	area.register_target_exited(player)
	area.register_target_entered(crate)
	a.eq(fired.size(), 1, "un cuerpo sin el grupo no dispara")
	area.register_target_exited(crate)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 350:
		await tree.process_frame
	area.register_target_entered(player)
	a.eq(fired.size(), 2, "pasada la recarga, dispara otra vez")
	area.register_target_exited(player)
	area.trigger_once = true
	area.trigger_count = 0
	area.trigger_cooldown_sec = 0.0
	area.register_target_entered(player)
	area.register_target_exited(player)
	area.register_target_entered(player)
	a.eq(fired.size(), 3, "con trigger_once solo la primera entrada dispara")
	area.register_target_exited(player)
	area.trigger_once = false
	area.trigger_probability = 0.0
	area.register_target_entered(player)
	a.eq(fired.size(), 3, "con probabilidad 0, nunca")
	area.register_target_exited(player)
	manager.stop_all()
	for n in [player, crate, area]:
		tree.root.remove_child(n); n.free()
	tree.root.remove_child(manager); manager.free()
	return a
