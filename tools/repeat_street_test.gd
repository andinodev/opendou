extends SceneTree

## Observacion 43: el test de la calle fallaba de forma intermitente con el origen aparente
## en la puerta cerrada en lugar de la ventana. Esta herramienta lo corre N veces seguidas y
## deja a la vista lo que el despachador veia en el momento de decidir. No es parte de la
## suite; se usa para cazar la causa y, despues, para comprobar que sigue cazada.
##
##     OPENDOU_TRACE_OBS43=1 Godot --headless --path . -s tools/repeat_street_test.gd

const RUNS: int = 10

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var TestClass = load("res://tests/test_demo_scenes.gd")
	var manager = root.get_node_or_null("OpenDou")
	var failures: int = 0
	for i in range(RUNS):
		var a = await TestClass.run_street_async(self)
		var failed: bool = not a.failures.is_empty()
		if failed:
			failures += 1
		# Lo que el grafo tiene registrado AL TERMINAR la corrida (la escena ya se libero y
		# debio desregistrar todo: si queda algo, es una fuga de registro).
		var ac = manager.spatial_acoustics
		var portals: Dictionary = {}
		for p_name in ac.portals:
			portals[p_name] = snappedf(ac.portals[p_name].open_factor, 0.01)
		print("[obs43] corrida %d: %s | salas restantes=%s portales restantes=%s generacion=%d" % [
			i + 1, "FALLO" if failed else "ok", ac.rooms.keys(), portals,
			ac.graph_generation if "graph_generation" in ac else -1])
		for f in a.failures:
			print("[obs43]    - ", f)
	print("[obs43] fallos: %d de %d" % [failures, RUNS])
	quit(1 if failures > 0 else 0)
