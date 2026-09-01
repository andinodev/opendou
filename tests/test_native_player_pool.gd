class_name TestNativePlayerPool
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("native_player_pool")

	var pool = NativePlayerPoolClass.new(3)
	var K = NativePlayerPoolClass.PlayerKind

	# Crecimiento perezoso: nada existe hasta que se pide.
	a.eq(pool.total_count(K.SPATIAL_3D), 0, "el pool arranca vacio")

	var p1 = pool.acquire(K.SPATIAL_3D)
	a.ok(p1 is AudioStreamPlayer3D, "acquire 3D devuelve AudioStreamPlayer3D")
	a.eq(pool.busy_count(K.SPATIAL_3D), 1, "una voz ocupada")

	var p2 = pool.acquire(K.SPATIAL_3D)
	pool.acquire(K.SPATIAL_3D)
	a.eq(pool.busy_count(K.SPATIAL_3D), 3, "tres voces ocupadas")

	# Cupo agotado: devuelve null en lugar de crecer sin limite.
	a.eq(pool.acquire(K.SPATIAL_3D), null, "acquire por encima del cupo devuelve null")

	# Liberar permite reutilizar, sin crear nodos nuevos.
	pool.release(p2)
	a.eq(pool.busy_count(K.SPATIAL_3D), 2, "liberar reduce las ocupadas")
	var p5 = pool.acquire(K.SPATIAL_3D)
	a.eq(p5, p2, "acquire reutiliza el reproductor liberado")
	a.eq(pool.total_count(K.SPATIAL_3D), 3, "no se crean nodos extra")

	# Los tres tipos son independientes y no comparten cupo.
	var n1 = pool.acquire(K.NON_SPATIAL)
	a.ok(n1 is AudioStreamPlayer, "acquire no-espacial devuelve AudioStreamPlayer")
	var d1 = pool.acquire(K.SPATIAL_2D)
	a.ok(d1 is AudioStreamPlayer2D, "acquire 2D devuelve AudioStreamPlayer2D")
	a.eq(pool.busy_count(K.SPATIAL_3D), 3, "los tipos no comparten cupo")

	# Liberar deja el reproductor limpio para el siguiente uso.
	pool.release(n1)
	a.eq(n1.stream, null, "al liberar se suelta el stream")

	pool.free()
	return a
