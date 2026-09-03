#!/usr/bin/env python3
"""Genera UNA VEZ scenes/demos/presa/presa_demo.tscn (Fase 16, «La presa»).

La escena se compone como nodos (regla .agents/rules/04_scene_composition.md); por su tamano
(cientos de cuerpos) el .tscn se escribe con este script y a partir de ahi el .tscn es la fuente
de verdad: se edita en el editor, no aqui. Volver a ejecutarlo SOBRESCRIBE los cambios manuales.
"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "demos", "presa", "presa_demo.tscn")

ext = []   # (type, path, id)
sub = []   # (type, id, props: list[str])
nodes = [] # str blocks

def ext_res(t, path, rid):
    ext.append((t, path, rid)); return rid

def sub_res(t, rid, props):
    sub.append((t, rid, props)); return rid

def tf(x, y, z, basis="1, 0, 0, 0, 1, 0, 0, 0, 1"):
    return "Transform3D(%s, %s, %s, %s)" % (basis, g(x), g(y), g(z))

def g(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"

def node(name, ntype, parent, props=(), groups=None, instance=None):
    head = '[node name="%s"' % name
    if ntype: head += ' type="%s"' % ntype
    head += ' parent="%s"' % parent
    if groups: head += ' groups=[%s]' % ", ".join('"%s"' % x for x in groups)
    if instance: head += ' instance=ExtResource("%s")' % instance
    head += "]"
    nodes.append("\n".join([head] + list(props)))

# ---------------- recursos externos
S_DEMO = ext_res("Script", "res://scenes/demos/presa/presa_demo.gd", "1_demo")
S_ROOM = ext_res("Script", "res://addons/opendou/nodes/opendou_room_3d.gd", "2_room")
S_PORTAL = ext_res("Script", "res://addons/opendou/nodes/opendou_portal_3d.gd", "3_portal")
S_REFL = ext_res("Script", "res://addons/opendou/nodes/opendou_reflector_3d.gd", "4_reflector")
S_AREA = ext_res("Script", "res://addons/opendou/nodes/opendou_parameter_area_3d.gd", "5_area")
S_BAKE = ext_res("Script", "res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd", "6_bake")
S_DEBUG = ext_res("Script", "res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd", "7_debug")
S_EMIT3 = ext_res("Script", "res://addons/opendou/nodes/opendou_event_player_3d.gd", "8_emitter")
S_EMIT = ext_res("Script", "res://addons/opendou/nodes/opendou_event_player.gd", "9_player1d")
S_MUSIC = ext_res("Script", "res://addons/opendou/nodes/opendou_music_player.gd", "10_music")
S_BED = ext_res("Script", "res://addons/opendou/nodes/opendou_ambisonic_bed_3d.gd", "11_bed")
S_SPLINE = ext_res("Script", "res://addons/opendou/nodes/opendou_spline_emitter_3d.gd", "12_spline")
S_MULTI = ext_res("Script", "res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd", "13_multi")
S_GRAN = ext_res("Script", "res://addons/opendou/nodes/opendou_granular_emitter_3d.gd", "14_granular")
S_IMPACT = ext_res("Script", "res://addons/opendou/nodes/opendou_physics_impact_3d.gd", "15_impact")
S_DIALOG = ext_res("Script", "res://addons/opendou/nodes/opendou_dialogue_emitter_3d.gd", "16_dialogue")
S_VOLUME = ext_res("Script", "res://addons/opendou/nodes/opendou_acoustic_volume_3d.gd", "17_volume")
S_LISTENER = ext_res("Script", "res://addons/opendou/nodes/opendou_listener_3d.gd", "18_listener")
S_INDICATOR = ext_res("Script", "res://addons/opendou/nodes/opendou_sound_indicator.gd", "19_indicator")
S_EAR = ext_res("Script", "res://addons/opendou/nodes/opendou_ai_hearing_3d.gd", "20_ear")
S_MONITOR = ext_res("Script", "res://addons/opendou/nodes/opendou_audible_monitor.gd", "21_monitor")
S_ENV = ext_res("Script", "res://addons/opendou/resources/acoustic_environment.gd", "22_env")
P_PLAYER = ext_res("PackedScene", "res://scenes/shared/player.tscn", "23_player")
P_NPC = ext_res("PackedScene", "res://scenes/shared/npc.tscn", "24_npc")
P_HUD = ext_res("PackedScene", "res://scenes/shared/demo_hud.tscn", "25_hud")
P_MENU = ext_res("PackedScene", "res://scenes/shared/pause_menu.tscn", "26_menu")

# ---------------- materiales visuales
COLORS = {"Concrete": "0.55, 0.55, 0.53", "Stone": "0.42, 0.40, 0.36", "Metal": "0.62, 0.66, 0.72",
          "Glass": "0.6, 0.8, 0.9", "Wood": "0.52, 0.36, 0.2", "Foliage": "0.2, 0.45, 0.18",
          "Water": "0.16, 0.35, 0.52", "Asphalt": "0.2, 0.2, 0.22"}
for m, c in COLORS.items():
    props = ["albedo_color = Color(%s, 1)" % c]
    if m == "Glass":
        props = ["transparency = 1", "albedo_color = Color(%s, 0.35)" % c]
    sub_res("StandardMaterial3D", "Mat_%s" % m, props)

_box_ids = {}
def box_ids(sx, sy, sz):
    key = (g(sx), g(sy), g(sz))
    if key not in _box_ids:
        n = len(_box_ids)
        sub_res("BoxShape3D", "Shape_%d" % n, ["size = Vector3(%s, %s, %s)" % key])
        sub_res("BoxMesh", "Mesh_%d" % n, ["size = Vector3(%s, %s, %s)" % key])
        _box_ids[key] = n
    n = _box_ids[key]
    return "Shape_%d" % n, "Mesh_%d" % n

count = [0]
def body(name, cx, cy, cz, sx, sy, sz, material, surface=None, obstacle=True, dynamic=False, parent=".", basis=None):
    """StaticBody3D con colision y malla. La malla va al grupo del bake y lleva el material acustico."""
    shape, mesh = box_ids(sx, sy, sz)
    props = ["transform = %s" % (tf(cx, cy, cz, basis) if basis else tf(cx, cy, cz))]
    if surface:
        props.append('metadata/surface_type = &"%s"' % surface)
    node(name, "StaticBody3D", parent, props)
    node("Collision", "CollisionShape3D", (parent + "/" if parent != "." else "") + name, ['shape = SubResource("%s")' % shape])
    groups = None
    if dynamic: groups = ["AcousticObstacleDynamic"]
    elif obstacle: groups = ["AcousticObstacle"]
    node("Mesh", "MeshInstance3D", (parent + "/" if parent != "." else "") + name,
         ['mesh = SubResource("%s")' % mesh, 'material_override = SubResource("Mat_%s")' % material,
          'metadata/acoustic_material = &"%s"' % material], groups=groups)
    count[0] += 3

def wall_x(name, x, y0, y1, z0, z1, material, thick=0.5, openings=()):
    """Muro en el plano x = const entre z0..z1 y y0..y1, con huecos (z_a, z_b, y_a, y_b)."""
    segs = [(z0, z1, y0, y1)]
    for (za, zb, ya, yb) in openings:
        new = []
        for (sz0, sz1, sy0, sy1) in segs:
            if zb <= sz0 or za >= sz1 or yb <= sy0 or ya >= sy1:
                new.append((sz0, sz1, sy0, sy1)); continue
            # partir en hasta cuatro trozos alrededor del hueco
            if za > sz0: new.append((sz0, za, sy0, sy1))
            if zb < sz1: new.append((zb, sz1, sy0, sy1))
            zi0, zi1 = max(za, sz0), min(zb, sz1)
            if ya > sy0: new.append((zi0, zi1, sy0, ya))
            if yb < sy1: new.append((zi0, zi1, yb, sy1))
        segs = new
    for i, (sz0, sz1, sy0, sy1) in enumerate(segs):
        body("%s_%d" % (name, i), x, (sy0 + sy1) / 2, (sz0 + sz1) / 2, thick, sy1 - sy0, sz1 - sz0, material)

def wall_z(name, z, y0, y1, x0, x1, material, thick=0.5, openings=()):
    segs = [(x0, x1, y0, y1)]
    for (xa, xb, ya, yb) in openings:
        new = []
        for (sx0, sx1, sy0, sy1) in segs:
            if xb <= sx0 or xa >= sx1 or yb <= sy0 or ya >= sy1:
                new.append((sx0, sx1, sy0, sy1)); continue
            if xa > sx0: new.append((sx0, xa, sy0, sy1))
            if xb < sx1: new.append((xb, sx1, sy0, sy1))
            xi0, xi1 = max(xa, sx0), min(xb, sx1)
            if ya > sy0: new.append((xi0, xi1, sy0, ya))
            if yb < sy1: new.append((xi0, xi1, yb, sy1))
        segs = new
    for i, (sx0, sx1, sy0, sy1) in enumerate(segs):
        body("%s_%d" % (name, i), (sx0 + sx1) / 2, (sy0 + sy1) / 2, z, sx1 - sx0, sy1 - sy0, thick, material)

# ---------------- entornos acusticos (sub-recursos)
sub_res("Resource", "Env_Water", ['script = ExtResource("%s")' % S_ENV, "medium_enabled = true", "speed_of_sound_mps = 1480.0",
                                  "medium_lowpass_hz = 600.0", "medium_pitch_scale = 0.97", 'medium_snapshot = &"Underwater"',
                                  "surface_enabled = true", 'surface_type = &"Water"', "surface_priority = 5"])
sub_res("Resource", "Env_Wind", ['script = ExtResource("%s")' % S_ENV, "wind_enabled = true", "wind_velocity = Vector3(-6, 0, 3)",
                                 "wind_gust_strength = 0.4", "wind_gust_rate_hz = 0.15", "wind_min_distance_m = 25.0"])
sub_res("Resource", "Env_Forest", ['script = ExtResource("%s")' % S_ENV, "occluder_enabled = true", "occluder_db_per_m = 1.2",
                                   "occluder_cutoff_hz_per_m = 600.0", "surface_enabled = true", 'surface_type = &"Foliage"', "surface_priority = 2"])
# Curvas
sub_res("Curve3D", "Curve_River", ['_data = {\n"points": PackedVector3Array(0, 0, 0, 0, 0, 0, 52, -16.2, 12, 0, 0, 0, 0, 0, 0, 50, -16.2, 22, 0, 0, 0, 0, 0, 0, 47, -16.2, 32, 0, 0, 0, 0, 0, 0, 42, -16.2, 40, 0, 0, 0, 0, 0, 0, 36, -16.2, 45),\n"tilts": PackedFloat32Array(0, 0, 0, 0, 0)\n}', "point_count = 5"])
sub_res("Curve3D", "Curve_Road", ['_data = {\n"points": PackedVector3Array(0, 0, 0, 0, 0, 0, -58, -15.9, 27, 0, 0, 0, 0, 0, 0, 58, -15.9, 27, 0, 0, 0, 0, 0, 0, 58, -15.9, 41, 0, 0, 0, 0, 0, 0, -58, -15.9, 41, 0, 0, 0, 0, 0, 0, -58, -15.9, 27),\n"tilts": PackedFloat32Array(0, 0, 0, 0, 0)\n}', "point_count = 5"])
sub_res("BoxShape3D", "Shape_room_nave", ["size = Vector3(36, 14, 18)"])
sub_res("BoxShape3D", "Shape_room_control", ["size = Vector3(8, 4, 6)"])
sub_res("BoxShape3D", "Shape_room_galeria", ["size = Vector3(22, 2.5, 23)"])
sub_res("BoxShape3D", "Shape_room_inundada", ["size = Vector3(6, 4.5, 6)"])
sub_res("BoxShape3D", "Shape_room_valle", ["size = Vector3(140, 30, 48)"])
sub_res("BoxShape3D", "Shape_vol_water", ["size = Vector3(6, 4, 6)"])
sub_res("BoxShape3D", "Shape_vol_wind", ["size = Vector3(140, 30, 48)"])
sub_res("BoxShape3D", "Shape_vol_forest", ["size = Vector3(24, 8, 15)"])
sub_res("BoxShape3D", "Shape_area_depth", ["size = Vector3(6, 4, 6)"])
sub_res("BoxShape3D", "Shape_area_load", ["size = Vector3(36, 14, 18)"])
sub_res("BoxShape3D", "Shape_area_warn", ["size = Vector3(6, 3, 6)"])
sub_res("BoxShape3D", "Shape_debris", ["size = Vector3(0.5, 0.5, 0.5)"])
sub_res("BoxMesh", "Mesh_debris", ["size = Vector3(0.5, 0.5, 0.5)"])

# ---------------- raiz
nodes.append('[node name="PresaDemo" type="Node3D"]\nscript = ExtResource("%s")' % S_DEMO)

# ---------------- terreno y presa (y = -16 es el suelo del valle; el muro va de -16 a 4)
body("ValleyFloor", 0, -16.5, 24, 140, 1, 48, "Stone", surface="Stone")
body("DamWall", 0, -6, 0, 140, 20, 6, "Concrete")               # z in [-3, 3]
body("HillWest", -73, -6, 24, 6, 20, 48, "Stone")
body("HillEast", 73, -6, 24, 6, 20, 48, "Stone")
body("Road_S", 0, -15.99, 41, 120, 0.02, 6, "Asphalt", surface="Asphalt", obstacle=False)
body("Road_N", 0, -15.99, 27, 120, 0.02, 6, "Asphalt", surface="Asphalt", obstacle=False)
body("Road_W", -58, -15.99, 34, 6, 0.02, 8, "Asphalt", surface="Asphalt", obstacle=False)
body("Road_E", 58, -15.99, 34, 6, 0.02, 8, "Asphalt", surface="Asphalt", obstacle=False)
body("Riverbed", 50, -16.2, 29, 10, 0.4, 34, "Water", surface="Water", obstacle=False)
body("ForestGround", 32, -15.99, 37.5, 24, 0.02, 15, "Foliage", surface="Foliage", obstacle=False)
# arboles de ribera: troncos y copas (follaje)
import random
rnd = random.Random(16)
for i in range(18):
    tx = 21 + rnd.random() * 22
    tz = 31 + rnd.random() * 13
    body("Trunk_%d" % i, tx, -14.5, tz, 0.5, 3, 0.5, "Wood")
    body("Canopy_%d" % i, tx, -11.5, tz, 3, 3, 3, "Foliage")

# ---------------- nave de turbinas (interior x -18..18, y -16..-2, z 3..21)
body("Nave_Floor", 0, -16.25, 12, 36, 0.5, 18, "Metal", surface="Metal")
body("Nave_Roof", 0, -1.75, 12, 37, 0.5, 19, "Concrete")
# Muro oeste: ventana de cristal (z 9..13, y -14.5..-12.5) y puerta a control (z 15..17, y -16..-13.5)
wall_x("Nave_West", -18.25, -16, -2, 3, 21, "Concrete", openings=[(9, 13, -14.5, -12.5), (15, 17, -16, -13.5)])
body("Nave_Window", -18.25, -13.5, 11, 0.3, 2, 4, "Glass")
# Muro este: puerta a la galeria (z 10..13, y -16..-13.5)
wall_x("Nave_East", 18.25, -16, -2, 3, 21, "Concrete", openings=[(10, 13, -16, -13.5)])
# Muro sur: porton al valle (x -3..3, y -16..-12)
wall_z("Nave_South", 21.25, -16, -2, -18.5, 18.5, "Concrete", openings=[(-3, 3, -16, -12)])
# pasarela metalica y pilares
body("Catwalk", 0, -8, 6, 34, 0.2, 2, "Metal", surface="Metal")
for i, px in enumerate([-15, -5, 5, 15]):
    body("Pillar_%d" % i, px, -12, 5, 0.4, 8, 0.4, "Metal")
for i, px in enumerate([-8, 8]):
    body("Turbine_Housing_%d" % i, px, -14.5, 12, 4, 3, 4, "Metal")
# cascotes en la pasarela (cuerpos rigidos con impacto)
for i, px in enumerate([-12, -2, 9]):
    node("Debris_%d" % i, "RigidBody3D", ".", ["transform = %s" % tf(px, -7.6, 6), "mass = 2.0", "freeze = true"])
    node("Collision", "CollisionShape3D", "Debris_%d" % i, ['shape = SubResource("Shape_debris")'])
    node("Mesh", "MeshInstance3D", "Debris_%d" % i, ['mesh = SubResource("Mesh_debris")', 'material_override = SubResource("Mat_Concrete")'])
    node("Impact", "Node3D", "Debris_%d" % i, ['script = ExtResource("%s")' % S_IMPACT, 'event_name = &"Rubble"', "min_speed_mps = 0.6", "cooldown_sec = 0.15"])
    count[0] += 4

# ---------------- sala de control (interior x -27..-19, y -16..-12, z 8..14)
body("Control_Floor", -23, -16.25, 11, 8, 0.5, 6, "Concrete", surface="Concrete")
body("Control_Roof", -23, -11.75, 11, 9, 0.5, 7, "Concrete")
wall_x("Control_West", -27.25, -16, -12, 8, 14, "Concrete")
wall_z("Control_North", 7.75, -16, -12, -27.5, -18.5, "Concrete")
wall_z("Control_South", 14.25, -16, -12, -27.5, -18.5, "Concrete", openings=[(-24, -22, -16, -13.5)])
# pasillo exterior control -> nave (puerta oeste de la nave en z 15..17): un techo bajo
body("Control_Corridor_Roof", -21, -13.25, 16, 12, 0.5, 4, "Concrete")

# ---------------- galeria en L (tramo A: x 18..40, z 10..13; tramo B: x 37..40, z -10..10), y -16..-13.5
body("Gal_A_Floor", 29, -16.25, 11.5, 22, 0.5, 3, "Concrete", surface="Concrete")
body("Gal_A_Roof", 29, -13.25, 11.5, 22, 0.5, 3.5, "Concrete")
wall_z("Gal_A_North", 9.75, -16, -13.5, 18, 37, "Concrete")
wall_z("Gal_A_South", 13.25, -16, -13.5, 18, 28, "Concrete")
wall_z("Gal_A_South2", 13.25, -16, -13.5, 34, 40.25, "Concrete")
body("Gal_B_Floor", 38.5, -16.25, 0, 3, 0.5, 20, "Concrete", surface="Concrete")
body("Gal_B_Roof", 38.5, -13.25, 0, 3.5, 0.5, 20, "Concrete")
wall_x("Gal_B_West", 36.75, -16, -13.5, -10, 10, "Concrete")
wall_x("Gal_B_East", 40.25, -16, -13.5, -10, 13.25, "Concrete")
wall_z("Gal_B_End", -10.25, -16, -13.5, 36.5, 40.5, "Concrete")

# ---------------- galeria inundada (cuenco al sur del tramo A: x 28..34, z 14..20, suelo -19)
body("Inundada_Floor", 31, -19.25, 17, 6, 0.5, 6, "Water", surface="Water")
wall_x("Inundada_West", 27.75, -19, -13.5, 14, 20, "Concrete")
wall_x("Inundada_East", 34.25, -19, -13.5, 14, 20, "Concrete")
wall_z("Inundada_South", 20.25, -19, -13.5, 27.5, 34.5, "Concrete")
body("Inundada_Roof", 31, -13.25, 17, 7, 0.5, 6.5, "Concrete")
# rampa de bajada (caja inclinada 30 grados) desde el tramo A hacia el cuenco
body("Inundada_Ramp", 31, -17.6, 14.9, 4, 0.3, 4.2, "Concrete", surface="Concrete", basis="1, 0, 0, 0, 0.866, 0.5, 0, -0.5, 0.866")

# ---------------- aliviadero (canal x 44..60, z 0..12, agua) y compuerta dinamica en x = 42
body("Spillway_Water", 52, -16.2, 6, 16, 0.4, 12, "Water", surface="Water", obstacle=False)
body("Spillway_WallN", 52, -12, -0.25, 16, 8, 0.5, "Concrete")
body("Spillway_WallS", 52, -12, 12.25, 16, 8, 0.5, "Concrete")
body("Spillway_Gate", 42, -12, 6, 0.4, 8, 12, "Metal", obstacle=False, dynamic=True)
body("Gate_Frame_N", 42, -12, -0.5, 1, 8, 1, "Concrete")
body("Gate_Frame_S", 42, -12, 12.5, 1, 8, 1, "Concrete")

# ---------------- salas
def room(name, cx, cy, cz, shape, material, floor, send=0.6, mode=None, extra=()):
    props = ["transform = %s" % tf(cx, cy, cz), 'script = ExtResource("%s")' % S_ROOM, 'room_name = &"%s"' % name,
             'material_preset = "%s"' % material, 'floor_surface = &"%s"' % floor, "reverb_send_amount = %s" % g(send),
             "reverb_uniformity = 0.6"] + list(extra)
    if mode is not None: props.append("reverb_mode = %d" % mode)
    node(name, "Area3D", ".", props)
    node("Shape", "CollisionShape3D", name, ['shape = SubResource("%s")' % shape])
    count[0] += 2
room("Nave", 0, -9, 12, "Shape_room_nave", "Metal", "Metal", send=0.8, mode=2)
room("Control", -23, -14, 11, "Shape_room_control", "Glass", "Concrete", send=0.4)
room("Galeria", 29, -14.75, 1.5, "Shape_room_galeria", "Concrete", "Concrete", send=0.7, mode=2)
room("Inundada", 31, -16.75, 17, "Shape_room_inundada", "Water", "Water", send=0.5)
room("Valle", 0, -5, 24, "Shape_room_valle", "Outdoor", "Stone", send=0.2)

def portal(name, x, y, z, a, b, size, open_f=1.0):
    node(name, "Node3D", ".", ["transform = %s" % tf(x, y, z), 'script = ExtResource("%s")' % S_PORTAL, 'portal_name = &"%s"' % name,
                                'room_a_name = &"%s"' % a, 'room_b_name = &"%s"' % b, "portal_size = Vector2(%s, %s)" % (g(size[0]), g(size[1])),
                                "open_factor = %s" % g(open_f)])
    count[0] += 1
portal("Door_Nave_Control", -18.25, -14.75, 16, "Nave", "Control", (2, 2.5), 1.0)
portal("Door_Nave_Galeria", 18.25, -14.75, 11.5, "Nave", "Galeria", (3, 2.5), 1.0)
portal("Gate_Nave_Valle", 0, -14, 21.25, "Nave", "Valle", (6, 4), 1.0)
portal("Hatch_Galeria_Inundada", 31, -14.75, 13.6, "Galeria", "Inundada", (4, 2.5), 1.0)

def reflector(name, x, y, z, normal, absorption=0.1):
    node(name, "Node3D", ".", ["transform = %s" % tf(x, y, z), 'script = ExtResource("%s")' % S_REFL, 'reflector_name = &"%s"' % name,
                                "plane_normal = Vector3(%s, %s, %s)" % tuple(g(v) for v in normal), "absorption = %s" % g(absorption)])
    count[0] += 1
reflector("Reflector_DamFace", 0, -6, 3.1, (0, 0, 1), 0.05)
reflector("Reflector_HillWest", -69.9, -6, 24, (1, 0, 0), 0.3)
reflector("Reflector_HillEast", 69.9, -6, 24, (-1, 0, 0), 0.3)

# ---------------- areas de parametro
node("WaterDepth", "Area3D", ".", ["transform = %s" % tf(31, -17, 17), 'script = ExtResource("%s")' % S_AREA, 'parameter_name = &"WaterDepth"',
                                    "min_value = 0.0", "max_value = 1.0", "fade_in_time = 0.4", "fade_out_time = 0.9"])
node("Shape", "CollisionShape3D", "WaterDepth", ['shape = SubResource("Shape_area_depth")'])
node("TurbineLoad", "Area3D", ".", ["transform = %s" % tf(0, -9, 12), 'script = ExtResource("%s")' % S_AREA, 'parameter_name = &"TurbineLoad"',
                                     "interpolation_mode = 1", "gradient_axis = Vector3(1, 0, 0)", "min_value = 0.2", "max_value = 1.0",
                                     "fade_in_time = 0.3", "fade_out_time = 0.6"])
node("Shape", "CollisionShape3D", "TurbineLoad", ['shape = SubResource("Shape_area_load")'])
node("WarnZone", "Area3D", ".", ["transform = %s" % tf(0, -14.5, 24), 'script = ExtResource("%s")' % S_AREA, 'trigger_event = &"GuardWarn"',
                                  'trigger_group = &"player"', "trigger_cooldown_sec = 12.0", "target_entity_mask = 1"])
node("Shape", "CollisionShape3D", "WarnZone", ['shape = SubResource("Shape_area_warn")'])
count[0] += 6

# ---------------- volumenes de entorno
def volume(name, x, y, z, shape, env, priority):
    node(name, "Area3D", ".", ["transform = %s" % tf(x, y, z), 'script = ExtResource("%s")' % S_VOLUME, 'environment = SubResource("%s")' % env,
                                "volume_priority = %d" % priority])
    node("Shape", "CollisionShape3D", name, ['shape = SubResource("%s")' % shape])
    count[0] += 2
volume("Vol_Water", 31, -17, 17, "Shape_vol_water", "Env_Water", 10)
volume("Vol_ValleyWind", 0, -5, 24, "Shape_vol_wind", "Env_Wind", 0)
volume("Vol_Forest", 32, -12, 37.5, "Shape_vol_forest", "Env_Forest", 5)

# ---------------- bake y depurador
node("AcousticBake", "Node3D", ".", ['script = ExtResource("%s")' % S_BAKE, 'target_group = &"AcousticObstacle"', "auto_bake_on_ready = true",
                                      "feed_steam_audio = true", 'dynamic_group = &"AcousticObstacleDynamic"', "probe_spacing_m = 2.0",
                                      "probe_height_m = 1.5", "probe_bounds = AABB(-30, -16, 3, 72, 3, 18)",
                                      'probes_path = "res://scenes/demos/presa/presa_demo.probes"', "auto_load_probes = true"])
node("AcousticDebugger", "Node3D", ".", ['script = ExtResource("%s")' % S_DEBUG, "enabled = false", "display_mode = 2", "show_paths = true"])
count[0] += 2

# ---------------- emisores
def emitter3(name, x, y, z, props):
    node(name, "AudioStreamPlayer3D", ".", ["transform = %s" % tf(x, y, z)] + props + ['script = ExtResource("%s")' % S_EMIT3])
    count[0] += 1
emitter3("Turbine_0", -8, -12.5, 12, ["unit_size = 8.0", "area_mask = 1", 'event_name = &"Turbine"', "auto_play_event = false", "base_priority = 70.0", "cull_distance = 80.0", 'bus_category = "Turbines"'])
emitter3("Turbine_1", 8, -12.5, 12, ["unit_size = 8.0", "area_mask = 1", 'event_name = &"Turbine"', "auto_play_event = false", "base_priority = 70.0", "cull_distance = 80.0", 'bus_category = "Turbines"'])
emitter3("Horn", 0, -6, 3.6, ["unit_size = 10.0", "area_mask = 1", "source = 1", 'capture_bus = &"Radio"', 'bus_category = "Voice"',
                              "directivity_dipole_weight = 0.8", "directivity_power = 2.0", "cull_distance = 120.0", "base_priority = 60.0",
                              "transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -6, 3.6)"])
emitter3("Drip", 38.5, -14.5, -8, ["unit_size = 3.0", "area_mask = 1", 'event_name = &"Drip"', "auto_play_event = false", "cull_distance = 60.0", 'bus_category = "Water"'])
emitter3("Birds", 30, -8, 36, ["unit_size = 12.0", "area_mask = 1", 'event_name = &"Bird"', "auto_play_event = false", "cull_distance = 90.0", 'bus_category = "Wildlife"', "base_priority = 20.0"])
emitter3("Thunder", 0, 60, -340, ["unit_size = 200.0", "max_distance = 800.0", "area_mask = 1", 'event_name = &"Thunder"', "auto_play_event = false",
                                   "propagation_delay_enabled = true", "cull_distance = 800.0", "base_priority = 80.0", 'bus_category = "Ambience"'])
# radio de la sala de control: fuente del altavoz
node("RadioSource", "AudioStreamPlayer", ".", ['script = ExtResource("%s")' % S_EMIT, 'event_name = &"RadioProgram"', "auto_play_event = false", 'bus_category = "Radio"'])
count[0] += 1
# musica
node("Music", "Node", ".", ['script = ExtResource("%s")' % S_MUSIC, 'suite_name = &"Presa_Storm"', "auto_play = false", 'master_bus = &"Music"', "enable_ducking = false", "combat_intensity = 0.0"])
count[0] += 1
# camas ambisonicas
node("WindBed", "AudioStreamPlayer", ".", ['script = ExtResource("%s")' % S_BED, "autoplay_bed = false", 'bus = &"Ambience"'])
node("RainBed", "AudioStreamPlayer", ".", ['script = ExtResource("%s")' % S_BED, "autoplay_bed = false", 'bus = &"Ambience"', "volume_db = -80.0"])
count[0] += 2
# rio (spline) y aliviadero (multiposicion)
node("River", "AudioStreamPlayer3D", ".", ["unit_size = 10.0", 'bus = &"Water"', 'script = ExtResource("%s")' % S_SPLINE, 'curve = SubResource("Curve_River")',
                                            "flow_speed_mps = 2.0", "enable_doppler = true", "max_virtual_distance = 70.0", "auto_play_event = true"])
node("Spillway", "AudioStreamPlayer3D", ".", ["transform = %s" % tf(52, -14, 6), "unit_size = 12.0", 'bus = &"Water"', 'script = ExtResource("%s")' % S_MULTI,
                                               "emission_points = Array[Vector3]([Vector3(-6, 0, -4), Vector3(0, 0, 0), Vector3(6, 0, 4)])",
                                               "smooth_position_lag = 0.15", "cull_distance = 90.0", "auto_play_event = true"])
count[0] += 2
# fauna granular
node("Frogs", "AudioStreamPlayer3D", ".", ["transform = %s" % tf(44, -15.5, 34), "unit_size = 8.0", 'script = ExtResource("%s")' % S_GRAN, "grain_size_ms = 60.0",
                                            "grain_rate_hz = 18.0", "position_jitter_ms = 30.0", "pitch_jitter_semitones = 3.0", "max_concurrent_grains = 12",
                                            "auto_play_emitter = false", 'bus_category = "Wildlife"'])
node("Crickets", "AudioStreamPlayer3D", ".", ["transform = %s" % tf(25, -15, 40), "unit_size = 8.0", 'script = ExtResource("%s")' % S_GRAN, "grain_size_ms = 30.0",
                                               "grain_rate_hz = 70.0", "position_jitter_ms = 20.0", "pitch_jitter_semitones = 2.0", "max_concurrent_grains = 16",
                                               "auto_play_emitter = false", 'bus_category = "Wildlife"'])
count[0] += 2
# camion: camino + seguidor + emisor
node("RoadPath", "Path3D", ".", ['curve = SubResource("Curve_Road")'])
node("TruckFollow", "PathFollow3D", "RoadPath", ["loop = true", "rotation_mode = 3"])
node("Truck", "AudioStreamPlayer3D", "RoadPath/TruckFollow", ["transform = %s" % tf(0, 1, 0), "unit_size = 9.0", "area_mask = 1", 'event_name = &"TruckEngine"',
                                                              "auto_play_event = false", "doppler_enabled = true", "propagation_delay_enabled = true",
                                                              "cull_distance = 150.0", "base_priority = 60.0", 'bus_category = "Vehicle"',
                                                              'script = ExtResource("%s")' % S_EMIT3])
count[0] += 3

# ---------------- jugador, vigilantes
node("Player", None, ".", ["transform = %s" % tf(-8, -15.5, 30)], instance=P_PLAYER)
node("OpenDouListener", "Node3D", "Player", ["transform = %s" % tf(0, 1.6, 0), 'script = ExtResource("%s")' % S_LISTENER, "head_radius_m = 0.09"])
count[0] += 2
def guard(name, x, y, z, waypoints, key):
    wp = ", ".join("Vector3(%s, %s, %s)" % tuple(g(c) for c in p) for p in waypoints)
    node(name, None, ".", ["transform = %s" % tf(x, y, z), "waypoints = Array[Vector3]([%s])" % wp], instance=P_NPC)
    node("Voice", "Node3D", name, ["transform = %s" % tf(0, 0.6, 0), 'script = ExtResource("%s")' % S_DIALOG, 'language = "es"', 'bus_category = &"Voice"',
                                   'duck_bus = &"Music"', "duck_db = -12.0",
                                   'subtitles = {\n&"%s": {\n"es": "%s"\n}\n}' % (key, {"halt": "¡Eh! ¿Quién anda por la nave?", "warn": "Esto es zona de la presa. Vuelva al camino."}[key])])
    node("Ear", "Node3D", name, ["transform = %s" % tf(0, 0.8, 0), 'script = ExtResource("%s")' % S_EAR, "threshold_db = -30.0", "poll_interval_sec = 0.1", "use_raycasts = true"])
    count[0] += 3
guard("GuardHall", -12, -15.5, 16, [(-12, -15.5, 16), (12, -15.5, 16), (12, -15.5, 8), (-12, -15.5, 8)], "halt")
guard("GuardYard", -20, -15.5, 24, [(-20, -15.5, 24), (20, -15.5, 24), (20, -15.5, 36), (-20, -15.5, 36)], "warn")

# ---------------- luz, HUD, accesibilidad, pausa
node("Sun", "DirectionalLight3D", ".", ["transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 14, 0)", "light_energy = 0.35"])
node("Hud", None, ".", ['demo_title = "La presa"',
                        'thesis = "Un valle entero suena por geometria: la nave de turbinas reverbera de verdad, el cristal deja pasar agudos donde el hormigon no, el goteo dobla la esquina del tunel sin portales, la compuerta tapa el aliviadero al bajar, el agua te cubre el oido, el rio te sigue, el camion se acerca y se aleja, el trueno tarda un segundo, y los vigilantes te oyen."',
                        'controls = Array[String](["Flechas — caminar", "Raton — mirar", "G — bajar o subir la compuerta", "T — avanzar la tormenta", "E — abrir o cerrar la puerta mas cercana", "F9 — depurador acustico (caminos en verde)", "F8 — monitor de voces", "F1 — mostrar u ocultar este cartel", "Esc — pausa"])',
                        'exercises = Array[String](["OpenDouRoom3D x5 con CONVOLUTION en la nave y la galeria", "OpenDouPortal3D x4, OpenDouReflector3D x3", "OpenDouAcousticGeometryBake con sondas y compuerta dinamica", "Efecto directo: cristal frente a hormigon", "Caminos: el goteo tras el codo", "OpenDouAcousticVolume3D x3: agua, viento, bosque", "OpenDouListener3D, OpenDouSoundIndicator, OpenDouAIHearing3D x2, OpenDouAudibleMonitor", "OpenDouAmbisonicBed3D x2, OpenDouSplineEmitter3D, OpenDouMultiPositionEmitter3D, OpenDouGranularEmitter3D x2", "OpenDouPhysicsImpact3D x3, OpenDouDialogueEmitter3D x2, OpenDouParameterArea3D x3", "OpenDouEventPlayer3D (turbinas, bocina BUS_CAPTURE, trueno con retardo, camion con doppler), OpenDouEventPlayer, OpenDouMusicPlayer"])'],
     instance=P_HUD)
node("AudibleMonitor", "CanvasLayer", ".", ['script = ExtResource("%s")' % S_MONITOR, "enabled = true", "is_overlay_visible = false", "max_items_displayed = 8"])
node("Accessibility", "CanvasLayer", ".", ["layer = 2"])
node("SoundIndicator", "Control", "Accessibility", ["anchors_preset = 3", "anchor_left = 1.0", "anchor_top = 1.0", "anchor_right = 1.0", "anchor_bottom = 1.0",
                                                     "offset_left = -220.0", "offset_top = -220.0", "offset_right = -20.0", "offset_bottom = -20.0",
                                                     'script = ExtResource("%s")' % S_INDICATOR, "max_items = 8", "min_db_threshold = -45.0", "ring_radius_px = 80.0"])
node("PauseMenu", None, ".", [], instance=P_MENU)
count[0] += 5

# ---------------- escribir
load_steps = len(ext) + len(sub) + 1
out = ["[gd_scene load_steps=%d format=3]" % load_steps, ""]
for t, path, rid in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, path, rid))
out.append("")
for t, rid, props in sub:
    out.append('[sub_resource type="%s" id="%s"]' % (t, rid))
    out.extend(props)
    out.append("")
out.extend(n + "\n" for n in nodes)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    f.write("\n".join(out))
print("nodos declarados:", len(nodes), "| ext", len(ext), "| sub", len(sub), "->", os.path.relpath(OUT))
