# ⚡ Tarea Activa: TASK-034 - Matriz Visual de Audio Ducking en el HDR Mixer Drawer

* **Estado:** 🚧 En Desarrollo
* **Fase:** 20 - Matriz de Ducking Dinámico en el Mixer Drawer
* **Fecha de Inicio:** 2026-08-29
* **Responsable:** Antigravity / Gemini Agent

---

## 🎯 Criterios de Aceptación (Definition of Done)

1. **Pestaña "🦆 Ducking Matrix" en `OpenDouMixerDrawer`:**
   * Grid interactivo de matriz de buses emisores (Voice, SFX, Music, Ambient) vs buses receptores.
2. **Editor de Reglas de Ducking por Celda:**
   * Configuración de atenuación en dB (`-1 dB a -48 dB`), `Attack Time (ms)` y `Release Time (ms)`.
   * Botón para habilitar/deshabilitar regla entre pares de buses.
3. **Indicador de Atenuación en Tiempo Real:**
   * Medidores visuales de reducción de ganancia (GR / Gain Reduction) en vivo.
4. **Sincronización con `AudioDuckingMatrix`:**
   * Conexión directa a las reglas y actualización continua en runtime.
5. **Verificación Automatizada:**
   * 100% de pruebas pasando en `tests/test_runner_cli.gd` (código de salida 0).
