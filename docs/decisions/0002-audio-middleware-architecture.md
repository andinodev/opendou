# ADR 0002: Arquitectura del Motor de Audio Open-Source OpenDou

* **Estado:** Aceptada
* **Fecha:** 2026-08-29
* **Autor:** Danielillo & Antigravity Agent

---

## 1. Contexto y Problema

Godot Engine (versiones 4.3+, 4.4+ y 4.7+) cuenta con un servidor de audio nativo funcional (`AudioServer`, buses, efectos y nodos `AudioStreamPlayer`), pero carece de las características de alto nivel requeridas en producciones complejas y dinámicas que tradicionalmente obligan a los desarrolladores a recurrir a middlewares propietarios como **Wwise** o **FMOD**:
1. Acoplamiento de la reproducción de audio a nodos del árbol de escenas.
2. Inexistencia de un sistema de **Voces Virtuales** y robo dinámico de canales por prioridad/distancia.
3. Carencia de un gestor desacoplado de **RTPCs (curvas de modulación en tiempo real)**, Estados globales y Switches locales.
4. Ausencia de un pipeline de **SoundBanks con memoria fija y prefetching** para streaming de latencia cero.
5. Falta de propagación acústica realista (**Rooms & Portals**) y servidor de **Live Update por TCP**.

---

## 2. Decisión Tomada

Se decide diseñar e implementar **OpenDou** como un middleware y motor de audio 100% código abierto estructurado en 5 pilares fundamentales:

1. **Gestor de Eventos y Acciones Desacoplado:**
   * El código del juego emite eventos independientes (`OpenDou.post_event(...)`).
   * Contenedores lógicos (*Random/Shuffle*, *Switch*, *Blend*, *Sequence*).
2. **Sistema de Voces Virtuales y Gestión de Recursos:**
   * Seguimiento de tiempo sin coste de decodificación para sonidos inaudibles.
   * Algoritmos deterministas de robo de voz (*voice stealing*) ponderados por distancia y prioridad.
3. **Pipeline de SoundBanks y Streaming Híbrido con Prefetch:**
   * Formato binario `.bank` con tablas de búsqueda rápida.
   * Búfer de pre-carga inicial en RAM (64–128 KB) para disparo inmediato acoplado a streaming asíncrono desde disco.
4. **Módulo de Acústica Espacial (Rooms & Portals):**
   * Cálculo de propagación y difracción geométrica conectando recintos con portales.
   * Integración con `PhysicsServer3D` para cálculo de oclusión por raycasting.
5. **Servidor de Live Update TCP y Profiling en Tiempo Real:**
   * Conexión TCP no bloqueante para ajuste de mezclas y curvas en vivo contra el juego en ejecución.
   * Backend de telemetría de rendimiento (voces activas, consumo de DSP y memoria).

---

## 3. Consecuencias

### Positivas (+)
* Alternativa 100% libre y sin costes de licencia para la comunidad de Godot.
* Rendimiento óptimo en escenas con cientos de emisores de sonido simultáneos gracias al sistema de voces virtuales.
* Cero latencia en el disparo de sonidos vía streaming gracias al prefetching en RAM.
* Flujo de trabajo profesional para diseñadores de sonido mediante eventos y RTPCs.

### Negativas / Compromisos (-)
* Requiere implementar y mantener componentes de bajo nivel en C++/GDExtension para garantizar rendimiento en tiempo real y seguridad de hilos.

---

## 4. Alternativas Consideradas

* **Usar exclusivamente el sistema nativo de Godot con scripts GDScript:** Descartado por sobrecarga de CPU, falta de voces virtuales y acoplamiento excesivo al SceneTree.
* **Integraciones directas de FMOD o Wwise:** Descartadas por restricciones de licenciamiento propietario y limitaciones en plataformas abiertas.
