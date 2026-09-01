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

	# Los presets de sintesis son contenido del ADDON, no datos del usuario: copiar
	# solo addons/opendou/ a otro proyecto tiene que dejarte con presets.
	a.ok(FileAccess.file_exists(DataPathsClass.addon_default_path(DataPathsClass.SYNTH_PRESETS)),
		"el addon envia sus presets de sintesis")

	# Y una instalacion limpia resuelve a un archivo valido para syncs y suites.
	for dn in [DataPathsClass.GAME_SYNCS, DataPathsClass.MUSIC_SUITES]:
		a.ok(FileAccess.file_exists(DataPathsClass.addon_default_path(dn)),
			"el addon envia un default para '%s'" % dn)

	# El registro carga presets sin que nadie le diga de donde.
	var RegistryClass = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	var reg = RegistryClass.get_singleton()
	a.ok(reg != null, "el registro de presets existe")
	if reg != null:
		a.gt(float(reg.get_preset_names().size()), 0.0, "el registro tiene presets tras resolver solo")

	# Ninguna ruta hardcodeada queda en el codigo del addon.
	var offenders: Array[String] = []
	for path in ["res://addons/opendou/runtime/synth/synth_preset_registry.gd",
			"res://addons/opendou/runtime/spatial/acoustic_material_registry.gd",
			"res://addons/opendou/nodes/opendou_music_player.gd",
			"res://addons/opendou/editor/opendou_game_syncs_panel.gd",
			"res://addons/opendou/editor/opendou_music_timeline.gd"]:
		var f2 = FileAccess.open(path, FileAccess.READ)
		if f2 == null:
			continue
		var text: String = f2.get_as_text()
		f2.close()
		if text.contains('"res://opendou_'):
			offenders.append(path)
	a.eq(offenders.size(), 0, "sin rutas res://opendou_ hardcodeadas, sobran: %s" % str(offenders))

	# El aviso al faltar el archivo. push_warning() no es capturable desde GDScript,
	# asi que se comprueba por las dos vias disponibles: que la funcion devuelve
	# false ante un archivo inexistente, y que el codigo contiene un aviso que
	# nombra la consecuencia.
	if reg != null:
		a.eq(reg.load_presets("res://__archivo_que_no_existe__.json"), false,
			"load_presets devuelve false ante un archivo inexistente")
	var rf = FileAccess.open("res://addons/opendou/runtime/synth/synth_preset_registry.gd", FileAccess.READ)
	if rf != null:
		var rsrc: String = rf.get_as_text()
		rf.close()
		a.ok(rsrc.contains("push_warning"), "load_presets avisa en lugar de callar")
		a.ok(rsrc.contains("desplegable"), "el aviso nombra la consecuencia, no solo el fallo")

	# Recargar los presets de verdad para no dejar el registro vacio para otras
	# suites: load_presets() los ha sobreescrito con nada.
	if reg != null:
		reg.load_presets()

	return a
