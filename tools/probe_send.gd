extends SceneTree
## Sondeo del envio propio: una caja CONVOLUTION, una voz dentro, contadores del acumulador.
const TP = preload("res://tests/test_backend_parity.gd")
const TR = preload("res://tests/test_reflections_thread.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const RoomScript = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
func _init() -> void:
	await process_frame
	var manager = TP.make_manager(self, "steam_audio")
	var cam := TP.make_listener_camera(self)
	cam.global_position = Vector3(0, 1.5, 0)
	var walls: Array = TR.make_box_room(self, &"Concrete")
	var bake = BakeScript.new(); bake.auto_bake_on_ready = false; root.add_child(bake); bake.bake_geometry(root)
	var room = RoomScript.new(); room.room_name = &"Caja"; room.reverb_mode = RoomScript.ReverbMode.CONVOLUTION; room.reverb_send_amount = 1.0
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(6, 3, 6); shape.shape = box; room.add_child(shape)
	room.set_acoustics_manager(manager.spatial_acoustics); root.add_child(room); room.global_position = Vector3(0, 1.5, 0)
	var bus: StringName = room.get_assigned_reverb_bus()
	var idx: int = AudioServer.get_bus_index(String(bus))
	var fx_names: Array = []
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var fx = AudioServer.get_bus_effect(idx, e)
		fx_names.append("%s(%s dry=%s)" % [fx.get_class(), fx.resource_name, str(fx.get("dry"))])
	print("bus ", bus, " efectos ", fx_names, " send_id ", room.runtime_room.send_id, " enruta godot ", room.reverb_bus_enabled, " buffer ", ProjectSettings.get_setting("audio/driver/output_latency"), " mix ", AudioServer.get_mix_rate())
	var sid: int = room.runtime_room.send_id
	print("stats antes: ", ClassDB.class_call_static("OpenDouSendBus", "stats", sid))
	TP.ensure_bus()
	var def = DefClass.new(&"T", load("res://tests/test_emitter_physics.gd")._tone(1000.0, 0.3, -3.0)); def.is_looping = false; def.stream_length = 0.3; def.target_bus = TP.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null); inst.set_position(Vector3(1, 1.5, -1))
	for k in range(5):
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 200: await process_frame
		var pk: float = AudioServer.get_bus_peak_volume_left_db(idx, 0)
		print("t=%d ms stats %s | pico bus reverb %.1f dB | canal send %d gain %.2f" % [(k + 1) * 200, str(ClassDB.class_call_static("OpenDouSendBus", "stats", sid)), pk, manager.voice_pool.get_channel(inst.assigned_channel_id).send_id if inst.assigned_channel_id >= 0 else -9, manager.voice_pool.get_channel(inst.assigned_channel_id).send_gain if inst.assigned_channel_id >= 0 else 0.0])
	manager.stop_all()
	root.remove_child(room); room.free(); root.remove_child(bake); bake.free()
	for w in walls: root.remove_child(w); w.free()
	root.remove_child(cam); cam.free(); root.remove_child(manager); manager.free()
	quit()
