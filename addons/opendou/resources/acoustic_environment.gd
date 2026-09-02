@tool
class_name AcousticEnvironment
extends Resource

## Comportamiento acustico de un volumen (Fase 10): cinco secciones opcionales, todas
## apagadas por defecto. El nodo es OpenDouAcousticVolume3D; esto es el dato, como
## Environment lo es de WorldEnvironment.

@export_group("Medio")
@export var medium_enabled: bool = false
## Escala el ITD, el retardo por distancia y el doppler. Agua: 1480.
@export_range(100.0, 6000.0, 1.0) var speed_of_sound_mps: float = 343.0
## Paso-bajo en Master mientras el oyente esta dentro. 20000 = sin filtro.
@export_range(200.0, 20000.0, 1.0) var medium_lowpass_hz: float = 20000.0
## Factor de tono sobre todas las voces fisicas.
@export_range(0.5, 2.0, 0.01) var medium_pitch_scale: float = 1.0
## Instantanea de mezcla que se empuja al entrar y se saca al salir. Vacia = ninguna.
@export var medium_snapshot: StringName = &""

@export_group("Viento")
@export var wind_enabled: bool = false
## Velocidad del viento en el mundo, m/s.
@export var wind_velocity: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var wind_gust_strength: float = 0.0
@export_range(0.01, 5.0, 0.01) var wind_gust_rate_hz: float = 0.2
## Solo las voces mas lejanas que esto notan el viento.
@export_range(0.0, 500.0, 1.0) var wind_min_distance_m: float = 20.0

@export_group("Oclusion parcial")
@export var occluder_enabled: bool = false
@export_range(0.0, 30.0, 0.1) var occluder_db_per_m: float = 3.0
@export_range(0.0, 10000.0, 10.0) var occluder_cutoff_hz_per_m: float = 2000.0

@export_group("Descarte")
@export var cull_enabled: bool = false
## Buses (target_bus de la definicion) cuyas voces se virtualizan con el oyente dentro.
@export var cull_buses: Array[StringName] = []

@export_group("Superficie")
@export var surface_enabled: bool = false
@export var surface_type: StringName = &""
@export var surface_priority: int = 0
