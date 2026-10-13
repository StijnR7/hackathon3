# Genereert de map "verlaten ziekenhuis" als Rojo model-bestand (maps/Hospital.model.json).
# Gebruik: python tools/maps/hospital.py
# Alles is Parts (geen uploads nodig), dus Rojo kan het direct in Workspace syncen.
import json
import math
import os
import random

R = random.Random(666)
H = 14  # plafondhoogte
DOOR_H = 9
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "maps", "Hospital.model.json")


# ---------------------------------------------------------------- helpers
def rgb(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def rot(yaw=0.0, pitch=0.0, roll=0.0):
    """Graden. Zelfde volgorde als CFrame.Angles(pitch, yaw, roll) = Rx * Ry * Rz."""
    x, y, z = math.radians(pitch), math.radians(yaw), math.radians(roll)
    rx = [[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]]
    ry = [[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]]
    rz = [[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]]
    return matmul(matmul(rx, ry), rz)


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def cframe(pos, m=None):
    m = m or [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    return {"CFrame": {"position": [round(p, 4) for p in pos], "orientation": [[round(c, 5) for c in row] for row in m]}}


class Group:
    def __init__(self, name, class_name="Folder"):
        self.node = {"name": name, "className": class_name, "children": []} if name != "Hospital" else {"className": class_name, "children": []}

    def add(self, node):
        self.node["children"].append(node)
        return node

    def sub(self, name, class_name="Folder"):
        g = Group(name, class_name)
        self.add(g.node)
        return g


COUNT = {"parts": 0, "lights": 0}


def part(group, name, size, pos, color, material="SmoothPlastic", m=None, shape=None, transparency=0.0,
         collide=True, shadow=True, tags=None, children=None, cls="Part", extra=None):
    props = {
        "Anchored": True,
        "Size": [round(s, 4) for s in size],
        "CFrame": cframe(pos, m),
        "Color": rgb(*color),
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if shape:
        props["Shape"] = shape
    if transparency:
        props["Transparency"] = transparency
    if not collide:
        props["CanCollide"] = False
        props["CanTouch"] = False
    if not shadow:
        props["CastShadow"] = False
    if tags:
        props["Tags"] = tags
    if extra:
        props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if children:
        node["children"] = children
    COUNT["parts"] += 1
    return group.add(node)


def light(kind, color, brightness, rng, extra=None):
    COUNT["lights"] += 1
    props = {"Color": rgb(*color), "Brightness": brightness, "Range": rng, "Shadows": True}
    props.update(extra or {})
    return {"name": kind, "className": kind, "properties": props}


def local(origin, m, offset):
    """Wereldpositie van `offset` t.o.v. (origin, rotatie m)."""
    o = apply(m, offset)
    return [origin[0] + o[0], origin[1] + o[1], origin[2] + o[2]]


def text_gui(text, face="Front", color=(120, 10, 10), font="Creepster", light_influence=1.0):
    return {
        "name": "SurfaceGui",
        "className": "SurfaceGui",
        "properties": {"Face": face, "LightInfluence": light_influence, "PixelsPerStud": 40},
        "children": [{
            "name": "Text",
            "className": "TextLabel",
            "properties": {
                "Size": {"UDim2": [[1, 0], [1, 0]]},
                "BackgroundTransparency": 1,
                "Text": text,
                "TextScaled": True,
                "TextColor3": rgb(*color),
                "FontFace": {"Font": {"family": f"rbxasset://fonts/families/{font}.json", "weight": "Regular", "style": "Normal"}},
            },
        }],
    }


# ---------------------------------------------------------------- kleuren
PLASTER = (150, 152, 140)
PLASTER_DIRTY = (118, 120, 108)
TILE_GREEN = (112, 138, 124)
TILE_WHITE = (170, 172, 165)
FLOOR_CORRIDOR = (92, 98, 92)
FLOOR_ROOM = (128, 128, 120)
FLOOR_DARK = (70, 74, 72)
METAL = (150, 155, 158)
METAL_DARK = (70, 74, 78)
RUST = (95, 60, 40)
WOOD = (70, 52, 40)
FABRIC = (170, 168, 155)
FABRIC_DIRTY = (140, 132, 110)
CURTAIN = (100, 140, 128)
BLOOD = (70, 8, 8)
BRICK = (90, 60, 50)

# ---------------------------------------------------------------- plattegrond
# (naam, x1, z1, x2, z2, soort). Latere gebieden overschrijven eerdere.
AREAS = [
    ("reception", -25, 10, 25, 40, "hall"),
    ("cross", -60, -30, 60, -20, "corridor"),
    ("main", -5, -70, 5, 10, "corridor"),
    ("room101", -25, -5, -5, 10, "patient"),
    ("room102", -25, -20, -5, -5, "patient"),
    ("nurse", 5, -5, 25, 10, "nurse"),
    ("bath", 5, -20, 25, -5, "bath"),
    ("surgery", -30, -70, -5, -30, "surgery"),
    ("morgue", 5, -70, 30, -30, "morgue"),
    ("ward", -60, -60, -30, -30, "ward"),
    ("records", 30, -60, 60, -30, "records"),
    ("room103", -60, -20, -42, 0, "patient"),
    ("storage", -42, -20, -25, 0, "storage"),
    ("office", 25, -20, 42, 0, "office"),
    ("room104", 42, -20, 60, 0, "patient"),
]
KIND = {a[0]: a[5] for a in AREAS}
OPEN = {frozenset(("reception", "main")), frozenset(("main", "cross"))}
CORRIDORS = {"main", "cross", "reception"}

# deuren: (x, z, as, breedte, bord). as "z" = muur loopt langs Z (x vast), "x" = muur loopt langs X (z vast)
DOORS = [
    (-5, 2, "z", 6, "101"),
    (-5, -12, "z", 6, "102"),
    (5, 2, "z", 6, "NURSES"),
    (5, -12, "z", 6, "WC"),
    (-5, -50, "z", 7, "SURGERY"),
    (-18, -30, "x", 8, "OR 1"),
    (5, -58, "z", 7, "MORGUE"),
    (-45, -30, "x", 7, "WARD B"),
    (45, -30, "x", 7, "RECORDS"),
    (-51, -20, "x", 6, "103"),
    (-33, -20, "x", 6, "STORAGE"),
    (51, -20, "x", 6, "104"),
    (33, -20, "x", 6, "OFFICE"),
    (15, 10, "x", 6, None),  # loket van de verpleegpost
]

X0, X1, Z0, Z1 = -61, 61, -71, 41
grid = {}
for name, x1, z1, x2, z2, _ in AREAS:
    for x in range(x1, x2):
        for z in range(z1, z2):
            grid[(x, z)] = name


def label(x, z):
    return grid.get((x, z))


def in_door(line_pos, along, axis):
    for dx, dz, ax, w, _ in DOORS:
        if ax != axis:
            continue
        if axis == "z" and dx == line_pos and dz - w / 2 <= along + 0.5 <= dz + w / 2:
            return True
        if axis == "x" and dz == line_pos and dx - w / 2 <= along + 0.5 <= dx + w / 2:
            return True
    return False


def needs_wall(a, b):
    if a == b:
        return False
    if a and b and frozenset((a, b)) in OPEN:
        return False
    return True


# randen verzamelen: muren langs Z op x = vast, muren langs X op z = vast
segments = []  # (axis, line, start, end, sideA, sideB)
for x in range(X0, X1 + 1):
    run = None
    for z in range(Z0, Z1 + 1):
        a, b = label(x - 1, z), label(x, z)
        wall = needs_wall(a, b) and not in_door(x, z, "z")
        key = (a, b) if wall else None
        if run and (not wall or run[3] != key):
            segments.append(("z", x, run[0], run[1], run[3][0], run[3][1]))
            run = None
        if wall:
            run = [run[0], z + 1, None, key] if run else [z, z + 1, None, key]
    if run:
        segments.append(("z", x, run[0], run[1], run[3][0], run[3][1]))
for z in range(Z0, Z1 + 1):
    run = None
    for x in range(X0, X1 + 1):
        a, b = label(x, z - 1), label(x, z)
        wall = needs_wall(a, b) and not in_door(z, x, "x")
        key = (a, b) if wall else None
        if run and (not wall or run[3] != key):
            segments.append(("x", z, run[0], run[1], run[3][0], run[3][1]))
            run = None
        if wall:
            run = [run[0], x + 1, None, key] if run else [x, x + 1, None, key]
    if run:
        segments.append(("x", z, run[0], run[1], run[3][0], run[3][1]))

# ---------------------------------------------------------------- bouwen
root = Group("Hospital", "Model")
structure = root.sub("Structure")
walls = structure.sub("Walls")
floors = structure.sub("Floors")
ceilings = structure.sub("Ceilings")
lights_g = root.sub("Lights")
props = root.sub("Props")
decor = root.sub("Decor")
markers = root.sub("Markers")

WAINSCOT = {"corridor": TILE_GREEN, "hall": TILE_GREEN, "patient": TILE_WHITE, "nurse": TILE_WHITE, "bath": TILE_WHITE,
            "surgery": TILE_WHITE, "morgue": (130, 140, 140), "ward": TILE_WHITE, "records": None, "storage": None, "office": None}


def wall_piece(axis, line, a, b, y0, y1, material="Plaster", color=PLASTER, name="Wall", ext=0.5):
    length = b - a + 2 * ext
    mid = (a + b) / 2
    h = y1 - y0
    if axis == "z":
        part(walls, name, [1, h, length], [line, y0 + h / 2, mid], color, material)
    else:
        part(walls, name, [length, h, 1], [mid, y0 + h / 2, line], color, material)


for axis, line, a, b, sa, sb in segments:
    tint = R.uniform(0.85, 1.05)
    col = tuple(min(255, int(c * tint)) for c in (PLASTER if R.random() < 0.6 else PLASTER_DIRTY))
    wall_piece(axis, line, a, b, 0, H, color=col)
    length = b - a
    mid = (a + b) / 2
    for side, lab in ((-1, sa), (1, sb)):
        if lab is None:
            # buitenkant: bakstenen schil
            if axis == "z":
                part(walls, "Brick", [0.3, H + 2, length + 1.6], [line + side * 0.65, H / 2 + 1, mid], BRICK, "Brick")
            else:
                part(walls, "Brick", [length + 1.6, H + 2, 0.3], [mid, H / 2 + 1, line + side * 0.65], BRICK, "Brick")
            continue
        kind = KIND[lab]
        tile = WAINSCOT.get(kind)
        if tile and length > 0.6:
            t = tuple(int(c * R.uniform(0.9, 1.05)) for c in tile)
            off = line + side * 0.58
            if axis == "z":
                part(walls, "Wainscot", [0.16, 4.2, length], [off, 2.1, mid], t, "CeramicTiles", shadow=False)
            else:
                part(walls, "Wainscot", [length, 4.2, 0.16], [mid, 2.1, off], t, "CeramicTiles", shadow=False)
        if lab in ("main", "cross") and length > 2:
            off = line + side * 0.85
            if axis == "z":
                part(walls, "Handrail", [0.3, 0.3, length - 0.6], [off, 3.4, mid], METAL, "Metal", shadow=False)
            else:
                part(walls, "Handrail", [length - 0.6, 0.3, 0.3], [mid, 3.4, off], METAL, "Metal", shadow=False)

# deurposten, bovenstuk, deuren en bordjes
for dx, dz, ax, w, sign in DOORS:
    if ax == "z":
        wall_piece("z", dx, dz - w / 2, dz + w / 2, DOOR_H, H, color=PLASTER_DIRTY, name="DoorHeader", ext=0)
        for s in (-1, 1):
            part(walls, "DoorFrame", [1.3, DOOR_H, 0.35], [dx, DOOR_H / 2, dz + s * (w / 2 - 0.17)], (60, 75, 70), "Metal")
        part(walls, "DoorFrame", [1.3, 0.35, w], [dx, DOOR_H - 0.17, dz], (60, 75, 70), "Metal")
        sides = [(dx - 1, dz), (dx, dz)]
    else:
        wall_piece("x", dz, dx - w / 2, dx + w / 2, DOOR_H, H, color=PLASTER_DIRTY, name="DoorHeader", ext=0)
        for s in (-1, 1):
            part(walls, "DoorFrame", [0.35, DOOR_H, 1.3], [dx + s * (w / 2 - 0.17), DOOR_H / 2, dz], (60, 75, 70), "Metal")
        part(walls, "DoorFrame", [w, 0.35, 1.3], [dx, DOOR_H - 0.17, dz], (60, 75, 70), "Metal")
        sides = [(dx, dz - 1), (dx, dz)]
    labs = [label(*c) for c in sides]
    if sign:
        # bordje aan de gangkant
        for i, lab in enumerate(labs):
            if lab in CORRIDORS:
                s = -1 if i == 0 else 1
                if ax == "z":
                    pos = [dx + s * 0.7, DOOR_H + 1.6, dz]
                    m = rot(yaw=90 if s < 0 else -90)
                else:
                    pos = [dx, DOOR_H + 1.6, dz + s * 0.7]
                    m = rot(yaw=180 if s > 0 else 0)
                part(decor, "RoomSign", [4, 1.2, 0.15], pos, (35, 60, 55), "SmoothPlastic", m=m,
                     children=[text_gui(sign, "Front", (200, 205, 190), "SpecialElite", 1)])
    # deurblad: open, half open of eruit gevallen
    leaf_w = w / (2 if w >= 7 else 1)
    roll = R.random()
    room_side = 1 if labs[1] not in CORRIDORS else -1
    if roll < 0.75:
        hinge_s = R.choice((-1, 1))
        angle = R.uniform(60, 105)
        if ax == "z":
            # blad staat vanaf het scharnier schuin de kamer in
            hinge = [dx + room_side * 0.4, 0, dz + hinge_s * (w / 2 - 0.3)]
            dirx, dirz = room_side * math.sin(math.radians(angle)), -hinge_s * math.cos(math.radians(angle))
            cx, cz = hinge[0] + dirx * leaf_w / 2, hinge[2] + dirz * leaf_w / 2
            yaw = math.degrees(math.atan2(dirx, dirz))
        else:
            hinge = [dx + hinge_s * (w / 2 - 0.3), 0, dz + room_side * 0.4]
            dirx, dirz = -hinge_s * math.cos(math.radians(angle)), room_side * math.sin(math.radians(angle))
            cx, cz = hinge[0] + dirx * leaf_w / 2, hinge[2] + dirz * leaf_w / 2
            yaw = math.degrees(math.atan2(dirx, dirz))
        part(props, "DoorLeaf", [0.3, DOOR_H - 0.4, leaf_w - 0.2], [cx, (DOOR_H - 0.4) / 2, cz],
                    (88, 108, 100), "Metal", m=rot(yaw=yaw))
    elif roll < 0.9:
        # deur ligt op de grond
        if ax == "z":
            pos = [dx + room_side * (DOOR_H / 2 + 1), 0.3, dz + R.uniform(-1, 1)]
        else:
            pos = [dx + R.uniform(-1, 1), 0.3, dz + room_side * (DOOR_H / 2 + 1)]
        part(props, "DoorLeafFallen", [DOOR_H - 0.4, 0.3, leaf_w - 0.2], pos, (88, 108, 100), "Metal", m=rot(yaw=R.uniform(0, 360), roll=R.uniform(-4, 4)))

# vloeren en plafonds per gebied
FLOOR_COLOR = {"corridor": FLOOR_CORRIDOR, "hall": (105, 102, 95), "patient": FLOOR_ROOM, "nurse": FLOOR_ROOM, "bath": TILE_WHITE,
               "surgery": (150, 160, 158), "morgue": FLOOR_DARK, "ward": FLOOR_ROOM, "records": (95, 88, 80), "storage": (90, 88, 82), "office": (95, 80, 65)}
FLOOR_MAT = {"records": "Concrete", "storage": "Concrete", "office": "WoodPlanks", "hall": "Marble"}
holes = []
for name, x1, z1, x2, z2, kind in AREAS:
    if name in ("cross",):
        # alleen de stukken buiten de hoofdgang
        rects = [(x1, z1, -5, z2), (5, z1, x2, z2)]
    else:
        rects = [(x1, z1, x2, z2)]
    for rx1, rz1, rx2, rz2 in rects:
        w, d = rx2 - rx1, rz2 - rz1
        cx, cz = (rx1 + rx2) / 2, (rz1 + rz2) / 2
        part(floors, "Floor_" + name, [w, 1, d], [cx, -0.5, cz], FLOOR_COLOR[kind], FLOOR_MAT.get(kind, "CeramicTiles"))
        # plafond in tegels van ~10 studs; sommige zijn ingestort
        nx, nz = max(1, round(w / 10)), max(1, round(d / 10))
        tw, td = w / nx, d / nz
        for i in range(nx):
            for j in range(nz):
                tx, tz = rx1 + tw * (i + 0.5), rz1 + td * (j + 0.5)
                if R.random() < 0.12 and name not in ("reception",):
                    holes.append((tx, tz, tw, td))
                    continue
                c = tuple(int(v * R.uniform(0.8, 1.0)) for v in (140, 140, 132))
                part(ceilings, "CeilingTile", [tw, 0.6, td], [tx, H + 0.3, tz], c, "Plaster")
# dicht "plenum" boven het systeemplafond
part(ceilings, "Plenum", [X1 - X0 + 4, 1, Z1 - Z0 + 4], [0, H + 6.5, (Z0 + Z1) / 2], (40, 40, 40), "Concrete")
part(ceilings, "Roof", [X1 - X0 + 6, 1, Z1 - Z0 + 6], [0, H + 8, (Z0 + Z1) / 2], (35, 35, 35), "Concrete")
part(floors, "Ground", [400, 2, 400], [0, -2, -15], (40, 38, 34), "Ground")

# ingestorte plafondtegels: puin + hangende tegel + kabels
for tx, tz, tw, td in holes:
    for _ in range(R.randint(3, 6)):
        s = [R.uniform(1.5, 4), R.uniform(0.2, 0.5), R.uniform(1.5, 4)]
        part(decor, "CeilingDebris", s, [tx + R.uniform(-tw / 3, tw / 3), s[1] / 2 + 0.05, tz + R.uniform(-td / 3, td / 3)],
             (120, 120, 112), "Plaster", m=rot(yaw=R.uniform(0, 360), roll=R.uniform(-12, 12), pitch=R.uniform(-8, 8)))
    part(decor, "HangingTile", [tw * 0.45, 0.4, td * 0.9], [tx - tw / 4, H - 2.5, tz], (125, 125, 118), "Plaster",
         m=rot(roll=R.choice((-55, 55))), collide=False)
    for _ in range(2):
        L = R.uniform(4, 8)
        part(decor, "Cable", [0.15, L, 0.15], [tx + R.uniform(-2, 2), H + 0.5 - L / 2, tz + R.uniform(-2, 2)], (20, 20, 20), "Rubber",
             m=rot(roll=R.uniform(-15, 15), pitch=R.uniform(-15, 15)), collide=False, shadow=False)

# ---------------------------------------------------------------- licht
FLICKER = ["Flicker"]


def fluorescent(x, z, along_x=True, state=None):
    state = state or R.choices(["on", "flicker", "dead"], weights=[3, 4, 3])[0]
    size = [5, 0.35, 1.4] if along_x else [1.4, 0.35, 5]
    part(lights_g, "LightHousing", [size[0] + 0.4, 0.3, size[2] + 0.4], [x, H - 0.15, z], (110, 112, 105), "Metal")
    if state == "dead":
        # soms half naar beneden gevallen
        if R.random() < 0.35:
            part(lights_g, "LightFallen", size, [x, H - 2.2, z], (60, 62, 58), "Glass", m=rot(roll=R.choice((-35, 35)) if along_x else 0, pitch=0 if along_x else R.choice((-35, 35))), collide=False)
        else:
            part(lights_g, "LightDead", size, [x, H - 0.45, z], (60, 62, 58), "Glass", collide=False)
        return
    part(lights_g, "Fluorescent", size, [x, H - 0.45, z], (215, 235, 225), "Neon", transparency=0.1, collide=False, shadow=False,
         tags=FLICKER if state == "flicker" else None,
         children=[light("SurfaceLight", (205, 240, 220), 1.4 if state == "on" else 1.8, 20, {"Face": "Bottom", "Angle": 120})] if state else None)
    if state == "flicker":
        # Flicker.server zoekt een PointLight; geef er een zwakke bij
        lights_g.node["children"][-1]["children"].append(light("PointLight", (200, 235, 215), 0.3, 8))


def emergency(x, y, z):
    part(lights_g, "EmergencyLight", [1.2, 0.5, 0.5], [x, y, z], (200, 20, 20), "Neon", collide=False, shadow=False,
         tags=FLICKER if R.random() < 0.4 else None, children=[light("PointLight", (255, 30, 20), 0.9, 14)])


# gangen: lampen om de ~11 studs
for z in range(-64, 8, 11):
    fluorescent(0, z, along_x=False)
for x in list(range(-55, -6, 11)) + list(range(10, 60, 11)):
    fluorescent(x, -25, along_x=True)
# hal: een paar, de meeste kapot
for x, z in ((-12, 18), (12, 18), (-12, 32), (12, 32), (0, 25)):
    fluorescent(x, z, True, R.choice(["dead", "flicker", "dead"]))
# kamers
for name, x1, z1, x2, z2, kind in AREAS:
    if kind in ("corridor", "hall"):
        continue
    w, d = x2 - x1, z2 - z1
    n = max(1, round(w * d / 220))
    for i in range(n):
        if w >= d:
            fluorescent(x1 + w * (i + 0.5) / n, (z1 + z2) / 2, True)
        else:
            fluorescent((x1 + x2) / 2, z1 + d * (i + 0.5) / n, False)
# noodlampjes boven een paar deuren
for dx, dz, ax, w, sign in DOORS:
    if sign and R.random() < 0.5:
        labs = [label(dx - 1, dz), label(dx, dz)] if ax == "z" else [label(dx, dz - 1), label(dx, dz)]
        s = -1 if labs[0] in CORRIDORS else 1
        if ax == "z":
            emergency(dx + s * 0.8, H - 1.2, dz + w / 2 + 1)
        else:
            emergency(dx + w / 2 + 1, H - 1.2, dz + s * 0.8)

# ---------------------------------------------------------------- ramen (dichtgetimmerd, maanlicht)
for axis, line, a, b, sa, sb in segments:
    if sa is not None and sb is not None:
        continue
    if (sa or sb) == "morgue":  # daar staat de muur met lijkenladen
        continue
    s_in = -1 if sa is not None else 1  # richting naar binnen
    length = b - a
    if length < 8:
        continue
    n = int((length - 4) // 13)
    for i in range(n):
        t = a + 4 + (length - 8) * (i + 0.5) / max(n, 1)
        if axis == "z":
            pos = [line + s_in * 0.62, 7.5, t]
            yaw = 90
        else:
            pos = [t, 7.5, line + s_in * 0.62]
            yaw = 0
        m = rot(yaw=yaw)
        part(decor, "WindowGlass", [5, 5, 0.1], pos, (25, 30, 38), "Glass", m=m, transparency=0.2, collide=False)
        part(decor, "WindowFrame", [5.6, 0.4, 0.3], local(pos, m, [0, 2.7, 0]), (60, 60, 55), "Metal", m=m)
        part(decor, "WindowFrame", [5.6, 0.4, 0.3], local(pos, m, [0, -2.7, 0]), (60, 60, 55), "Metal", m=m)
        for k in range(R.randint(2, 4)):
            part(decor, "Board", [6.2, 0.7, 0.25], local(pos, m, [0, R.uniform(-2, 2), 0.25 * s_in]),
                 (85, 66, 50), "WoodPlanks", m=matmul(m, rot(roll=R.uniform(-18, 18))))
        if R.random() < 0.55:
            # maanlicht dat door de planken valt
            lp = [pos[0] + (s_in * 0.6 if axis == "z" else 0), 8.5, pos[2] + (s_in * 0.6 if axis == "x" else 0)]
            face = "Right" if (axis == "z" and s_in > 0) else "Left" if axis == "z" else ("Back" if s_in > 0 else "Front")
            part(lights_g, "MoonLight", [1, 1, 1], lp, (0, 0, 0), transparency=1, collide=False, shadow=False,
                 children=[light("SpotLight", (120, 140, 200), 1.6, 26, {"Face": face, "Angle": 50})])

# ---------------------------------------------------------------- props
def bed(g, x, z, yaw, wrecked=False, body=False):
    m = rot(yaw=yaw, roll=R.uniform(-6, 6) if wrecked else 0)
    base = [x, 0, z]
    def p(name, size, off, col, mat="Metal", **kw):
        return part(g, name, size, local(base, m, off), col, mat, m=m, **kw)
    p("BedFrame", [3.4, 0.35, 7.2], [0, 2.1, 0], METAL)
    p("Mattress", [3.1, 0.6, 6.6], [0, 2.6, 0], FABRIC_DIRTY if R.random() < 0.6 else FABRIC, "Fabric")
    p("Headboard", [3.4, 2.6, 0.25], [0, 3.1, -3.5], METAL)
    p("Footboard", [3.4, 1.6, 0.25], [0, 2.6, 3.5], METAL)
    for sx in (-1.5, 1.5):
        for sz in (-3.3, 3.3):
            p("BedLeg", [0.2, 2, 0.2], [sx, 1, sz], METAL_DARK)
    p("Rail", [0.12, 0.12, 3.5], [1.65, 3.3, -1], METAL)
    if R.random() < 0.6:
        p("Pillow", [2.2, 0.5, 1.2], [0, 3.1, -2.6], FABRIC, "Fabric")
    if body or R.random() < 0.25:
        # iets onder het laken...
        p("SheetBody", [1.6, 0.8, 5.2], [0, 3.2, 0.4], (190, 185, 170), "Fabric")
        p("SheetHead", [1.1, 0.8, 1.1], [0, 3.25, -2.3], (190, 185, 170), "Fabric")
    if R.random() < 0.3:
        p("BloodStain", [1.6, 0.05, 1.8], [R.uniform(-0.6, 0.6), 2.92, R.uniform(-1, 1)], BLOOD, "SmoothPlastic", collide=False, shadow=False)


def iv_stand(g, x, z):
    tilt = R.uniform(-4, 4)
    m = rot(roll=tilt)
    part(g, "IVBase", [1.6, 0.2, 1.6], [x, 0.15, z], METAL_DARK, "Metal")
    part(g, "IVPole", [0.15, 6.5, 0.15], [x, 3.4, z], METAL, "Metal", m=m)
    part(g, "IVHook", [1.4, 0.12, 0.12], [x, 6.6, z], METAL, "Metal")
    part(g, "IVBag", [0.6, 1, 0.25], [x + 0.6, 5.9, z], (200, 190, 120), "Glass", transparency=0.3, collide=False)


def curtain(g, x, z, length, along_x, color=CURTAIN):
    if along_x:
        part(g, "CurtainRail", [length, 0.15, 0.15], [x, H - 0.8, z], METAL, "Metal", collide=False)
        n = R.randint(2, 4)
        for i in range(n):
            w = length / n * R.uniform(0.6, 0.95)
            part(g, "Curtain", [w, 8.5, 0.1], [x - length / 2 + length * (i + 0.5) / n, H - 5.2, z + R.uniform(-0.2, 0.2)],
                 tuple(int(c * R.uniform(0.8, 1.0)) for c in color), "Fabric", m=rot(yaw=R.uniform(-8, 8)), collide=False)
    else:
        part(g, "CurtainRail", [0.15, 0.15, length], [x, H - 0.8, z], METAL, "Metal", collide=False)
        n = R.randint(2, 4)
        for i in range(n):
            w = length / n * R.uniform(0.6, 0.95)
            part(g, "Curtain", [0.1, 8.5, w], [x + R.uniform(-0.2, 0.2), H - 5.2, z - length / 2 + length * (i + 0.5) / n],
                 tuple(int(c * R.uniform(0.8, 1.0)) for c in color), "Fabric", m=rot(yaw=R.uniform(-8, 8)), collide=False)


def wheelchair(g, x, z, yaw, tipped=False):
    m = rot(yaw=yaw, roll=80 if tipped else 0)
    base = [x, 1.4 if tipped else 0, z]
    def p(name, size, off, col, mat="Metal", **kw):
        return part(g, name, size, local(base, m, off), col, mat, m=m, **kw)
    p("WCSeat", [2, 0.25, 2], [0, 1.8, 0], (40, 40, 45), "Fabric")
    p("WCBack", [2, 2, 0.2], [0, 2.9, 1], (40, 40, 45), "Fabric")
    for s in (-1.15, 1.15):
        part(g, "WCWheel", [0.15, 2.8, 2.8], local(base, m, [s, 1.4, 0.3]), METAL_DARK, "Metal", m=matmul(m, rot()), shape="Cylinder")
        p("WCFront", [0.15, 0.7, 0.7], [s * 0.85, 0.35, -1], METAL_DARK, shape="Cylinder")


def cabinet(g, x, z, yaw, w=3, h=7, d=1.6, col=(130, 140, 135), open_door=False):
    m = rot(yaw=yaw)
    base = [x, 0, z]
    part(g, "Cabinet", [w, h, d], local(base, m, [0, h / 2, 0]), col, "Metal", m=m)
    if open_door:
        part(g, "CabinetDoor", [w / 2, h - 0.4, 0.12], local(base, m, [-w / 2 - 0.2, h / 2, -d / 2 - w / 4]), col, "Metal", m=matmul(m, rot(yaw=80)))
    for k in range(3):
        part(g, "Handle", [0.4, 0.1, 0.1], local(base, m, [w / 4, h * (k + 1) / 4, -d / 2 - 0.05]), METAL_DARK, "Metal", m=m)


def papers(g, x, z, n, spread=4):
    for _ in range(n):
        part(g, "Paper", [0.85, 0.03, 1.1], [x + R.uniform(-spread, spread), 0.03, z + R.uniform(-spread, spread)],
             (200, 195, 175), "SmoothPlastic", m=rot(yaw=R.uniform(0, 360)), collide=False, shadow=False)


def blood(g, x, y, z, w, d, wall_axis=None):
    if wall_axis is None:
        part(g, "Blood", [w, 0.04, d], [x, 0.03, z], BLOOD, "SmoothPlastic", m=rot(yaw=R.uniform(0, 360)), collide=False, shadow=False)
    elif wall_axis == "z":
        part(g, "BloodWall", [0.04, d, w], [x, y, z], BLOOD, "SmoothPlastic", m=rot(pitch=R.uniform(-20, 20)), collide=False, shadow=False)
    else:
        part(g, "BloodWall", [w, d, 0.04], [x, y, z], BLOOD, "SmoothPlastic", m=rot(roll=R.uniform(-20, 20)), collide=False, shadow=False)


def writing(g, text, pos, yaw, w=10, h=3):
    part(g, "WallWriting", [w, h, 0.05], pos, (0, 0, 0), transparency=1, m=rot(yaw=yaw), collide=False, shadow=False,
         children=[text_gui(text, "Back", (110, 8, 8), "Creepster", 1)])


def chair(g, x, z, yaw, fallen=False):
    m = rot(yaw=yaw, roll=90 if fallen else 0)
    base = [x, 1.0 if fallen else 0, z]
    col = (60, 90, 110)
    part(g, "ChairSeat", [1.8, 0.25, 1.8], local(base, m, [0, 1.8, 0]), col, "Plastic", m=m)
    part(g, "ChairBack", [1.8, 1.8, 0.2], local(base, m, [0, 2.8, 0.8]), col, "Plastic", m=m)
    for sx in (-0.8, 0.8):
        part(g, "ChairLeg", [0.12, 1.8, 0.12], local(base, m, [sx, 0.9, 0]), METAL_DARK, "Metal", m=m)


def debris(g, x, z, n, spread=3):
    for _ in range(n):
        s = R.uniform(0.4, 1.4)
        part(g, "Rubble", [s, s * R.uniform(0.5, 1), s * R.uniform(0.6, 1.2)], [x + R.uniform(-spread, spread), s / 3, z + R.uniform(-spread, spread)],
             (115, 112, 105), "Concrete", m=rot(yaw=R.uniform(0, 360), pitch=R.uniform(-30, 30), roll=R.uniform(-30, 30)))


def gurney(g, x, z, yaw, body=True):
    m = rot(yaw=yaw)
    base = [x, 0, z]
    part(g, "Gurney", [2.6, 0.3, 6.5], local(base, m, [0, 2.8, 0]), METAL, "Metal", m=m)
    for sx in (-1.1, 1.1):
        for sz in (-2.8, 2.8):
            part(g, "GurneyLeg", [0.15, 2.6, 0.15], local(base, m, [sx, 1.4, sz]), METAL_DARK, "Metal", m=m)
            part(g, "Caster", [0.3, 0.4, 0.4], local(base, m, [sx, 0.2, sz]), (25, 25, 25), "Rubber", m=m, shape="Cylinder")
    if body:
        part(g, "SheetBody", [1.6, 0.9, 4.8], local(base, m, [0, 3.4, 0.4]), (195, 192, 180), "Fabric", m=m)
        part(g, "SheetHead", [1.1, 0.9, 1.1], local(base, m, [0, 3.45, -2.4]), (195, 192, 180), "Fabric", m=m)
        part(g, "Toe", [1.5, 0.05, 0.8], local(base, m, [0, 3.0, 3.2]), (180, 175, 160), "SmoothPlastic", m=m, collide=False)


# --- receptie
rec = props.sub("Reception")
part(rec, "Desk", [16, 3.6, 2], [0, 1.8, 18], WOOD, "WoodPlanks")
part(rec, "DeskTop", [16.6, 0.3, 2.6], [0, 3.75, 18], (60, 50, 42), "Wood")
part(rec, "DeskSide", [2, 3.6, 7], [-8, 1.8, 15.5], WOOD, "WoodPlanks")
part(rec, "DeskSide", [2, 3.6, 7], [8, 1.8, 15.5], WOOD, "WoodPlanks")
for x in (-4, 3):
    part(rec, "Monitor", [2, 1.6, 0.3], [x, 4.8, 17.6], (30, 30, 32), "SmoothPlastic", m=rot(yaw=R.uniform(-15, 15)))
    part(rec, "MonitorStand", [0.4, 0.8, 0.4], [x, 4.2, 17.7], (30, 30, 32), "SmoothPlastic")
part(rec, "MonitorFallen", [2, 1.6, 0.3], [6, 0.2, 21], (30, 30, 32), "SmoothPlastic", m=rot(pitch=90, yaw=40))
papers(rec, 0, 22, 25, 8)
for row, z in enumerate((27, 31)):
    for i in range(7):
        x = -15 + i * 2.2 if row == 0 else 4 + i * 2.2
        if R.random() < 0.8:
            chair(rec, x, z, 180, fallen=R.random() < 0.2)
part(rec, "Column", [2.5, H, 2.5], [-12, H / 2, 25], PLASTER, "Plaster")
part(rec, "Column", [2.5, H, 2.5], [12, H / 2, 25], PLASTER, "Plaster")
# voordeur: dicht en vastgeketend
for s in (-1, 1):
    part(rec, "EntranceDoor", [5, 10, 0.4], [s * 2.6, 5, 39.3], (60, 75, 70), "Metal")
    part(rec, "EntranceGlass", [3.4, 4, 0.1], [s * 2.6, 6.5, 39.05], (30, 35, 40), "Glass", transparency=0.3)
for i in range(12):
    t = i / 11
    part(rec, "Chain", [0.5, 0.25, 0.15], [-2.5 + 5 * t, 4.6 + math.sin(t * math.pi) * -0.6, 38.9], (90, 85, 80), "Metal",
         m=rot(roll=(i % 2) * 90 + R.uniform(-15, 15)), collide=False)
part(rec, "Padlock", [0.7, 0.9, 0.35], [0, 4, 38.8], (100, 90, 50), "Metal")
part(rec, "ExitSign", [3, 1, 0.3], [0, 11.5, 39.3], (120, 10, 10), "Neon", tags=FLICKER,
     children=[light("PointLight", (255, 40, 30), 0.8, 12), text_gui("EXIT", "Front", (255, 220, 220), "SpecialElite", 0)])
part(rec, "HospitalSign", [14, 2.2, 0.3], [0, 11.2, 10.8], (30, 40, 38), "SmoothPlastic",
     children=[text_gui("ST. MERCY HOSPITAL", "Back", (170, 175, 160), "SpecialElite", 1)])
writing(decor, "THEY NEVER LEFT", [-20, 8, 39.4], 180, 12, 3)
blood(decor, -6, 0, 26, 3, 5)
blood(decor, -5, 0, 20, 1.5, 6)
wheelchair(rec, 18, 30, 210, tipped=True)

# --- patiÃ«ntenkamers
for name, x1, z1, x2, z2, kind in AREAS:
    if kind != "patient":
        continue
    g = props.sub(name)
    cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
    w, d = x2 - x1, z2 - z1
    if w > d:
        for i, bx in enumerate((x1 + w * 0.3, x1 + w * 0.7)):
            bed(g, bx, z1 + 4.5, 0 if z1 > -20 else 0, wrecked=R.random() < 0.5)
            iv_stand(g, bx + 2.6, z1 + 3)
        curtain(g, cx, z1 + 9, w - 4, True)
    else:
        for i, bz in enumerate((z1 + d * 0.3, z1 + d * 0.7)):
            bed(g, x1 + 4.5, bz, 90, wrecked=R.random() < 0.5)
            iv_stand(g, x1 + 3, bz + 2.8)
        curtain(g, x1 + 9, cz, d - 4, False)
    cabinet(g, x2 - 1.5, z2 - 2.5, 90, 2.5, 4, 1.4, (150, 150, 140), open_door=R.random() < 0.5)
    if R.random() < 0.5:
        wheelchair(g, cx + R.uniform(-2, 2), cz + R.uniform(-2, 2), R.uniform(0, 360), tipped=R.random() < 0.4)
    papers(g, cx, cz, 6, 4)
    if R.random() < 0.6:
        blood(decor, cx + R.uniform(-3, 3), 0, cz + R.uniform(-3, 3), R.uniform(1.5, 3), R.uniform(2, 5))

# --- verpleegpost
g = props.sub("NurseStation")
part(g, "Counter", [12, 3.6, 2], [15, 1.8, 6.5], (120, 125, 118), "Plastic")
part(g, "CounterTop", [12.6, 0.3, 2.6], [15, 3.75, 6.5], (90, 95, 90), "Plastic")
for x in (8, 11):
    cabinet(g, x, -3.5, 180, 2.8, 6, 1.6)
cabinet(g, 23.5, -1, 90, 2.8, 6, 1.6, open_door=True)
papers(g, 15, 0, 18, 6)
chair(g, 13, 3, 20, fallen=True)
writing(decor, "DON'T LOOK UP", [24.4, 7, 2], -90, 9, 2.5)

# --- toiletten
g = props.sub("Bathroom")
for i in range(4):
    x = 8 + i * 4.2
    part(g, "StallWall", [0.2, 7, 6], [x - 2.1, 3.6, -16.5], (110, 120, 115), "Plastic")
    if R.random() < 0.7:
        part(g, "StallDoor", [3.6, 6, 0.15], [x, 3.4, -13.4], (110, 120, 115), "Plastic", m=rot(yaw=R.uniform(-70, 0)))
    part(g, "Toilet", [1.6, 1.6, 2.2], [x, 0.8, -18.4], (190, 190, 185), "Marble")
part(g, "StallWall", [0.2, 7, 6], [8 + 4 * 4.2 - 2.1, 3.6, -16.5], (110, 120, 115), "Plastic")
for i in range(3):
    x = 9 + i * 5
    part(g, "Sink", [2.2, 0.6, 1.6], [x, 3.2, -5.9], (190, 190, 185), "Marble")
    part(g, "Mirror", [2.6, 3, 0.1], [x, 6.3, -5.55], (30, 35, 40) if R.random() < 0.6 else (160, 170, 175), "Glass", transparency=0.1, collide=False)
blood(decor, 14, 0, -9, 2, 4)
writing(decor, "IT HEARS YOU", [14, 9.5, -5.45], 180, 10, 2.5)

# --- ok (operatiekamer)
g = props.sub("Surgery")
part(g, "OpTable", [3.2, 0.5, 7.5], [-17, 3.2, -50], (170, 175, 175), "Metal")
part(g, "OpTableBase", [1.5, 3, 2.5], [-17, 1.5, -50], METAL_DARK, "Metal")
part(g, "OpBody", [1.7, 0.9, 5.2], [-17, 3.9, -49.6], (195, 192, 180), "Fabric")
blood(g, -17, 3.47, -51, 2.6, 3)
blood(decor, -16, 0, -47, 3, 4)
part(g, "SurgeryLampArm", [0.4, 4, 0.4], [-17, H - 2, -50], METAL, "Metal")
part(g, "SurgeryLamp", [1, 4.5, 4.5], [-17, H - 4.2, -50], (220, 225, 220), "Metal", m=rot(roll=90 + 12), shape="Cylinder",
     tags=FLICKER, children=[light("SpotLight", (230, 245, 255), 3, 22, {"Face": "Left", "Angle": 50}), light("PointLight", (230, 245, 255), 0.5, 10)])
for k in range(2):
    x = -24 + k * 13
    part(g, "TrayCart", [3, 0.2, 2], [x, 3.4, -44], METAL, "Metal")
    part(g, "TrayCartShelf", [2.8, 0.15, 1.8], [x, 1.0, -44], METAL, "Metal")
    for sx in (-1.3, 1.3):
        for sz in (-0.8, 0.8):
            part(g, "TrayCartLeg", [0.12, 3.3, 0.12], [x + sx, 1.65, -44 + sz], METAL_DARK, "Metal")
    for _ in range(4):
        part(g, "Tool", [0.1, 0.05, 1.2], [x + R.uniform(-1, 1), 3.55, -44 + R.uniform(-0.6, 0.6)], (200, 200, 205), "Metal", m=rot(yaw=R.uniform(0, 180)), collide=False)
for k in range(3):
    part(g, "OxygenTank", [0.9, 4, 0.9], [-28 + k * 1.1, 2, -67.5], (40, 110, 60), "Metal", shape=None, m=rot(roll=R.choice((0, 0, 75))))
part(g, "Monitor", [2.5, 2, 1.5], [-11, 5.5, -50], (30, 30, 32), "SmoothPlastic")
part(g, "MonitorScreen", [2.1, 1.5, 0.05], [-11, 5.6, -50.78], (20, 120, 40), "Neon", tags=FLICKER, collide=False,
     children=[light("PointLight", (40, 255, 90), 0.4, 6)])
part(g, "MonitorPole", [0.2, 4.5, 0.2], [-11, 2.25, -50], METAL, "Metal")
curtain(g, -17, -40, 18, True, (110, 140, 150))
writing(decor, "NO ANESTHESIA", [-29.4, 8, -55], 90, 12, 3)

# --- mortuarium (hier spawnt de Crawler)
g = props.sub("Morgue")
for row in range(3):
    for col in range(6):
        x = 8 + col * 3.6
        y = 1.8 + row * 3.4
        part(g, "BodyDrawer", [3.2, 3, 0.2], [x, y, -69.4], (150, 155, 155), "Metal")
        part(g, "DrawerHandle", [1, 0.25, 0.25], [x, y + 0.6, -69.2], METAL_DARK, "Metal")
        if (row, col) in ((0, 2), (1, 4)):
            part(g, "DrawerOut", [3, 0.3, 6], [x, y - 0.9, -66], (150, 155, 155), "Metal")
            part(g, "SheetBody", [1.5, 0.8, 4.8], [x, y - 0.4, -66], (195, 192, 180), "Fabric")
part(g, "DrawerWall", [23, 11, 1.2], [17, 5.5, -69.9], (110, 115, 115), "Metal")
gurney(g, 14, -50, 15)
gurney(g, 23, -44, -30)
gurney(g, 10, -38, 80, body=False)
part(g, "AutopsyTable", [3.2, 0.4, 7], [20, 3.2, -56], (170, 175, 175), "Metal")
part(g, "AutopsyBase", [1.5, 3, 2], [20, 1.5, -56], METAL_DARK, "Metal")
part(g, "Drain", [1.2, 0.05, 1.2], [20, 0.03, -56], (20, 20, 20), "Metal", collide=False)
blood(decor, 20, 0, -54, 2.5, 6)
blood(decor, 17, 0, -48, 1.5, 7)
part(g, "MorgueLight", [1, 1, 1], [17, H - 1.5, -55], (0, 0, 0), transparency=1, collide=False, tags=FLICKER,
     children=[light("PointLight", (140, 170, 255), 1.2, 22)])
part(markers, "CrawlerSpawn", [4, 1, 4], [17, 0.5, -62], (255, 0, 0), transparency=1, collide=False)
writing(decor, "IT CRAWLS", [29.4, 8, -50], -90, 10, 3)

# --- zaal met 6 bedden
g = props.sub("Ward")
for i in range(3):
    for side in (-1, 1):
        x = -55 + i * 9.5
        z = -45 + side * 10
        bed(g, x, z, 0 if side < 0 else 180, wrecked=R.random() < 0.4, body=R.random() < 0.3)
        if R.random() < 0.6:
            iv_stand(g, x + 2.6, z + side * -1)
        curtain(g, x + 4.6, z, 8, False)
wheelchair(g, -40, -45, 130)
papers(g, -45, -45, 8, 8)
blood(decor, -48, 0, -44, 2, 6)

# --- archief
g = props.sub("Records")
for i in range(4):
    x = 35 + i * 6.5
    for k in range(3):
        z = -55 + k * 7
        part(g, "Shelf", [1.6, 9, 6], [x, 4.5, z], (90, 92, 88), "Metal", transparency=0)
        for lvl in range(4):
            for b in range(3):
                if R.random() < 0.75:
                    part(g, "Box", [1.4, 1.4, 1.6], [x, 1 + lvl * 2.2 + 0.75, z - 2 + b * 2], (150, 120, 85), "Cardboard",
                         m=rot(yaw=R.uniform(-10, 10)))
    if R.random() < 0.5:
        for _ in range(4):
            part(g, "BoxFallen", [1.4, 1.4, 1.6], [x + R.uniform(1.5, 3), 0.7, -48 + R.uniform(-6, 6)], (150, 120, 85), "Cardboard",
                 m=rot(yaw=R.uniform(0, 360), roll=R.uniform(-20, 20)))
papers(g, 45, -40, 30, 10)

# --- opslag
g = props.sub("Storage")
for i in range(5):
    part(g, "Crate", [3, 3, 3], [-39 + i * 3.2, 1.5, -2.5], (110, 85, 60), "WoodPlanks", m=rot(yaw=R.uniform(-8, 8)))
for i in range(3):
    part(g, "Crate", [3, 3, 3], [-38 + i * 3.4, 4.5, -2.5], (110, 85, 60), "WoodPlanks", m=rot(yaw=R.uniform(-8, 8)))
cabinet(g, -27, -15, -90, 3, 7, 1.6, open_door=True)
gurney(g, -34, -12, 40, body=False)
wheelchair(g, -38, -8, 200)

# --- kantoor
g = props.sub("Office")
part(g, "Desk", [7, 0.4, 3.5], [33, 3.3, -8], (80, 60, 45), "Wood")
part(g, "DeskBody", [6.6, 3.1, 3.2], [33, 1.55, -8], (70, 52, 40), "WoodPlanks")
chair(g, 33, -5, 0, fallen=True)
cabinet(g, 27, -17, 0, 3, 6, 1.6)
cabinet(g, 30.5, -17, 0, 3, 6, 1.6, open_door=True)
papers(g, 33, -10, 20, 5)
part(g, "DeskLamp", [0.6, 1.4, 0.6], [35, 4.2, -8.5], (40, 40, 40), "Metal", tags=FLICKER,
     children=[light("PointLight", (255, 200, 120), 0.7, 12)])
writing(decor, "WE TRIED TO STOP IT", [33, 8, -19.4], 0, 14, 3)

# --- trappenhuis: ingestort einde van de hoofdgang
g = props.sub("CollapsedStairs")
debris(g, 0, -66, 30, 4)
for k in range(5):
    part(g, "Slab", [R.uniform(4, 8), 0.8, R.uniform(3, 5)], [R.uniform(-3, 3), 1 + k * 1.3, -67 + R.uniform(-1, 1)], (110, 108, 100), "Concrete",
         m=rot(yaw=R.uniform(-30, 30), roll=R.uniform(-25, 25), pitch=R.uniform(-15, 15)))
part(g, "Rebar", [0.15, 6, 0.15], [1, 5, -66], RUST, "Metal", m=rot(roll=35))
part(g, "Rebar", [0.15, 5, 0.15], [-1.5, 6, -67], RUST, "Metal", m=rot(roll=-20, pitch=25))

# --- leidingen langs de gangplafonds
for x, z1, z2 in ((-3.8, -70, 10),):
    part(decor, "Pipe", [z2 - z1, 0.8, 0.8], [x, H - 1.1, (z1 + z2) / 2], RUST, "Metal", collide=False, shape="Cylinder", m=rot(yaw=90))
part(decor, "Pipe", [120, 0.6, 0.6], [0, H - 1.0, -21.2], (70, 75, 72), "Metal", collide=False, shape="Cylinder")
part(decor, "Pipe", [120, 0.4, 0.4], [0, H - 1.7, -21.2], RUST, "Metal", collide=False, shape="Cylinder")

# --- losse rommel in de gangen
for _ in range(14):
    x, z = (R.uniform(-3.5, 3.5), R.uniform(-60, 8)) if R.random() < 0.5 else (R.uniform(-55, 55), R.uniform(-28.5, -21.5))
    papers(decor, x, z, R.randint(2, 6), 2)
for _ in range(6):
    blood(decor, R.uniform(-3, 3), 0, R.uniform(-60, 5), R.uniform(0.6, 1.6), R.uniform(1, 3))
gurney(props, 2.5, -40, 175, body=R.random() < 0.5)
wheelchair(props, -40, -24, 75)
writing(decor, "RUN", [-4.4, 7, -36], 90, 6, 3)
writing(decor, "HELP US", [40, 7, -29.4], 0, 9, 2.5)
# sleepspoor van bloed richting mortuarium
for k in range(10):
    blood(decor, R.uniform(-1, 1) + 0.4 * k / 10, 0, -30 - k * 2.6, 0.9, 2.2)

# ---------------------------------------------------------------- spawn
spawn_props = {
    "Anchored": True,
    "Size": [8, 1, 6],
    "CFrame": cframe([0, 0.5, 34], rot(yaw=0)),
    "Transparency": 1,
    "CanCollide": False,
    "Duration": 0,
    "Neutral": True,
}
markers.add({"name": "SpawnLocation", "className": "SpawnLocation", "properties": spawn_props})

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf8") as f:
    json.dump(root.node, f, separators=(",", ":"))
print(f"Hospital: {COUNT['parts']} parts, {COUNT['lights']} lichten, {len(segments)} muursegmenten -> {os.path.relpath(OUT, ROOT)}")
