extends SceneTree
const TestConv = preload("res://tests/test_convolution_reverb.gd")
func _init() -> void:
	await process_frame
	for k in range(4):
		var r: Dictionary = await TestConv._measure(self, "steam_audio", &"Concrete", 1.0)
		print("hormigon %d: tono %.1f cola %.1f rt60 %.2f muestras %d" % [k, r.tone_db, r.tail_db, r.rt60.y, r.samples])
	for k in range(2):
		var r: Dictionary = await TestConv._measure(self, "steam_audio", &"Foliage", 1.0)
		print("follaje %d: tono %.1f cola %.1f rt60 %.2f muestras %d" % [k, r.tone_db, r.tail_db, r.rt60.y, r.samples])
	quit()
