extends SceneTree
## Precocina las sondas de «La presa» (Fase 16) y guarda presa_demo.probes junto a la escena.
##     Godot --headless --path . --script tools/bake_presa_probes.gd
func _init() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/demos/presa/presa_demo.tscn")
	var demo = packed.instantiate()
	root.add_child(demo)
	await process_frame
	await physics_frame
	var bake = demo.get_node("AcousticBake")
	print("bake: %d triangulos, %d dinamicos, escena %s" % [bake.get_baked_triangle_count(), int(bake.stats.get("dynamic_count", 0)), str(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready"))])
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = bake.bake_probes()
	print("sondas: %s en %d ms" % [str(r), Time.get_ticks_msec() - t0])
	var mgr = root.get_node_or_null("OpenDou")
	if mgr != null:
		mgr.stop_all()
	root.remove_child(demo); demo.free()
	quit()
