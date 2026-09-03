class_name TestSpeakerOutputMode
extends RefCounted

## Fase 13: en modo altavoces con un dispositivo surround, el anfitrion deja de estar
## neutralizado y el stream pasa a MONO_PASS: Godot panea la senal procesada. En estereo, todo
## como antes. La suite no puede oir 5.1: afirma la decision.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func _hosts(manager) -> Dictionary:
	var pans: Array = []
	var modes: Array = []
	manager.player_pool.for_each_host(func(p): pans.append(p.panning_strength); modes.append(int(p.stream.output_mode)))
	return {"pans": pans, "modes": modes}

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("speaker_output_mode")
	if not BackendClass.native_available():
		print("[OpenDou] extension nativa AUSENTE: modo de salida omitido")
		return a
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "steam_audio")
	var cam := TestParityClass.make_listener_camera(tree)
	# Un anfitrion vivo para observar: se pide y se devuelve al pool.
	var host = manager.player_pool.acquire(manager.player_pool.PlayerKind.BINAURAL_3D)
	manager.player_pool.release(host)
	manager.surround_available = false
	manager.spatial_settings.set_output("speakers")
	var st: Dictionary = _hosts(manager)
	a.ok(st.pans.size() >= 1, "hay anfitriones que observar")
	a.ok(st.pans.all(func(x): return is_zero_approx(x)), "estereo + altavoces: anfitrion neutralizado (paneo 0)")
	a.ok(st.modes.all(func(m): return m == 1), "y el stream en altavoces propios (1)")
	manager.surround_available = true
	manager._apply_spatial_settings()
	st = _hosts(manager)
	a.ok(st.pans.all(func(x): return is_equal_approx(x, 1.0)), "surround + altavoces: Godot panea (paneo 1)")
	a.ok(st.modes.all(func(m): return m == 2), "y el stream en MONO_PASS (2)")
	manager.spatial_settings.set_output("headphones")
	st = _hosts(manager)
	a.ok(st.pans.all(func(x): return is_zero_approx(x)), "audifonos: neutralizado otra vez")
	a.ok(st.modes.all(func(m): return m == 0), "y HRTF (0)")
	print("[OpenDou] modo de salida: %d anfitriones observados" % st.pans.size())
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
