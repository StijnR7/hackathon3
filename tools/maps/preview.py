# Rendert previews van een Rojo .model.json map in Blender (zonder Studio).
# Gebruik: blender --background --python tools/maps/preview.py -- maps/Hospital.model.json <out_dir> [plan|shots|all]
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
MODE = args[2] if len(args) > 2 else "all"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Roblox (x, y, z) met Y omhoog -> Blender (x, -z, y)
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def to_b(v):
    return P @ Vector(v)


cube_mesh = bpy.data.meshes.new("cube")
import bmesh

bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bm.to_mesh(cube_mesh)
bm.free()
cyl_mesh = bpy.data.meshes.new("cyl")
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.5, radius2=0.5, depth=1.0,
                      matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))  # as langs X, zoals Roblox
bm.to_mesh(cyl_mesh)
bm.free()

mats = {}
HIDE_IN_PLAN = ("CeilingTile", "Plenum", "Roof", "HangingTile", "Cable", "Pipe", "LightHousing", "Fluorescent", "LightDead",
                "CurtainRail", "SurgeryLamp", "SurgeryLampArm", "DoorHeader")


def material(color, mat, transparency):
    key = (tuple(round(c, 3) for c in color), mat, round(transparency, 2))
    if key in mats:
        return mats[key]
    m = bpy.data.materials.new(str(len(mats)))
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    rough = {"Metal": 0.4, "Glass": 0.05, "Marble": 0.3, "CeramicTiles": 0.35}.get(mat, 0.8)
    bsdf.inputs["Roughness"].default_value = rough
    if mat == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.6
    if mat == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in color], 1)
        bsdf.inputs["Emission Strength"].default_value = 6
    if transparency > 0:
        bsdf.inputs["Alpha"].default_value = 1 - transparency
        m.surface_render_method = "BLENDED" if hasattr(m, "surface_render_method") else None
    m.diffuse_color = (*[c ** 2.2 for c in color], 1 - transparency)
    mats[key] = m
    return m


lights = []


def walk(node, parent_name=""):
    cls = node.get("className")
    props = node.get("properties", {})
    name = node.get("name", "")
    if cls in ("Part", "SpawnLocation") and "Size" in props:
        cf = props["CFrame"]["CFrame"]
        pos = cf["position"]
        rot = Matrix(cf["orientation"])
        size = props["Size"]
        transparency = props.get("Transparency", 0)
        if transparency < 1:
            mesh = cyl_mesh if props.get("Shape") == "Cylinder" else cube_mesh
            ob = bpy.data.objects.new(name, mesh)
            m3 = P @ rot @ Matrix.Diagonal((size[0], size[1], size[2]))
            ob.matrix_world = Matrix.Translation(to_b(pos)) @ m3.to_4x4()
            ob["plan_hide"] = name in HIDE_IN_PLAN
            scene.collection.objects.link(ob)
            ob.material_slots[0].link = "OBJECT"
            ob.material_slots[0].material = material(props.get("Color", [0.5, 0.5, 0.5]), props.get("Material", "SmoothPlastic"), transparency)
        for child in node.get("children", []):
            if child["className"] in ("PointLight", "SpotLight", "SurfaceLight"):
                lights.append((child, pos, rot, size))
    for child in node.get("children", []):
        walk(child, name)


# gedeelde meshes krijgen één materiaalslot zodat objecten er zelf één kunnen kiezen
for me in (cube_mesh, cyl_mesh):
    me.materials.append(bpy.data.materials.new("base"))

with open(SRC, encoding="utf8") as f:
    walk(json.load(f))

FACES = {"Front": (0, 0, -1), "Back": (0, 0, 1), "Left": (-1, 0, 0), "Right": (1, 0, 0), "Top": (0, 1, 0), "Bottom": (0, -1, 0)}
for node, pos, rot, size in lights:
    p = node["properties"]
    color = p.get("Color", [1, 1, 1])
    bright, rng = p.get("Brightness", 1), p.get("Range", 8)
    cls = node["className"]
    if cls == "PointLight":
        ld = bpy.data.lights.new("pl", "POINT")
        ld.energy = bright * rng * rng * 1.2
        ld.shadow_soft_size = 0.3
        direction = None
    else:
        face = p.get("Face", "Front")
        direction = Vector(FACES[face])
        if cls == "SpotLight":
            ld = bpy.data.lights.new("sl", "SPOT")
            ld.spot_size = math.radians(min(p.get("Angle", 90), 170))
            ld.energy = bright * rng * rng * 2
        else:
            ld = bpy.data.lights.new("al", "SPOT")
            ld.spot_size = math.radians(min(p.get("Angle", 90), 170))
            ld.spot_blend = 0.6
            ld.energy = bright * rng * rng * 2
    ld.color = color
    ld.use_shadow = False  # te veel lampen voor Eevee-schaduwen
    ob = bpy.data.objects.new("light", ld)
    ob.location = to_b(pos)
    if direction is not None:
        d_world = to_b(list(Matrix(rot) @ direction))
        ob.rotation_euler = d_world.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(ob)

# wereld: bijna zwart
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.005, 0.007, 1)
scene.world = world
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.view_settings.look = "AgX - Medium High Contrast" if "AgX - Medium High Contrast" in [i.name for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items] else "None"


def camera(name, loc_r, target_r, lens=18):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    ob = bpy.data.objects.new(name, cd)
    scene.collection.objects.link(ob)
    ob.location = to_b(loc_r)
    direction = to_b(target_r) - to_b(loc_r)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return ob


def render(path):
    scene.render.filepath = os.path.join(OUT, path)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


if MODE in ("plan", "all"):
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = False
    for ob in scene.objects:
        if ob.get("plan_hide"):
            ob.hide_render = True
    cd = bpy.data.cameras.new("plan")
    cd.type = "ORTHO"
    cd.ortho_scale = 130
    cam = bpy.data.objects.new("plan", cd)
    scene.collection.objects.link(cam)
    cam.location = to_b([0, 80, -15])
    cam.rotation_euler = (0, 0, 0)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1400, 1300
    render("plan.png")
    for ob in scene.objects:
        if ob.get("plan_hide"):
            ob.hide_render = False
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720

if MODE in ("shots", "all"):
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
        scene.eevee.use_shadows = True
    except Exception:
        pass
    shots = {
        "reception": ([0, 5.5, 36], [0, 4, 8]),
        "corridor": ([0, 5.5, 6], [0, 4, -60]),
        "cross": ([-55, 5.5, -25], [40, 4, -25]),
        "morgue": ([8, 6.5, -34], [20, 2.5, -64]),
        "surgery": ([-7, 6.5, -33], [-22, 2.5, -56]),
        "ward": ([-33, 6, -45], [-60, 3, -45]),
    }
    for name, (loc, tgt) in shots.items():
        scene.camera = camera(name, loc, tgt)
        render(f"shot_{name}.png")
