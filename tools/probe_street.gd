extends SceneTree
## Sondeo: la demo de la calle tras 20 cuadros: portal elegido para la musica, corte y voces.
func _init() -> void:
	await process_frame
	var wind_on: bool = OS.get_cmdline_user_args().is_empty() or OS.get_cmdline_user_args()[0] != "off"
	var manager = root.get_node_or_null("OpenDou")
	var packed: PackedScene = load("res://scenes/demos/street/street_demo.tscn")
	var demo = packed.instantiate()
	demo.leaves_count = 12
	root.add_child(demo)
	if not wind_on:
		demo.get_node("Wind").auto_play_event = false
		demo.get_node("Wind").stop_event()
	await process_frame
	await physics_frame
	await process_frame
	var ac = manager.spatial_acoustics
	var portals: Dictionary = {}
	for p_name in ac.portals:
		portals[p_name] = snappedf(ac.portals[p_name].open_factor, 0.01)
	var music = demo.music_emitter.active_instance
	music.occlusion_smoothing_speed = 200.0
	for k in range(4):
		for i in range(5):
			await process_frame
		var names: Array = []
		for inst in manager.active_instances:
			if inst != null and inst.definition != null:
				names.append("%s@%s%s" % [String(inst.definition.event_name), str(inst.emitter_position.snapped(Vector3(0.1, 0.1, 0.1))), "" if inst.assigned_channel_id >= 0 else "(virtual)"])
		print("viento %s | cuadro %d | musica: room_path %s aparente %s lpf %.0f | voces %d: %s" % [str(wind_on), (k + 1) * 5, str(music.room_path_active), str(music.target_apparent_position), music.current_spatial_lpf, names.size(), str(names)])
	print("portales ", portales_str(portals), " | oyente ", manager.active_listener_position)
	manager.stop_all()
	root.remove_child(demo); demo.free()
	quit()
func portales_str(p: Dictionary) -> String:
	return str(p)
