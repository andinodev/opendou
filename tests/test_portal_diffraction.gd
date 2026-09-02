class_name TestPortalDiffraction
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const PortalClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("portal_diffraction")

	# Asignar open_factor directamente debe propagarse al portal en runtime, sin
	# tener que acordarse de llamar set_open_factor().
	var portal = PortalClass.new()
	portal.portal_name = &"PuertaBlindada"
	portal.room_a_name = &"Pasillo"
	portal.room_b_name = &"Bunker"
	var runtime = portal.register_in_manager()
	a.ok(runtime != null, "el portal se registra")

	portal.open_factor = 0.25
	a.approx(runtime.open_factor, 0.25, "asignar open_factor sincroniza el portal", 0.001)
	portal.open_factor = 1.0
	a.approx(runtime.open_factor, 1.0, "y vuelve a sincronizar al reabrir", 0.001)

	# Fuera de rango se recorta, igual que hacia set_open_factor().
	portal.open_factor = 5.0
	a.approx(portal.open_factor, 1.0, "open_factor se recorta por arriba", 0.001)
	portal.open_factor = -3.0
	a.approx(portal.open_factor, 0.0, "open_factor se recorta por abajo", 0.001)

	# set_open_factor() sigue funcionando: es API publica que no se rompe.
	portal.set_open_factor(0.5)
	a.approx(runtime.open_factor, 0.5, "set_open_factor sigue sincronizando", 0.001)

	# El tamano de la apertura importa. Dos portales igual de abiertos pero de
	# tamano muy distinto no pueden difractar igual.
	var gatera = PortalClass.new()
	gatera.portal_size = Vector2(0.3, 0.3)
	gatera.open_factor = 1.0
	var porton = PortalClass.new()
	porton.portal_size = Vector2(3.0, 4.0)
	porton.open_factor = 1.0

	var lpf_gatera: float = gatera.get_diffraction_lpf()
	var lpf_porton: float = porton.get_diffraction_lpf()
	a.gt(lpf_porton, lpf_gatera, "el porton difracta menos que la gatera")
	a.lt(lpf_gatera, 5000.0, "una gatera abierta sigue filtrando mucho")

	# Cerrar reduce el cutoff aunque la apertura sea grande.
	porton.open_factor = 0.05
	a.lt(porton.get_diffraction_lpf(), lpf_porton, "cerrar el porton baja el cutoff")

	# El cutoff nunca sale del rango declarado.
	for f in [0.0, 0.5, 1.0]:
		porton.open_factor = f
		var v: float = porton.get_diffraction_lpf()
		a.ok(v >= PortalClass.MIN_DIFFRACTION_LPF_HZ and v <= PortalClass.MAX_DIFFRACTION_LPF_HZ,
			"el cutoff se queda en rango con open_factor %.1f" % f)

	# Una puerta del tamano de referencia abierta del todo no filtra: garantiza
	# compatibilidad con el comportamiento anterior, que solo miraba open_factor.
	var referencia = PortalClass.new()
	referencia.portal_size = Vector2(2.0, 3.0)
	referencia.open_factor = 1.0
	a.approx(referencia.get_diffraction_lpf(), PortalClass.MAX_DIFFRACTION_LPF_HZ,
		"una apertura de referencia abierta no filtra", 1.0)

	referencia.free(); gatera.free(); porton.free(); portal.free()
	return a
