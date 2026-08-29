# 📋 Backlog de Tareas: OpenDou Audio Middleware

Este archivo almacena el banco de tareas pendientes y planificadas para **OpenDou**, organizadas por módulo técnico y prioridad.

---

## 🎮 7. Escenas de Demostración AAA y Sandbox (Fase Actual)

* [ ] `TASK-020.1`: **Demo 01: Macro-Acústica y Difracción 3D (`01_spatial_rooms_portals`)**
  * Salas acústicas cerradas (`AudioRoom`), puerta batiente (`AudioPortal`), difracción de sonido y cambio dinámico de origen aparente y LPF.
* [ ] `TASK-020.2`: **Demo 02: Estrés de Voces y Seguimiento Virtual (`02_massive_voice_stress`)**
  * 250 emisores activos con pool de 16 canales físicos, robo de voz por prioridad ($W$), micro-fades de 15ms y virtual tracking con pitch.
* [ ] `TASK-020.3`: **Demo 03: Pisadas y Switch de Superficies 3D (`03_surface_switches_3d`)**
  * Controlador de personaje en tercera persona caminando sobre Madera, Concreto, Metal y Agua con selección por `AudioSwitchContainer` y shuffle anti-repetición.
* [ ] `TASK-020.4`: **Demo 04: Motor de Vehículo y Crossfade Multicapa RPM (`04_vehicle_blend_rpm`)**
  * Acelerador interactivo con tacómetro (0 a 8000 RPM) evaluando `AudioBlendContainer` con curvas LUT $O(1)$ y descarte de silencio ($\le -80\text{ dB}$).
* [ ] `TASK-020.5`: **Demo 05: Oclusión Física Directa y Slew-Rate (`05_dynamic_occlusion_ray`)**
  * Muro móvil que interrumpe la línea de visión, raycasting multi-rayo y suavizado de filtro LPF sin chasquidos.
* [ ] `TASK-020.6`: **Demo 06: Streaming y Prefetching desde SoundBank (`06_soundbank_streaming`)**
  * Demostración de reproducción con arranque instantáneo desde slice de RAM contigua y transición transparente a streaming de disco `.bank`.
* [ ] `TASK-020.7`: **Demo 07: Lanzador Maestro y Hub de Demostraciones (`demo_hub`)**
  * Interfaz de selección de escenas con descripciones técnicas, controles interactivos y telemetría en vivo.

---

## ⚪ 8. Empaquetado y Distribución

* [ ] `TASK-021`: **Empaquetado y Distribución para Godot Asset Library**
  * Manifiesto final, iconos SVG y documentación pública de instalación.
