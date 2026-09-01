# 🗺️ Roadmap del Proyecto OpenDou (Audio Middleware)

Este documento resume las fases estratégicas, hitos principales y estado general de evolución de **OpenDou**.

---

## 📌 Estado Actual del Proyecto

* **Fase Actual:** Fase 6 - Suite de Interfaz de Autoría / UI Multi-Ventana en Godot 4.7+
* **Versión Objetivo de Godot:** Godot 4.7+ (compatible con 4.3+)
* **Última Actualización:** 2026-08-29

---

## 🚀 Fases de Desarrollo

### 🟢 Fase 1: Núcleo de Eventos y Sistema de Voces Virtuales (✅ Completada)
* [x] Análisis comparativo de motores de audio (Godot, Wwise, FMOD) y diseño de arquitectura base (`TASK-001`).
* [x] Implementación del despachador de eventos y acciones (`TASK-002`).
* [x] Contenedores lógicos (*Random/Shuffle*, *Switch*, *Blend*, *Sequence*) con Patrón Composite (`TASK-003`).
* [x] Gestor de Voces Virtuales (*Virtual Voice Tracking* a coste cero y robo dinámico de voz) (`TASK-004`, `TASK-005`).
* [x] Suite de pruebas unitarias headless para eventos y voces.

---

### 🟡 Fase 2: Parámetros RTPC, Estados y Modulación (✅ Completada)
* [x] Sistema centralizado de variables de juego (*Game Syncs*): RTPCs, States con crossfade, Switches y Triggers (`TASK-006`).
* [x] Motor de evaluación de curvas acelerado con tablas de búsqueda pre-horneadas LUT $O(1)$ (`TASK-006`).
* [x] Moduladores automáticos integrados: envolventes AHDSR y osciladores LFO periódicos (`TASK-007`).
* [x] Enlace dinámico de RTPCs a volumen, tono, corte de frecuencias y envíos de bus.

---

### 🔵 Fase 3: Pipeline de SoundBanks y Precarga (✅ Completada)
* [x] Especificación y formato de archivo binario monolítico `ODBK` (`TASK-008`).
* [x] Gestor de memoria física con búfer de *Prefetch* en RAM contigua (`TASK-008`).
* [x] Precarga perezosa de cada stream del banco como `AudioStreamWAV` reproducible (`TASK-009`). El streaming asíncrono desde disco se retiró: exige un mezclador en el hilo de audio, y GDScript no puede sostenerlo.
* [x] Herramienta de compilación/empaquetado de bancos de sonido (`SoundBankCompiler`).

---

### 🟣 Fase 4: Acústica Espacial (Rooms, Portals y Oclusión) (✅ Completada)
* [x] Nodos y componentes de recintos acústicos (`AudioRoom`) y aberturas (`AudioPortal`) (`TASK-010`).
* [x] Cálculo de propagación y difracción en esquinas mediante pathfinding acústico a través de portales (`TASK-010`).
* [x] Oclusión directa multi-rayo y suavizado temporal por *slew-rate* ($\kappa = 8.0\text{ s}^{-1}$) (`TASK-011`).

---

### 🟠 Fase 5: Servidor de Live Update TCP y Profiler en Vivo (✅ Completada)
* [x] Servidor TCP no bloqueante embebido con protocolo binario TLV (`TASK-012`).
* [x] Protocolo de sincronización en caliente de parámetros, volúmenes y curvas en RAM en tiempo real (`TASK-012`).
* [x] Telemetría detallada y snapshot de voces vivas con coordenadas 3D para radar (`TASK-013`).

---

### 🎨 Fase 6: Suite de Interfaz de Autoría / UI en Godot 4.7+ (⚡ En Curso)
* [ ] **`TASK-014`**: Nodos de Grafo Visual de Audio (`GraphNode` Custom Widgets: Blend, Random, Switch, WAV, Output).
* [ ] **`TASK-015`**: Lienzo de Grafo Visual & Serialización (`GraphEdit` con flujo de señal animado en vivo y conversión Composite).
* [ ] **`TASK-016`**: Barra de Transporte, Audición en Vivo y Faders RTPC (`OpenDouTransportBar`).
* [ ] **`TASK-017`**: Radar Acústico 3D & Telemetría en Tiempo Real (`OpenDouRadarView`).
* [ ] **`TASK-018`**: Panel de Compilación y Empaquetado de SoundBanks (`OpenDouBankPanel`).
* [ ] **`TASK-019`**: Contenedor Maestro Multi-Modo (Dock Inferior "Audio Logic", Main Screen Tab y Ventana Flotante Desacoplable `Window`).

---

### ⚪ Fase 7: Demostración y Distribución
* [ ] Escena de demostración en Godot 4.7+ con cientos de emisores, rooms/portals y música dinámica.
* [ ] Empaquetado y distribución en el Godot Asset Library.
