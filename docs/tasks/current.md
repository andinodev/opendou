# ⚡ Tareas Activas (Current Tasks)

Este archivo contiene el trabajo que se encuentra en desarrollo en la sesión o sprint actual.

---

## 📌 Tarea Reciente: `TASK-020` - Escenas de Demostración AAA y Sandbox (Divididas por Capacidades)

* **ID:** `TASK-020`
* **Fecha de Inicio:** 2026-08-29
* **Estado:** ✅ Completada y Verificada
* **Prioridad:** Alta (Validación Interactiva de Capacidades AAA)
* **Módulo:** `scenes/demos/`
* **Referencias:** 
  * [docs/specs/spec_demo_suite.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_demo_suite.md)

### 📋 Checklist de Subtareas
- [x] **1. `TASK-020.1`: Demo 01 - Macro-Acústica 3D (Rooms, Portals & Difracción):**
  - [x] Implementado `scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.gd` con cálculo de origen aparente y filtrado LPF interactivo al abrir/cerrar puerta.
- [x] **2. `TASK-020.2`: Demo 02 - Estrés de Voces y Seguimiento Virtual:**
  - [x] Implementado `scenes/demos/02_massive_voice_stress/demo_voice_stress.gd` con 250 emisores activos, pool de 16 canales físicos y virtual tracking.
- [x] **3. `TASK-020.3`: Demo 03 - Pisadas y Switch de Superficies 3D:**
  - [x] Implementado `scenes/demos/03_surface_switches_3d/demo_surface_switches.gd` con selección por `AudioSwitchContainer` y shuffle anti-repetición (Madera, Concreto, Metal, Agua).
- [x] **4. `TASK-020.4`: Demo 04 - Motor de Vehículo y Crossfade RPM:**
  - [x] Implementado `scenes/demos/04_vehicle_blend_rpm/demo_vehicle_rpm.gd` con tacómetro y `AudioBlendContainer` con curvas LUT $O(1)$.
- [x] **5. `TASK-020.5`: Demo 05 - Oclusión Dinámica y Slew-Rate:**
  - [x] Implementado `scenes/demos/05_dynamic_occlusion_ray/demo_dynamic_occlusion.gd` con obstáculo móvil y suavizado temporal ($\kappa = 8.0\text{ s}^{-1}$).
- [x] **6. `TASK-020.6`: Demo 06 - Streaming de SoundBanks `.bank`:**
  - [x] Implementado `scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd` con prefetch RAM y streaming de disco sin chasquidos.
- [x] **7. `TASK-020.7`: Demo 07 - Hub / Lanzador Maestro:**
  - [x] Implementado `scenes/demos/demo_hub.gd` para seleccionar y lanzar cualquiera de las 6 escenas con notas técnicas.
- [x] **8. Suite de Pruebas Automatizadas:**
  - [x] Tests de controladores de demo en `tests/test_demo_suite.gd`.
  - [x] Actualización de `test_all.gd` (90 pruebas unitarias en total).

---

## 🎯 Próxima Tarea: `TASK-021`
* **Objetivo:** Empaquetado final y documentación pública de instalación para el Godot Asset Library.
