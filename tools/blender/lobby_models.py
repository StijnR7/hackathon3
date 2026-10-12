# Genereert de lobby-modellen procedureel en exporteert ze naar één FBX.
# Gebruik: blender --background --python tools/blender/lobby_models.py -- <out_dir>
import bpy
import bmesh
import json
import math
import os
import random
import sys
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- helpers ----------
def link(name, me):
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def obj_from_bm(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(name, me)


def bake(ob):
    """Past alle modifiers toe (zonder operators)."""
    dg = bpy.context.evaluated_depsgraph_get()
    if ob.type == "MESH":
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear()
        old = ob.data
        ob.data = me
        bpy.data.meshes.remove(old)
        return ob
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    new = link(ob.name + "_m", me)
    bpy.data.objects.remove(ob)
    return new


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, target):
    t = tris(ob)
    if t > target:
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = target / t
        bake(ob)


def box(bm, c, s, rot=None):
    m = Matrix.Translation(Vector(c)) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((s[0], s[1], s[2], 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def cyl(bm, c, r, h, seg=12, r2=None, rot=None):
    m = Matrix.Translation(Vector(c)) @ (rot or Matrix.Identity(4))
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=m)


def ico(bm, c, r, sub=2, scale=(1, 1, 1)):
    m = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1))
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r, matrix=m)


def merge(bm, ob):
    """Voegt een (gebakken) object toe aan bm en verwijdert het object."""
    tmp = bmesh.new()
    tmp.from_mesh(ob.data)
    tmp.transform(ob.matrix_world)
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bpy.data.objects.remove(ob)


def bevel(ob, width=0.04, seg=1):
    m = ob.modifiers.new("bev", "BEVEL")
    m.width = width
    m.segments = seg
    m.limit_method = "ANGLE"
    bake(ob)


def noise_tex(scale):
    t = bpy.data.textures.new("noise", type="CLOUDS")
    t.noise_scale = scale
    return t


def weather(ob, voxel=0.04, strength=0.05, scale=0.25, target=2500):
    """Remesh + noise voor oude, verweerde steen."""
    r = ob.modifiers.new("rem", "REMESH")
    r.mode = "VOXEL"
    r.voxel_size = voxel
    d = ob.modifiers.new("disp", "DISPLACE")
    d.texture = noise_tex(scale)
    d.strength = strength
    d.mid_level = 0.5
    bake(ob)
    decimate(ob, target)


def smooth(ob, on=True):
    for p in ob.data.polygons:
        p.use_smooth = on


def triplanar_uv(ob, tile=4.0):
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UV")
    uv = me.uv_layers.active.data
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv[li].uv = (co.y / tile, co.z / tile)
            elif ax == 1:
                uv[li].uv = (co.x / tile, co.z / tile)
            else:
                uv[li].uv = (co.x / tile, co.y / tile)


def finish(ob, target=None, smooth_shade=False):
    if target:
        decimate(ob, target)
    smooth(ob, smooth_shade)
    triplanar_uv(ob)
    # oorsprong onderaan in het midden
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    shift = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    ob.data.transform(Matrix.Translation(-shift))
    return ob


# ---------- dode bomen (skin modifier) ----------
def tree(name, seed, height, depth=3, spread=1.0, target=5000):
    rnd = random.Random(seed)
    verts, edges, radii = [Vector((0, 0, 0))], [], [height * 0.06]

    def grow(parent, pos, d, length, radius, lvl):
        segs = 5
        cur, idx = pos, parent
        for s in range(segs):
            d = (d + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.05, 0.12)))).normalized()
            cur = cur + d * (length / segs)
            verts.append(cur.copy())
            r = max(radius * (1 - (s + 1) / (segs + 1) * 0.75), 0.03)
            radii.append(r)
            edges.append((idx, len(verts) - 1))
            idx = len(verts) - 1
            if lvl > 0 and s >= 1 and rnd.random() < 0.5:
                bd = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.1, 0.5))) * spread).normalized()
                grow(idx, cur, bd, length * rnd.uniform(0.4, 0.65), r * 0.6, lvl - 1)
        if lvl > 0:
            for _ in range(rnd.randint(2, 3)):
                bd = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.4))) * spread).normalized()
                grow(idx, cur, bd, length * rnd.uniform(0.4, 0.6), radius * 0.4, lvl - 1)

    grow(0, Vector((0, 0, 0)), Vector((0, 0, 1)), height * 0.55, height * 0.05, depth)
    # wortels
    for i in range(5):
        a = i / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        end = Vector((math.cos(a) * height * 0.12, math.sin(a) * height * 0.12, -0.3))
        mid = Vector((math.cos(a) * height * 0.05, math.sin(a) * height * 0.05, 0.25))
        verts += [mid, end]
        radii += [height * 0.035, 0.05]
        edges += [(0, len(verts) - 2), (len(verts) - 2, len(verts) - 1)]

    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], edges, [])
    ob = link(name, me)
    ob.modifiers.new("skin", "SKIN")
    if len(me.skin_vertices) == 0:
        me.skin_vertices.new()
    for i, r in enumerate(radii):
        me.skin_vertices[0].data[i].radius = (r, r)
    me.skin_vertices[0].data[0].use_root = True
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    d = ob.modifiers.new("bark", "DISPLACE")
    d.texture = noise_tex(0.15)
    d.strength = 0.06
    bake(ob)
    return finish(ob, target, smooth_shade=True)


# ---------- grafstenen ----------
def grave_round():
    bm = bmesh.new()
    box(bm, (0, 0, 0.6), (0.9, 0.22, 1.2))
    cyl(bm, (0, 0, 1.2), 0.45, 0.22, seg=24, rot=Matrix.Rotation(math.pi / 2, 4, "X"))
    box(bm, (0, 0, 0.08), (1.1, 0.4, 0.16))
    ob = obj_from_bm("GraveRound", bm)
    weather(ob, voxel=0.025, strength=0.035, scale=0.12, target=2000)
    return finish(ob)


def grave_cross():
    bm = bmesh.new()
    box(bm, (0, 0, 0.12), (0.8, 0.5, 0.24))
    box(bm, (0, 0, 0.35), (0.6, 0.38, 0.25))
    box(bm, (0, 0, 1.1), (0.18, 0.16, 1.5))
    box(bm, (0, 0, 1.35), (0.8, 0.16, 0.18))
    ob = obj_from_bm("GraveCross", bm)
    weather(ob, voxel=0.025, strength=0.03, scale=0.12, target=2000)
    return finish(ob)


def grave_broken():
    bm = bmesh.new()
    box(bm, (0, 0, 0.55), (0.85, 0.2, 1.1))
    box(bm, (0, 0, 0.08), (1.05, 0.38, 0.16))
    # schuine breuk bovenaan
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0.9), plane_no=Vector((0.45, 0.1, 1)).normalized(), clear_outer=True)
    bmesh.ops.holes_fill(bm, edges=[e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)])
    ob = obj_from_bm("GraveBroken", bm)
    weather(ob, voxel=0.025, strength=0.04, scale=0.1, target=2000)
    return finish(ob)


def obelisk():
    bm = bmesh.new()
    box(bm, (0, 0, 0.15), (0.9, 0.9, 0.3))
    box(bm, (0, 0, 0.42), (0.7, 0.7, 0.25))
    cyl(bm, (0, 0, 1.55), 0.32, 2.0, seg=4, r2=0.2, rot=Matrix.Rotation(math.pi / 4, 4, "Z"))
    cyl(bm, (0, 0, 2.75), 0.2, 0.4, seg=4, r2=0.0, rot=Matrix.Rotation(math.pi / 4, 4, "Z"))
    ob = obj_from_bm("Obelisk", bm)
    weather(ob, voxel=0.03, strength=0.03, scale=0.15, target=2000)
    return finish(ob)


def coffin():
    pts = [(0, 1.05), (0.25, 1.05), (0.38, 0.6), (0.3, -1.05), (-0.3, -1.05), (-0.38, 0.6), (-0.25, 1.05)]
    pts = pts[1:]
    bm = bmesh.new()
    for z0, z1, grow in ((0, 0.45, 1.0), (0.45, 0.58, 1.06)):
        bot = [bm.verts.new((x * grow, y * (1 + (grow - 1) * 0.5), z0)) for x, y in pts]
        top = [bm.verts.new((x * grow, y * (1 + (grow - 1) * 0.5), z1)) for x, y in pts]
        bm.faces.new(list(reversed(bot)))
        bm.faces.new(top)
        n = len(pts)
        for i in range(n):
            bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
    ob = obj_from_bm("Coffin", bm)
    bevel(ob, 0.02)
    return finish(ob)


def rock(name, seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    ico(bm, (0, 0, 0), 1.0, sub=3, scale=(rnd.uniform(1, 1.6), rnd.uniform(0.8, 1.2), rnd.uniform(0.5, 0.8)))
    ob = obj_from_bm(name, bm)
    d = ob.modifiers.new("disp", "DISPLACE")
    d.texture = noise_tex(0.6)
    d.strength = 0.35
    bake(ob)
    return finish(ob, 1200, smooth_shade=True)


# ---------- lantaarnpaal ----------
def curve_mesh(name, points, depth):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = depth
    cu.bevel_resolution = 3
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    ob = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(ob)
    return bake(ob)


LAMP_HANG = (1.45, 0, 5.9)  # waar de lantaarn hangt (Blender-coords, voor finish)


def lamp_post():
    bm = bmesh.new()
    cyl(bm, (0, 0, 0.2), 0.38, 0.4, seg=8, r2=0.28)
    cyl(bm, (0, 0, 0.55), 0.2, 0.3, seg=8, r2=0.12)
    cyl(bm, (0, 0, 3.6), 0.09, 6.2, seg=10)
    for z in (1.2, 4.5, 6.5):
        cyl(bm, (0, 0, z), 0.14, 0.12, seg=10)
    cyl(bm, (0, 0, 6.95), 0.12, 0.4, seg=10, r2=0.0)
    ob = obj_from_bm("LampPost", bm)
    arm = curve_mesh("arm", [(0, 0, 6.3), (0.8, 0, 6.75), (1.45, 0, 6.4), (1.45, 0, 6.15)], 0.05)
    scroll = curve_mesh("scroll", [(0, 0, 5.4), (0.5, 0, 5.6), (0.8, 0, 6.2), (0.55, 0, 6.45)], 0.035)
    bm2 = bmesh.new()
    bm2.from_mesh(ob.data)
    merge(bm2, arm)
    merge(bm2, scroll)
    bm2.to_mesh(ob.data)
    bm2.free()
    return finish(ob)


def lantern():
    """Lantaarn-frame; middelpunt = midden van het glas."""
    bm = bmesh.new()
    s, h = 0.42, 0.7
    box(bm, (0, 0, -h / 2 - 0.04), (s + 0.12, s + 0.12, 0.08))
    for x in (-1, 1):
        for y in (-1, 1):
            box(bm, (x * s / 2, y * s / 2, 0), (0.05, 0.05, h))
    box(bm, (0, 0, h / 2 + 0.04), (s + 0.14, s + 0.14, 0.08))
    cyl(bm, (0, 0, h / 2 + 0.25), (s + 0.14) / math.sqrt(2), 0.34, seg=4, r2=0.04, rot=Matrix.Rotation(math.pi / 4, 4, "Z"))
    cyl(bm, (0, 0, h / 2 + 0.47), 0.05, 0.1, seg=8)
    cyl(bm, (0, 0, -h / 2 - 0.16), 0.12, 0.16, seg=8, r2=0.02)
    ob = obj_from_bm("Lantern", bm)
    ob.data.transform(Matrix.Translation((0, 0, 0)))
    return finish(ob)


# ---------- smeedijzeren hek ----------
def fence():
    bm = bmesh.new()
    L, H = 8.0, 3.0
    for z in (0.45, 2.55):
        box(bm, (0, 0, z), (L, 0.07, 0.09))
    n = 20
    for i in range(n + 1):
        x = -L / 2 + i * L / n
        cyl(bm, (x, 0, H / 2), 0.035, H, seg=6)
        cyl(bm, (x, 0, H + 0.15), 0.08, 0.3, seg=4, r2=0.0)
    for x in (-L / 2, L / 2):
        box(bm, (x, 0, 1.8), (0.28, 0.28, 3.6))
        ico(bm, (x, 0, 3.8), 0.2, sub=1)
    ob = obj_from_bm("FenceSegment", bm)
    return finish(ob)


def gate_arch():
    bm = bmesh.new()
    for x in (-4.2, 4.2):
        box(bm, (x, 0, 3.0), (1.4, 1.4, 6.0))
        box(bm, (x, 0, 6.2), (1.7, 1.7, 0.4))
        box(bm, (x, 0, 0.2), (1.7, 1.7, 0.4))
        ico(bm, (x, 0, 6.8), 0.45, sub=2)
    ob = obj_from_bm("GatePillars", bm)
    weather(ob, voxel=0.06, strength=0.08, scale=0.4, target=4000)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bpy.data.objects.remove(ob)
    arch = curve_mesh("arch", [(-3.5, 0, 6.0), (-1.8, 0, 7.6), (0, 0, 8.4), (1.8, 0, 7.6), (3.5, 0, 6.0)], 0.07)
    merge(bm, arch)
    arch2 = curve_mesh("arch2", [(-3.5, 0, 5.4), (-1.8, 0, 6.8), (0, 0, 7.5), (1.8, 0, 6.8), (3.5, 0, 5.4)], 0.05)
    merge(bm, arch2)
    for i in range(-6, 7):
        x = i * 0.5
        top = 8.4 - (x / 3.5) ** 2 * 2.3
        bot = 7.5 - (x / 3.5) ** 2 * 2.0
        cyl(bm, (x, 0, (top + bot) / 2), 0.03, top - bot, seg=6)
        cyl(bm, (x, 0, top + 0.18), 0.07, 0.36, seg=4, r2=0.0)
    ob = obj_from_bm("GateArch", bm)
    return finish(ob)


# ---------- crypte (queue) ----------
def crypt():
    W, D, H, T, B = 12.0, 13.0, 9.0, 0.8, 1.0  # breedte, diepte, hoogte, wanddikte, sokkel
    bm = bmesh.new()
    box(bm, (0, 0, 0.25), (W + 3, D + 3, 0.5))
    box(bm, (0, 0, 0.75), (W + 1.6, D + 1.6, 0.5))
    box(bm, (-(W / 2 - T / 2), 0, B + H / 2), (T, D, H))
    box(bm, ((W / 2 - T / 2), 0, B + H / 2), (T, D, H))
    box(bm, (0, D / 2 - T / 2, B + H / 2), (W, T, H))
    # dak: platte rand + driehoekig dak (nok over de diepte)
    box(bm, (0, -0.6, B + H + 0.35), (W + 1.2, D + 2.4, 0.7))
    zt, zr, y0, y1 = B + H + 0.7, B + H + 4.0, -D / 2 - 1.8, D / 2 + 0.6
    xs = W / 2 + 0.6
    v = [bm.verts.new(p) for p in ((-xs, y0, zt), (xs, y0, zt), (0, y0, zr), (-xs, y1, zt), (xs, y1, zt), (0, y1, zr))]
    for f in ((v[0], v[2], v[1]), (v[3], v[4], v[5]), (v[0], v[1], v[4], v[3]), (v[1], v[2], v[5], v[4]), (v[2], v[0], v[3], v[5])):
        bm.faces.new(f)
    # zuilen voor de deur
    for x in (-3.9, 3.9):
        cyl(bm, (x, -D / 2 - 1.0, B + H / 2), 0.45, H, seg=16)
        box(bm, (x, -D / 2 - 1.0, B + 0.2), (1.2, 1.2, 0.4))
        box(bm, (x, -D / 2 - 1.0, B + H - 0.2), (1.2, 1.2, 0.4))
    # kruis op de nok
    box(bm, (0, y0 + 0.3, zr + 1.0), (0.35, 0.35, 2.0))
    box(bm, (0, y0 + 0.3, zr + 1.4), (1.3, 0.35, 0.35))
    # hoekpilasters, fries en urnen
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            box(bm, (x, y, B + H / 2), (1.1, 1.1, H))
    box(bm, (0, 0, B + H - 0.35), (W + 0.5, D + 0.5, 0.5))
    box(bm, (0, 0, B + 0.3), (W + 0.4, D + 0.4, 0.6))
    for x in (-W / 2 - 0.1, W / 2 + 0.1):
        box(bm, (x, y0 + 0.5, zt + 0.3), (0.8, 0.8, 0.6))
        ico(bm, (x, y0 + 0.5, zt + 1.0), 0.42, sub=2, scale=(1, 1, 1.3))
    # traptreden voor de deur
    box(bm, (0, -D / 2 - 2.4, 0.75), (6.0, 1.2, 0.5))
    shell = obj_from_bm("CryptShell", bm)

    # voorgevel met boogdeur (boolean)
    bm = bmesh.new()
    box(bm, (0, -D / 2 + T / 2, B + H / 2), (W, T, H))
    front = obj_from_bm("CryptFront", bm)
    bm = bmesh.new()
    box(bm, (0, -D / 2 + T / 2, B + 2.6), (5.0, T * 4, 5.2))
    cyl(bm, (0, -D / 2 + T / 2, B + 5.2), 2.5, T * 4, seg=24, rot=Matrix.Rotation(math.pi / 2, 4, "X"))
    cutter = obj_from_bm("cutter", bm)
    m = front.modifiers.new("cut", "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    m.use_self = True  # cutter bestaat uit overlappende box + cilinder
    bake(front)
    bpy.data.objects.remove(cutter)

    bm = bmesh.new()
    bm.from_mesh(shell.data)
    merge(bm, front)
    bm.to_mesh(shell.data)
    bm.free()
    shell.name = "Crypt"
    weather(shell, voxel=0.07, strength=0.07, scale=0.6, target=9000)
    return finish(shell)


# ---------- bouwen + export ----------
BUILDERS = {
    "TreeA": lambda: tree("TreeA", 1, 9.0, depth=3),
    "TreeB": lambda: tree("TreeB", 7, 7.5, depth=3, spread=1.3),
    "TreeC": lambda: tree("TreeC", 21, 11.0, depth=3, spread=0.8),
    "TreeBig": lambda: tree("TreeBig", 42, 14.0, depth=4, spread=1.1, target=9000),
    "DeadBush": lambda: tree("DeadBush", 5, 2.2, depth=2, spread=1.6, target=1500),
    "GraveRound": grave_round,
    "GraveCross": grave_cross,
    "GraveBroken": grave_broken,
    "Obelisk": obelisk,
    "Coffin": coffin,
    "RockA": lambda: rock("RockA", 3),
    "RockB": lambda: rock("RockB", 11),
    "LampPost": lamp_post,
    "Lantern": lantern,
    "FenceSegment": fence,
    "GateArch": gate_arch,
    "Crypt": crypt,
}
# Alleen bepaalde modellen opnieuw maken: zet env LOBBY_ONLY=Crypt,Lantern
ONLY = [n for n in os.environ.get("LOBBY_ONLY", "").split(",") if n]
objs = [BUILDERS[n]() for n in (ONLY or BUILDERS)]
NAME = "lobby_models" + ("_" + "_".join(ONLY) if ONLY else "")

info = {}
for ob in objs:
    bb = [Vector(c) for c in ob.bound_box]
    info[ob.name] = {
        "tris": tris(ob),
        "min": [round(min(v[i] for v in bb), 3) for i in range(3)],
        "max": [round(max(v[i] for v in bb), 3) for i in range(3)],
    }
info["_lamp_hang"] = LAMP_HANG

with open(os.path.join(OUT, NAME + ".json"), "w") as f:
    json.dump(info, f, indent=1)

bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, NAME + ".fbx"),
    use_selection=False,
    object_types={"MESH"},
    apply_unit_scale=True,
    axis_forward="-Z",
    axis_up="Y",
    mesh_smooth_type="FACE",
)
print("EXPORTED", len(objs), "objects")
