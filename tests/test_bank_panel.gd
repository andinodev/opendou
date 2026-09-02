class_name TestBankPanel
extends RefCounted

const OpenDouBankPanelClass = preload("res://addons/opendou/editor/opendou_bank_panel.gd")

## Este test estaba escrito contra una API que nunca existio (file_list,
## compile_soundbank, _on_add_stream_pressed): abortaba en su primera linea en
## cada ejecucion y no verificaba nada. Ahora prueba la API real del panel.
static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var panel = OpenDouBankPanelClass.new()

	# Test 1: el panel arranca con los streams de muestra en su modelo
	var initial: int = panel.get_stream_count()
	if initial <= 0:
		failures.append("Test 1 Failed: se esperaban streams de muestra, hay %d" % initial)

	# Test 2: anadir streams crece el modelo y el arbol que lo dibuja
	panel._on_add_stream_pressed()
	panel._on_add_stream_pressed()
	if panel.get_stream_count() != initial + 2:
		failures.append("Test 2 Failed: se esperaban %d streams, hay %d" % [initial + 2, panel.get_stream_count()])
	if panel.asset_tree == null:
		failures.append("Test 2b Failed: asset_tree no existe")

	# Test 3: compilar escribe un banco ODBK real en disco
	panel.bank_name_edit.text = "UITestBank"
	panel.output_path_edit.text = "user://ui_test.bank"
	panel.prefetch_spin.value = 16.0

	var success: bool = panel.compile_soundbank()
	if not success or not FileAccess.file_exists("user://ui_test.bank"):
		failures.append("Test 3 Failed: la compilacion del banco desde el panel fallo")

	# Test 4: sin ruta de salida no se compila y se dice que no
	panel.output_path_edit.text = ""
	if panel.compile_soundbank():
		failures.append("Test 4 Failed: compilar sin ruta deberia devolver false")

	panel.free()
	return failures
