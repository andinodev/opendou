# Fase 16 — «La presa» — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una escena grande y viva (`scenes/demos/presa/`) que instancia todos los nodos del plugin (salvo el 2D) y afirma con audio medido cada una de sus diez tesis.

**Architecture:** `.tscn` generado una vez por `tools/gen_presa_tscn.py`; `presa_demo.gd` autora los eventos sintetizados y la vida (tormenta, camión, vigilantes, cascotes, compuerta, megafonía); `.probes` precocinado por `tools/bake_presa_probes.gd`; test en `test_demo_scenes.gd`; guardas actualizadas.

**Spec:** `docs/superpowers/specs/2026-09-03-fase16-la-presa-design.md`

## Global Constraints

- Regla 04: los nodos van en la escena; el código solo hace lo dinámico y los streams.
- Commit gate: `./run_tests.sh` con código de salida 0.
- Sin assets de audio: `AudioSynthesizer`.

---

### Task 1: Geometría y composición (`.tscn` generado)

- [ ] `tools/gen_presa_tscn.py`: emite `presa_demo.tscn` con valle, presa, nave, control, galería en L, galería inundada, aliviadero, compuerta (grupo dinámico), carretera (`Path3D`), río (`Curve3D`), salas/portales/reflectores/áreas/volúmenes (con `AcousticEnvironment` como sub-recursos), emisores, rigs (jugador con `OpenDouListener3D`, dos NPC), HUD (cartel, monitor, indicador), depurador, bake, menú de pausa, luces. ≥ 300 nodos.
- [ ] `presa_demo.gd` mínimo (buses, eventos, teclas) para que la escena cargue sin errores.
- [ ] Guardas: `SCENES`, `COMPOSITION` (min 300, requires: todos), `EXPECTED_UNCOVERED` = solo el 2D; tarjeta en el hub.
- [ ] Suite verde; commit `"Fase 16: la presa, composicion de la escena (geometria, salas, emisores, HUD)"`.

### Task 2: Vida

- [ ] Tormenta (estados, `StormIntensity`, truenos con retardo, lluvia, música), camión en ronda con RPM, vigilantes que oyen y hablan, cascotes, compuerta con G, megafonía con programa, ranas/grillos que callan con la lluvia.
- [ ] Suite verde; commit `"Fase 16: la presa cobra vida (tormenta, camion, vigilantes, cascotes, compuerta, megafonia)"`.

### Task 3: Sondas

- [ ] `tools/bake_presa_probes.gd` (headless): carga la escena, `bake_probes()` con `probe_bounds` en la galería y la nave, guarda `presa_demo.probes`; `.gitattributes` ya lo marca binario.
- [ ] Commit `"Fase 16: sondas de la presa precocinadas"`.

### Task 4: Tests

- [ ] `run_presa_async` con las afirmaciones de §4 del spec; presupuesto LUFS.
- [ ] Suite verde; commit `"Fase 16: la presa afirma sus diez tesis con audio medido"`.

### Task 5: Documentos

- [ ] `funcionalidades.md` (demo nueva, §3.5), `AGENTS.md` (observación 55), `current.md`, spec §12, `observaciones` C2 pagada, roadmap.
- [ ] Commit `"Fase 16: documentos al dia; observacion 55"`.
