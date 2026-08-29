# 📜 Architecture Decision Records (ADRs)

Este directorio almacena los **Registros de Decisiones de Arquitectura (ADRs)** de OpenDou.

Un ADR documenta una decisión técnica o arquitectónica relevante que se ha tomado en el proyecto, su contexto, las opciones consideradas y sus consecuencias.

---

## 📌 Convención de Nomenclatura

Cada archivo debe seguir el formato:
```text
NNNN-titulo-en-kebab-case.md
```
Donde `NNNN` es un número secuencial de 4 dígitos (ejemplo: `0001-init-architecture.md`, `0002-audio-middleware-architecture.md`).

---

## 📋 Proceso para Crear un Nuevo ADR

1. Copiar la plantilla [docs/templates/template_adr.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/templates/template_adr.md).
2. Asignar el siguiente número correlativo disponible.
3. Completar las secciones:
   * **Contexto y Problema**
   * **Decisión Tomada**
   * **Consecuencias (Positivas y Negativas)**
   * **Alternativas Consideradas**
4. Registrar el nuevo ADR en la tabla de índice que figura a continuación.

---

## 📑 Índice de Decisiones

| ID | Fecha | Título | Estado |
|---|---|---|---|
| [ADR-0001](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/decisions/0001-init-architecture.md) | 2026-08-29 | Inicialización de Gobernanza y Estructura Modular | **Aceptada** |
| [ADR-0002](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/decisions/0002-audio-middleware-architecture.md) | 2026-08-29 | Arquitectura del Motor de Audio Open-Source OpenDou | **Aceptada** |
