extends SceneTree
func _init() -> void:
	await process_frame
	var a = await load("res://tests/test_emitter_physics.gd").run_near_field_async(self)
	print("near_field fallos: ", a.failures)
	quit()
