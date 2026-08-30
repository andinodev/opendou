Está redactado como un Documento de Diseño de Experiencia (XDD), utilizando variables claras, mapeo de canales estructurado y una línea de tiempo para asegurar que el modelo procese cada dimensión acústica sin perder ningún detalle técnico o narrativo.

---

## **[Contexto del Sistema]**

**Proyecto:** Sala Demo "Biosfera 7.1"
**Objetivo:** Diseñar una experiencia auditiva inmersiva de alta fidelidad que demuestre las capacidades de un sistema surround 7.1. El entorno debe ser vibrante, orgánico y saturado de micromovimientos naturales.
**Instrucción para la IA Receptora:** Actúa como Ingeniero de Audio Espacial y Diseñador Narrativo. Analiza esta estructura y expande el concepto generando especificaciones de ecualización, listas de *assets* de audio y automatizaciones de paneo espacial.

## **[Mapeo Espacial 7.1]**

La distribución del paisaje sonoro debe aislar frecuencias y eventos direccionales para evitar la saturación de fase y maximizar la inmersión.

| Canal (7.1) | Rango de Frecuencia | Asignación de Sonidos Naturales | Función en la Mezcla |
| --- | --- | --- | --- |
| **Frontales (L/R)** | Medias y Altas | Viento en la copa de los árboles, río fluyendo a la distancia. | Cama acústica principal y definición del ancho del paisaje. |
| **Central (C)** | Medias (Aisladas) | Canto de aves exóticas, ramas crujiendo justo al frente. | Punto de atención principal; ancla auditiva del espectador. |
| **Subwoofer (LFE)** | Bajas (< 80Hz) | Truenos lejanos, rugidos de cascadas, pisadas pesadas, estampidas. | Presión sonora y vibración física en la sala demo. |
| **Laterales (SL/SR)** | Altas y Medias-Altas | Insectos zumbando de un lado a otro, ranas, aleteos rápidos cruzando la sala. | Expansión del campo estéreo y sensación de proximidad inmediata. |
| **Traseros (RL/RR)** | Medias y Bajas-Medias | Eco de la montaña, lluvia acercándose por la espalda, depredador sigiloso. | Profundidad del entorno, inmersión 360° y factor sorpresa. |

## **[Evolución Dinámica: Arco Acústico]**

La demostración debe fluir a través de distintas densidades sonoras para resaltar el rango dinámico del sistema y la separación de canales.

* 0:00 - 0:30: Fase 1: El Despertar del Dosel
Comienza en silencio absoluto. Se introducen los frontales (L/R) con una suave brisa. El canal Central (C) emite el primer canto de un ave solitaria. Progresivamente, los canales laterales (SL/SR) despiertan con insectos sutiles, demostrando precisión en frecuencias altas sin fatigar el oído.


* 0:30 - 1:00: Fase 2: La Tormenta Envolvente
La presión atmosférica auditiva cambia. La lluvia comienza sutilmente en los traseros (RL/RR) y envuelve la sala avanzando hacia los frontales. El Subwoofer (LFE) despierta con truenos profundos que hacen vibrar el suelo, mientras aleteos asustados cruzan mediante paneos rápidos de SL a SR.


* 1:00 - 1:30: Fase 3: El Goteo Tridimensional
La tormenta amaina súbitamente. El foco se mueve a un riachuelo cristalino (L/C/R). El protagonismo pasa a los 4 canales envolventes (Laterales y Traseros), donde gotas residuales caen aleatoriamente de forma aislada, creando una sensación hiperrealista de humedad y mapeo espacial preciso.


## **[Variables de Salida Solicitadas a la IA]**

A partir de este documento, requiero que generes:

1. **Inventario de Assets:** Una tabla con los archivos de audio crudos necesarios y la técnica de grabación recomendada (ej. Ambisonics, Binaural, Mono puntual).
2. **Matemática de Paneo:** Explicación técnica de cómo un sonido rápido (ej. una abeja) debe transitar mediante *crossfading* desde el canal RR hasta el Frontal L sin perder volumen.
3. **Tratamiento de Reverb:** Parámetros de reverberación digital para emular la absorción acústica de un bosque denso.

---