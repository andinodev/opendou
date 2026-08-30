# Idea 014: Monitor de Voces Audibles, Percepción de IA y Accesibilidad Auditiva

## 1. Visión y Propósito
Crear un subsistema en tiempo real capaz de calcular con precisión la **intensidad sonora percibida (Loudness en dB)** de cada fuente de audio activa desde el punto de vista del oyente (`AudioListener3D` o cámara 2D), ordenando las fuentes de mayor a menor audibilidad para depuración, jugabilidad y accesibilidad.

---

## 2. Aplicaciones y Casos de Uso Futuros

### A. Herramienta de Debug Universal (`OpenDouAudibleMonitor`)
* **HUD In-Game Flotante:** Un panel desplegable (activable con shortcut o botón) que lista en vivo los sonidos que realmente se escuchan en el fotograma actual.
* **VU Meter por Categoría:** Barras de nivel coloreadas (Voz, SFX, Música, Ambiente) que muestran la ganancia recibida, atenuación por distancia, oclusión por muros y reducción por ducking.
* **Filtro de Inaudibilidad:** Oculta automáticamente sonidos con ganancia $< -60\text{ dB}$, voces virtuales detenidas o emisores culleados por distancia.

### B. Sistema de Percepción Acústica para IA (Stealth Gameplay)
* Los agentes de IA (enemigos, guardias, monstruos) pueden consultar la API `OpenDou.get_audible_voices_at_position(npc_pos, min_db_threshold)`:
  * Detectar pisadas según la superficie y la oclusión de muros.
  * Reaccionar a disparos, explosiones o alarmas calculando si el sonido superó el umbral de alerta del guardia.

### C. Accesibilidad para Jugadores con Discapacidad Auditiva (Deaf Accessibility)
* **Indicadores Direccionales de Audio en Pantalla:** Flechas o radares visuales que apuntan hacia las fuentes de sonido más intensas.
* **Subtítulos con Indicador de Intensidad y Tipo:** Diferenciación visual de susurros, pasos lejanos o disparos cercanos según el nivel en dB calculado.

### D. Profiler de Mezcla en OpenDou Studio
* Pestaña dedicada en el Profiler con historial temporal de volumen de las 10 voces más dominantes para detectar desbalances en la mezcla o sonidos que saturan el master.

---

## 3. Arquitectura de Datos (`AudibleVoiceInfo`)

```gdscript
class_name AudibleVoiceInfo
extends RefCounted

var emitter_name: StringName = &""
var event_name: StringName = &""
var bus_category: StringName = &"SFX"
var effective_db: float = -60.0
var raw_volume_db: float = 0.0
var distance_attenuation_db: float = 0.0
var occlusion_attenuation_db: float = 0.0
var ducking_attenuation_db: float = 0.0
var distance_meters: float = 0.0
var world_position: Vector3 = Vector3.ZERO
var is_3d: bool = false
var priority: float = 50.0
```
