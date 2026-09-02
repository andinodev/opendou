class_name TestSpatialSettings
extends RefCounted

## Fase 7B: los ajustes de espacializacion del jugador persisten en user:// y se sanean.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spatial_settings")
	var path := "user://opendou_audio_test.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var s = SettingsClass.new()
	a.eq(s.hrtf, "default", "HRTF por defecto")
	a.approx(s.blend, 1.0, "mezcla por defecto 1.0")
	a.eq(s.output, "headphones", "salida por defecto audifonos")

	# Cargar sin archivo deja los defectos y no falla.
	s.load_from_disk(path)
	a.eq(s.output, "headphones", "cargar sin archivo conserva los defectos")

	var changes: Array[int] = [0]
	s.changed.connect(func(): changes[0] += 1)
	s.set_blend(0.35)
	s.set_output("speakers")
	s.set_hrtf("user://mi_cabeza.sofa")
	a.eq(changes[0], 3, "cada cambio emite changed")
	a.eq(s.save_to_disk(path), OK, "guarda en disco")

	var s2 = SettingsClass.new()
	s2.load_from_disk(path)
	a.approx(s2.blend, 0.35, "recarga la mezcla")
	a.eq(s2.output, "speakers", "recarga la salida")
	a.eq(s2.hrtf, "user://mi_cabeza.sofa", "recarga el HRTF")

	# Valores invalidos se sanean: la mezcla se acota, la salida vuelve a audifonos.
	s2.set_blend(7.0)
	a.approx(s2.blend, 1.0, "la mezcla se acota a 1")
	s2.set_output("subwoofer")
	a.eq(s2.output, "headphones", "una salida desconocida vuelve a audifonos")
	s2.set_hrtf("")
	a.eq(s2.hrtf, "default", "un HRTF vacio vuelve a default")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
