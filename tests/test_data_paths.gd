class_name TestDataPaths
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const DataPathsClass = preload("res://addons/opendou/runtime/data_paths.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("data_paths")

	# Las rutas se construyen con los nombres de archivo que el proyecto ya usa.
	a.eq(DataPathsClass.project_override_path(DataPathsClass.SYNTH_PRESETS),
		"res://opendou_synth_presets.json", "el override de presets conserva su nombre")
	a.eq(DataPathsClass.project_override_path(DataPathsClass.GAME_SYNCS),
		"res://opendou_syncs.json", "el override de syncs conserva su nombre")
	a.eq(DataPathsClass.addon_default_path(DataPathsClass.SYNTH_PRESETS),
		"res://addons/opendou/data/synth_presets.json", "el default vive dentro del addon")

	# Precedencia: si existe el override del proyecto, gana.
	var probe_name := "__probe_data_paths__"
	var override_path: String = DataPathsClass.project_override_path(probe_name)
	var default_path: String = DataPathsClass.addon_default_path(probe_name)

	# Sin ninguno de los dos, cadena vacia: el consumidor cae a su default en codigo.
	a.eq(DataPathsClass.resolve(probe_name), "", "sin archivos resuelve a cadena vacia")

	# Solo el default del addon.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DataPathsClass.ADDON_DATA_DIR))
	var f = FileAccess.open(default_path, FileAccess.WRITE)
	if f == null:
		a.ok(false, "no se pudo crear el default de sonda en %s" % default_path)
		return a
	f.store_string("{}")
	f.close()
	a.eq(DataPathsClass.resolve(probe_name), default_path, "con solo el default del addon, resuelve a el")

	# Con override del proyecto, el override gana.
	var g = FileAccess.open(override_path, FileAccess.WRITE)
	if g != null:
		g.store_string("{}")
		g.close()
		a.eq(DataPathsClass.resolve(probe_name), override_path, "el override del proyecto tiene prioridad")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path))
	else:
		a.ok(false, "no se pudo crear el override de sonda")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(default_path))

	# Los cuatro nombres canonicos resuelven sin reventar, exista el archivo o no.
	for data_name in [DataPathsClass.SYNTH_PRESETS, DataPathsClass.ACOUSTIC_MATERIALS,
			DataPathsClass.MUSIC_SUITES, DataPathsClass.GAME_SYNCS]:
		var r: String = DataPathsClass.resolve(data_name)
		a.ok(r.is_empty() or r.begins_with("res://"), "resolve('%s') devuelve ruta valida o vacia" % data_name)

	return a
