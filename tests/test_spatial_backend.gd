class_name TestSpatialBackend
extends RefCounted

## Fase 7B: la regla que elige el backend espacial al arrancar, y su exposicion en el manager.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spatial_backend")
	# auto: depende de si la extension esta.
	a.eq(BackendClass.resolve("auto", true), &"steam_audio", "auto con extension -> steam_audio")
	a.eq(BackendClass.resolve("auto", false), &"godot", "auto sin extension -> godot")
	# forzado a godot: ignora la extension.
	a.eq(BackendClass.resolve("godot", true), &"godot", "godot forzado aunque haya extension")
	# forzado a steam_audio sin extension: cae a godot (y lo dice por consola).
	a.eq(BackendClass.resolve("steam_audio", false), &"godot", "steam_audio sin extension cae a godot")
	a.eq(BackendClass.resolve("steam_audio", true), &"steam_audio", "steam_audio con extension")
	# valores raros: como auto.
	a.eq(BackendClass.resolve("lo_que_sea", false), &"godot", "valor desconocido se trata como auto")
	# El ajuste de proyecto existe con su defecto.
	a.eq(BackendClass.read_setting(), "auto", "el ajuste de proyecto vale auto por defecto")

	# El manager lo expone y coincide con la regla.
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	var expected: StringName = BackendClass.resolve(BackendClass.read_setting(), BackendClass.native_available())
	a.eq(manager.spatial_backend, expected, "el manager expone el backend resuelto")
	a.eq(manager.is_steam_audio_backend(), expected == &"steam_audio", "is_steam_audio_backend coincide")
	manager.free()
	return a
