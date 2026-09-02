class_name TestGameSyncs
extends RefCounted

const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const GameSyncManagerClass = preload("res://addons/opendou/runtime/game_sync_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: O(1) LUT Baking and Fast Evaluation
	var curve = Curve.new()
	curve.min_value = -80.0
	curve.max_value = 0.0
	curve.add_point(Vector2(0.0, -80.0))
	curve.add_point(Vector2(0.5, -20.0))
	curve.add_point(Vector2(1.0, 0.0))
	curve.bake()
	
	var binding = RTPCBindingClass.new(&"Volume", &"volume_db", curve, RTPCBindingClass.Operation.ADD, 0.0, 100.0)
	binding.bake_lut(256)
	
	# evaluate() ya consulta la LUT horneada por bake_lut(): la aceleracion O(1)
	# existe, solo fallaba el nombre del metodo que este test invocaba.
	var lut_val_0 = binding.evaluate(0.0)
	var lut_val_50 = binding.evaluate(50.0)
	var lut_val_100 = binding.evaluate(100.0)
	
	# La LUT cuantiza la curva en 256 entradas, asi que el valor devuelto no puede
	# ser exactamente el de la curva: en el punto medio da -20.00136. Exigir
	# igualdad exacta a una tabla de consulta es la asercion equivocada; se
	# comprueba dentro del error de cuantizacion, que sigue detectando cualquier
	# regresion real de la curva.
	const LUT_TOLERANCE := 0.05
	if absf(lut_val_0 - (-80.0)) > LUT_TOLERANCE:
		failures.append("Test 1a Failed: LUT 0%% expected -80.0, got %f" % lut_val_0)
	if absf(lut_val_50 - (-20.0)) > LUT_TOLERANCE:
		failures.append("Test 1b Failed: LUT 50%% expected -20.0, got %f" % lut_val_50)
	if not is_equal_approx(lut_val_100, 0.0):
		failures.append("Test 1c Failed: LUT 100%% expected 0.0, got %f" % lut_val_100)
		
	# Test 2: GameSyncManager RTPCs
	var sync_mgr = GameSyncManagerClass.new()
	sync_mgr.set_rtpc(&"MasterVolume", 10.0, true)
	if not is_equal_approx(sync_mgr.get_rtpc(&"MasterVolume"), 10.0):
		failures.append("Test 2 Failed: Expected RTPC MasterVolume = 10.0")
		
	# Test 3: State Transitions with Crossfade Duration
	sync_mgr.set_state(&"GameState", &"Explore", 0.0) # Immediate
	if sync_mgr.get_state(&"GameState") != &"Explore" or sync_mgr.get_state_transition_weight(&"GameState") != 1.0:
		failures.append("Test 3a Failed: Immediate state change expected weight 1.0")
		
	sync_mgr.set_state(&"GameState", &"Combat", 2.0) # 2.0s transition
	if sync_mgr.get_state(&"GameState") != &"Combat":
		failures.append("Test 3b Failed: State name should immediately reflect target 'Combat'")
	if sync_mgr.get_state_transition_weight(&"GameState") != 0.0:
		failures.append("Test 3c Failed: Transition weight at start should be 0.0")
		
	sync_mgr.process(1.0) # Advance 1.0s (50% of 2.0s)
	if not is_equal_approx(sync_mgr.get_state_transition_weight(&"GameState"), 0.5):
		failures.append("Test 3d Failed: Transition weight at 50%% expected 0.5, got %f" % sync_mgr.get_state_transition_weight(&"GameState"))
		
	sync_mgr.process(1.0) # Advance another 1.0s (100%)
	if not is_equal_approx(sync_mgr.get_state_transition_weight(&"GameState"), 1.0):
		failures.append("Test 3e Failed: Transition weight at end expected 1.0, got %f" % sync_mgr.get_state_transition_weight(&"GameState"))
		
	# Test 4: Entity-Scoped Switches vs Global Switches
	var dummy_node_a = Node.new()
	var dummy_node_b = Node.new()
	
	sync_mgr.set_switch(&"Surface", &"Concrete") # Global default
	sync_mgr.set_switch(&"Surface", &"Water", dummy_node_a) # Node A only
	
	if sync_mgr.get_switch(&"Surface", dummy_node_a) != &"Water":
		failures.append("Test 4a Failed: Node A should have switch 'Water'")
	if sync_mgr.get_switch(&"Surface", dummy_node_b) != &"Concrete":
		failures.append("Test 4b Failed: Node B should fallback to global switch 'Concrete'")
		
	dummy_node_a.free()
	dummy_node_b.free()
	
	# Test 5: Triggers and Callbacks
	var trigger_fired: Array[bool] = [false]
	var cb = func(trig_name: StringName) -> void:
		if trig_name == &"Level_Up":
			trigger_fired[0] = true
			
	sync_mgr.register_trigger_listener(&"Level_Up", cb)
	sync_mgr.post_trigger(&"Level_Up")
	
	if not trigger_fired[0]:
		failures.append("Test 5 Failed: Trigger callback was not called upon post_trigger")
		
	return failures
