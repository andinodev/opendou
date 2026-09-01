# Task 1 Brief: Physical Material Matrix & Mass-Law Calculation Engine (TASK-051)

## Files to touch:
- Create: `addons/opendou/runtime/spatial/acoustic_material_registry.gd`
- Create: `tests/test_spatial_acoustics_phase1.gd`
- Modify: `tests/test_all.gd`

## Testing Command:
- You can run tests using:
  `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  or
  `powershell.exe -ExecutionPolicy Bypass -File .\run_tests.ps1`
- Exit code 0 means PASS.

## Requirements:
1. Create `addons/opendou/runtime/spatial/acoustic_material_registry.gd`:
   - `@tool`, `class_name AcousticMaterialRegistry`, `extends RefCounted`.
   - Singleton pattern:
     ```gdscript
     static var _singleton: AcousticMaterialRegistry
     static func get_singleton() -> AcousticMaterialRegistry:
         if not _singleton:
             _singleton = AcousticMaterialRegistry.new()
         return _singleton
     ```
   - Canonical physical materials:
     * `"Concrete"`: `{"density": 2400.0, "resonance_lpf": 350.0, "absorption": 0.05}`
     * `"Stone"`: `{"density": 2400.0, "resonance_lpf": 350.0, "absorption": 0.05}`
     * `"Metal"`: `{"density": 7800.0, "resonance_lpf": 1200.0, "absorption": 0.02}`
     * `"Glass"`: `{"density": 2500.0, "resonance_lpf": 800.0, "absorption": 0.03}`
     * `"Wood"`: `{"density": 700.0, "resonance_lpf": 2000.0, "absorption": 0.15}`
     * `"Foliage"`: `{"density": 150.0, "resonance_lpf": 4500.0, "absorption": 0.85}`
     * `"Water"`: `{"density": 1000.0, "resonance_lpf": 600.0, "absorption": 0.01}`
     * `"Asphalt"`: `{"density": 2100.0, "resonance_lpf": 400.0, "absorption": 0.08}`
   - `func get_material(mat_name: StringName) -> Dictionary`:
     - Returns dictionary copy or fallback to Concrete if unknown.
   - `func calculate_transmission_loss(mat_name: StringName, thickness_meters: float, center_freq: float = 1000.0) -> Dictionary`:
     - Computes:
       $$\text{attenuation\_db} = \text{clampf}(20.0 \cdot \frac{\ln(\text{center\_freq} \cdot \text{density} \cdot \max(0.001, \text{thickness\_meters}))}{\ln(10.0)} - 45.0, 0.0, 36.0)$$
       $$\text{cutoff\_lpf} = \text{lerpf}(20000.0, \text{resonance\_lpf}, \text{clampf}(\text{thickness\_meters} / 0.5, 0.0, 1.0))$$
     - Returns `{"attenuation_db": attenuation_db, "cutoff_lpf": cutoff_lpf}`.
   - `func register_custom_material(mat_name: StringName, density: float, resonance_lpf: float, absorption: float) -> void`
   - `func load_from_json(path: String = "res://opendou_acoustic_materials.json") -> void` (gracefully ignores if file doesn't exist).

2. Create `tests/test_spatial_acoustics_phase1.gd`:
   - Test 1: Verify canonical materials in registry (`Concrete`, `Metal`, `Glass`, `Wood`, `Foliage`, `Water`, `Asphalt`) have valid density $> 0$, resonance LPF $> 0$, and absorption $\in [0, 1]$.
   - Test 2: Verify `calculate_transmission_loss` calculations:
     - 0.5m Concrete attenuation $> 0.5\text{m}$ Wood attenuation.
     - 0.5m Concrete cutoff LPF $\le 500\text{Hz}$.
     - 0.1m Wood cutoff LPF $> 5000\text{Hz}$.
     - Custom material registration and retrieval.

3. Update `tests/test_all.gd`:
   - Preload `TestSpatialAcousticsPhase1Class` and register test execution (`total_tests += 2`).

4. Run test runner and confirm 100% tests pass (exit code 0).
5. Commit:
   `git add addons/opendou/runtime/spatial/acoustic_material_registry.gd tests/test_spatial_acoustics_phase1.gd tests/test_all.gd`
   `git commit -m "feat(spatial): implement AcousticMaterialRegistry with physical mass-law transmission (Task 1 - TASK-051)"`
