extends SceneTree

## Sondeo generico: corre UN test de la suite (una clase con `static func run_all()`)
## y sale con su resultado, sin arrancar test_all (150 s) ni run_tests.ps1.
##
##     OPENDOU_TEST=res://tests/test_synth_nature.gd Godot --headless --path . --script tools/probe_one_test.gd
##
## Imprime "N pasaron, M fallaron" (N es el numero de fallos posibles solo cuando la
## clase expone `last_assertions`; si no, cuenta 1 por test) y sale con 0 si M == 0.


func _initialize() -> void:
	var path: String = OS.get_environment("OPENDOU_TEST")
	if path.is_empty():
		print("Falta OPENDOU_TEST=res://tests/test_x.gd")
		quit(2)
		return
	var script = load(path)
	if script == null:
		print("No se pudo cargar %s" % path)
		quit(2)
		return
	var result = script.run_all()
	var failures: Array = []
	var total: int = 1
	if result is Array:
		failures = result
		total = int(script.get("last_assertions")) if "last_assertions" in script else maxi(1, failures.size())
	elif result != null and "failures" in result:
		failures = result.failures
		total = int(result.get("assertions_run")) if "assertions_run" in result else maxi(1, failures.size())
	for f in failures:
		print("  FALLO: %s" % str(f))
	print("%d pasaron, %d fallaron" % [maxi(total - failures.size(), 0), failures.size()])
	quit(0 if failures.is_empty() else 1)
