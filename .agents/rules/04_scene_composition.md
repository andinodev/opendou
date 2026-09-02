# Reglas de Composición de Escenas

## La regla

**Todo lo que una escena necesita se compone como NODOS dentro de la escena y se
configura ahí.** El código solo se encarga de lo que de verdad es dinámico.

Un `.tscn` con un único nodo raíz y doscientas líneas de `build()` en su script no
demuestra este plugin: demuestra que alguien sabe escribir GDScript. OpenDou vende que
compones nodos en el árbol y los configuras en el inspector, así que sus escenas tienen
que hacer exactamente eso o la promesa es falsa.

## Qué va en la escena

* La **jerarquía completa**: salas, portales, reflectores, áreas, emisores, suelos,
  personajes, luces, interfaz.
* Los **valores del inspector**: nombres de sala, presets de material, tamaños de portal,
  `unit_size`, máscaras, envíos de reverb, waypoints.
* La **metadata** que otros sistemas leen, como `surface_type`.
* Las **subescenas instanciadas**: un rig de personaje, un HUD, un parche de suelo. Si
  algo aparece en más de una escena, es una subescena.

## Qué va en el código

* **Entrada del jugador**, movimiento y cámara.
* **Comportamiento por frame**: patrullas, telemetría, disparo de pisadas por distancia.
* **Reacciones a eventos**: teclas, triggers, cambios de estado.
* **Recursos que no pueden existir en un `.tscn`.** Es la única excepción legítima, y hay
  que decir por qué en el propio archivo. En este proyecto son los `AudioStream`: no hay
  assets de audio, se sintetizan en tiempo de ejecución, así que los eventos y sus
  contenedores se autoran en código. **Los nodos no.**

## Qué NO es excepción

* «Es más rápido de escribir en código.» Lo es, y por eso hay que resistirlo.
* «Son muchos nodos.» Si son muchos, con más razón: un `.tscn` los muestra de un vistazo
  y un `build()` de 200 líneas no.
* «El tamaño se calcula.» Cálcula el valor una vez y escríbelo en la escena. Si de verdad
  varía en tiempo de ejecución, entonces sí es dinámico.

## Cómo se hace cumplir

`tests/test_scene_guards.gd` lee cada `.tscn` **sin instanciarlo**, con
`PackedScene.get_state()`, y falla si:

* una escena de demo declara menos nodos que su mínimo,
* le falta un tipo de nodo de OpenDou que la escena dice ejercitar,
* o su raíz es el único nodo declarado.

Leer el estado empaquetado y no el árbol ya instanciado es deliberado: lo que se quiere
afirmar es que los nodos están **en la escena**, no que un `_ready()` los fabricó.
