extends SceneTree

## Sondeo: corre solo TestGamePresets y, si se pide, vuelca los presets del juego
## a WAV para escucharlos.
##
##     Godot --headless --path . --script tools/probe_game_presets.gd
##     OPENDOU_RENDER_DIR=/ruta Godot --headless --path . --script tools/probe_game_presets.gd
##
## Imprime "N pasaron, M fallaron" y sale con 0 si M == 0.

const TestGamePresetsClass = preload("res://tests/test_game_presets.gd")
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")


func _initialize() -> void:
	var failures: Array[String] = TestGamePresetsClass.run_all()
	for f in failures:
		print("  FALLO: %s" % f)
	var total: int = TestGamePresetsClass.last_assertions
	print("%d pasaron, %d fallaron" % [total - failures.size(), failures.size()])

	var dir: String = OS.get_environment("OPENDOU_RENDER_DIR")
	if not dir.is_empty():
		_render(dir)

	quit(0 if failures.is_empty() else 1)


func _render(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var registry = SynthPresetRegistryClass.get_singleton()
	var count := 0
	for name in registry.get_preset_names():
		if not registry.get_preset_category(name).begins_with("Game/"):
			continue
		var wav: AudioStreamWAV = registry.get_preset_stream(name, absi(hash(str(name))))
		var path := dir.path_join("%s.wav" % str(name))
		var err := wav.save_to_wav(path)
		if err != OK:
			print("  no se pudo guardar %s (%d)" % [path, err])
		else:
			count += 1
	print("%d WAV en %s" % [count, dir])
