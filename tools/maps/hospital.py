# Genereert de map "verlaten ziekenhuis" als Rojo model-bestand (maps/Hospital.model.json).
# Gebruik: python tools/maps/hospital.py
# Alles is Parts (geen uploads nodig), dus Rojo kan het direct in Workspace syncen.
#
# Opbouw: een netwerk van gangen; langs elke gang liggen "stroken" die automatisch in kamers worden
# verdeeld. Elke kamersoort heeft een eigen inrichting (fill_*). Twee binnenplaatsen liggen buiten.
# De receptie (voordeur, stroomkast, uitgang, spawn) staat vast op dezelfde plek: Round.server.luau
# (Stijn) gebruikt de namen/tags EntranceDoor, EntranceGlass, Chain, Padlock, FuseBox, FuseSpawn, ExitZone,
# Mirror en CrawlerSpawn.
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
    return [round(min(255, max(0, r)) / 255, 4), round(min(255, max(0, g)) / 255, 4), round(min(255, max(0, b)) / 255, 4)]


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


def tint(col, lo=0.85, hi=1.05):
    f = R.uniform(lo, hi)
    return tuple(int(c * f) for c in col)


class Group:
    def __init__(self, name, class_name="Folder", top=False):
        self.node = {"className": class_name, "children": []} if top else {"name": name, "className": class_name, "children": []}

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
        "Size": [round(max(s, 0.05), 4) for s in size],
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


def light(kind, color, brightness, rng, extra=None, shadows=True):
    COUNT["lights"] += 1
    props = {"Color": rgb(*color), "Brightness": brightness, "Range": rng, "Shadows": shadows}
    props.update(extra or {})
    return {"name": kind, "className": kind, "properties": props}


def local(origin, m, offset):
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
SHEET = (195, 192, 180)
FRAME = (60, 75, 70)

WRITINGS = ["THEY NEVER LEFT", "RUN", "HELP US", "IT HEARS YOU", "DON'T LOOK UP", "IT CRAWLS", "TURN BACK",
            "IT'S IN THE WALLS", "COUNT THE BODIES", "SHE WATCHES", "NO WAY OUT", "WE TRIED TO STOP IT", "HIDE",
            "DON'T LET IT SEE YOU", "WHERE DID THEY TAKE US", "LIGHTS OFF = DEAD"]

# ---------------------------------------------------------------- plattegrond
# Gangen en vaste ruimtes: (naam, x1, z1, x2, z2, soort)
FIXED = [
    ("reception", -25, 10, 25, 40, "hall"),
    ("crossA", -130, -30, 130, -20, "corridor"),
    ("crossB", -130, -110, 130, -100, "corridor"),
    ("crossC", -70, -160, 70, -150, "corridor"),
    ("sideW", -130, -110, -120, -20, "corridor"),
    ("sideE", 120, -110, 130, -20, "corridor"),
    ("main", -5, -160, 5, 10, "corridor"),
    ("yardW", -102, -82, -23, -48, "yard"),
    ("yardE", 23, -82, 102, -48, "yard"),
]
CORRIDORS = {"reception", "crossA", "crossB", "crossC", "sideW", "sideE", "main"}
OPEN = {frozenset(p) for p in [("reception", "main"), ("main", "crossA"), ("main", "crossB"), ("main", "crossC"),
                               ("crossA", "sideW"), ("crossA", "sideE"), ("crossB", "sideW"), ("crossB", "sideE")]}

# Kamersoorten: (min breedte, max breedte, gewicht)
KINDS = {
    "patient": (14, 18, 6),
    "ward": (24, 30, 2),
    "office": (12, 16, 2),
    "bath": (16, 20, 1.5),
    "storage": (12, 16, 2),
    "records": (20, 26, 1),
    "lab": (16, 22, 1.5),
    "cell": (10, 12, 2),
    "xray": (16, 18, 1),
    "dayroom": (22, 28, 1),
    "boiler": (16, 20, 0.8),
    "collapsed": (12, 16, 1),
    "nurse": (14, 18, 1),
}

# Stroken langs de gangen: (x1, z1, x2, z2, muur met deuren, soorten of None = willekeurig)
STRIPS = [
    (-23, -2, -5, 10, "x2", ["nurse"]),
    (5, -2, 23, 10, "x1", ["nurse"]),
    (-130, -20, -5, -2, "z1", None),
    (5, -20, 130, -2, "z1", None),
    (-120, -48, -5, -30, "z2", None),
    (5, -48, 120, -30, "z2", None),
    (-120, -100, -5, -82, "z1", None),
    (5, -100, 120, -82, "z1", None),
    (-120, -82, -102, -48, "x1", None),
    (102, -82, 120, -48, "x2", None),
    (-23, -82, -5, -48, "x2", None),
    (5, -82, 23, -48, "x1", None),
    (-148, -110, -130, -20, "x2", None),
    (130, -110, 148, -20, "x1", None),
    (-130, -130, -5, -110, "z2", None),
    (5, -130, 130, -110, "z2", None),
    (-70, -150, -5, -130, "z1", None),
    (5, -150, 70, -130, "z1", None),
    (-70, -185, -5, -160, "z2", ["chapel", "surgery", "cafeteria"]),
    (5, -185, 70, -160, "z2", ["morgue", "lab", "surgery"]),
]
SPECIAL_W = {"chapel": 26, "surgery": 22, "cafeteria": 0, "morgue": 26}

rooms = []  # dicts: name, x1,z1,x2,z2, wall, kind
for si, (x1, z1, x2, z2, wall, forced) in enumerate(STRIPS):
    along_x = wall in ("z1", "z2")
    a0, a1 = (x1, x2) if along_x else (z1, z2)
    length = a1 - a0
    pos = a0
    k = 0
    while a1 - pos >= 10:
        if forced:
            kind = forced[k % len(forced)]
            if kind in SPECIAL_W and SPECIAL_W[kind]:
                w = SPECIAL_W[kind]
            elif kind == "cafeteria":
                w = a1 - pos
            else:
                w = R.randint(*KINDS.get(kind, (16, 20, 1))[:2])
        else:
            kind = R.choices(list(KINDS), weights=[v[2] for v in KINDS.values()])[0]
            w = R.randint(KINDS[kind][0], KINDS[kind][1])
        if a1 - (pos + w) < 10:
            w = a1 - pos
        if along_x:
            rect = (pos, z1, pos + w, z2)
        else:
            rect = (x1, pos, x2, pos + w)
        rooms.append({"name": f"r{si}_{k}", "rect": rect, "wall": wall, "kind": kind})
        pos += w
        k += 1

AREAS = [(n, x1, z1, x2, z2, kind) for n, x1, z1, x2, z2, kind in FIXED[:1] + FIXED[1:]]
AREAS += [(r["name"], *r["rect"], r["kind"]) for r in rooms]
# volgorde: kamers eerst, dan gangen (gangen winnen bij overlap), receptie en binnenplaatsen
order = [a for a in AREAS if a[0] not in CORRIDORS and a[5] != "yard"] + [a for a in AREAS if a[5] == "yard"] + \
        [a for a in AREAS if a[0] in CORRIDORS]
KIND = {a[0]: a[5] for a in AREAS}

grid = {}
for name, x1, z1, x2, z2, _ in order:
    for x in range(x1, x2):
        for z in range(z1, z2):
            grid[(x, z)] = name


def label(x, z):
    return grid.get((x, z))


# deuren: (x, z, as, breedte, bordtekst)
DOORS = []
SIGN_NAMES = {"patient": None, "ward": "WARD", "office": "OFFICE", "bath": "WC", "storage": "STORAGE", "records": "RECORDS",
              "lab": "LAB", "cell": "ISOLATION", "xray": "X-RAY", "dayroom": "DAY ROOM", "boiler": "BOILER", "collapsed": None,
              "nurse": "NURSES", "chapel": "CHAPEL", "surgery": "SURGERY", "cafeteria": "CAFETERIA", "morgue": "MORGUE"}
room_no = 100
for r in rooms:
    x1, z1, x2, z2 = r["rect"]
    w = 8 if (x2 - x1 if r["wall"] in ("z1", "z2") else z2 - z1) >= 24 else 6
    if r["wall"] == "z1":
        d = ((x1 + x2) // 2, z1, "x")
    elif r["wall"] == "z2":
        d = ((x1 + x2) // 2, z2, "x")
    elif r["wall"] == "x1":
        d = (x1, (z1 + z2) // 2, "z")
    else:
        d = (x2, (z1 + z2) // 2, "z")
    room_no += 1
    sign = SIGN_NAMES.get(r["kind"]) or str(room_no)
    if r["kind"] == "collapsed":
        sign = None
    r["door"] = d
    DOORS.append((d[0], d[1], d[2], w, sign))
# loket verpleegpost naar de receptie
DOORS.append((15, 10, "x", 6, None))

# binnenplaatsen: één kamer in de strook ernaast krijgt een achterdeur naar buiten
for yard in ("yardW", "yardE"):
    _, yx1, yz1, yx2, yz2, _ = next(a for a in FIXED if a[0] == yard)
    for r in rooms:
        x1, z1, x2, z2 = r["rect"]
        if r["wall"] == "z2" and z1 == yz2 and x1 >= yx1 + 6 and x2 <= yx2 - 6 and r["kind"] not in ("collapsed", "cell"):
            DOORS.append(((x1 + x2) // 2, z1, "x", 6, None))
            r["yard_door"] = True
            r["kind"] = "passage"
            break
    for r in rooms:
        x1, z1, x2, z2 = r["rect"]
        if r["wall"] == "z1" and z2 == yz1 and x1 >= yx1 + 6 and x2 <= yx2 - 6 and r["kind"] not in ("collapsed", "cell"):
            DOORS.append(((x1 + x2) // 2, z2, "x", 6, None))
            r["yard_door"] = True
            r["kind"] = "passage"
            break


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
    if (a is None or KIND.get(a) == "yard") and (b is None or KIND.get(b) == "yard"):
        return False
    return True


xs = [k[0] for k in grid]
zs = [k[1] for k in grid]
X0, X1, Z0, Z1 = min(xs) - 1, max(xs) + 2, min(zs) - 1, max(zs) + 2

segments = []  # (axis, line, start, end, sideA, sideB)
for x in range(X0, X1 + 1):
    run = None
    for z in range(Z0, Z1 + 1):
        a, b = label(x - 1, z), label(x, z)
        wall = needs_wall(a, b) and not in_door(x, z, "z")
        key = (a, b) if wall else None
        if run and (not wall or run[2] != key):
            segments.append(("z", x, run[0], run[1], run[2][0], run[2][1]))
            run = None
        if wall:
            run = [run[0], z + 1, key] if run else [z, z + 1, key]
    if run:
        segments.append(("z", x, run[0], run[1], run[2][0], run[2][1]))
for z in range(Z0, Z1 + 1):
    run = None
    for x in range(X0, X1 + 1):
        a, b = label(x, z - 1), label(x, z)
        wall = needs_wall(a, b) and not in_door(z, x, "x")
        key = (a, b) if wall else None
        if run and (not wall or run[2] != key):
            segments.append(("x", z, run[0], run[1], run[2][0], run[2][1]))
            run = None
        if wall:
            run = [run[0], x + 1, key] if run else [x, x + 1, key]
    if run:
        segments.append(("x", z, run[0], run[1], run[2][0], run[2][1]))

# ---------------------------------------------------------------- bouwen
root = Group("Hospital", "Model", top=True)
structure = root.sub("Structure")
walls = structure.sub("Walls")
floors = structure.sub("Floors")
ceilings = structure.sub("Ceilings")
lights_g = root.sub("Lights")
props = root.sub("Props")
decor = root.sub("Decor")
markers = root.sub("Markers")

WAINSCOT = {"corridor": TILE_GREEN, "hall": TILE_GREEN, "patient": TILE_WHITE, "nurse": TILE_WHITE, "bath": TILE_WHITE,
            "surgery": TILE_WHITE, "morgue": (130, 140, 140), "ward": TILE_WHITE, "lab": TILE_WHITE, "xray": TILE_WHITE,
            "cafeteria": TILE_GREEN, "dayroom": (120, 130, 150)}


def outside(lab):
    return lab is None or KIND.get(lab) == "yard"


def strip(axis, line, a, b, off, thick, y0, y1, name, color, material, shadow=True):
    """Plaat evenwijdig aan een muur: van a tot b langs de muur, op afstand `off` van de muurlijn."""
    length, mid, h = b - a, (a + b) / 2, y1 - y0
    if length <= 0.05:
        return
    if axis == "z":
        part(walls, name, [thick, h, length], [line + off, y0 + h / 2, mid], color, material, shadow=shadow)
    else:
        part(walls, name, [length, h, thick], [mid, y0 + h / 2, line + off], color, material, shadow=shadow)


def wall_piece(axis, line, a, b, y0, y1, material="Plaster", color=PLASTER, name="Wall"):
    strip(axis, line, a, b, 0, 1, y0, y1, name, color, material)


# Om flikkeren (z-fighting) te voorkomen mogen muren elkaar nooit met een vlak overlappen:
# een muureinde loopt alleen door (0.45) als er een dwarsmuur staat en de muur niet rechtdoor verder gaat.
SEG_BY_LINE = {}
for s in segments:
    SEG_BY_LINE.setdefault((s[0], s[1]), []).append(s)
OTHER = {"x": "z", "z": "x"}


def collinear(axis, line, p, me):
    return any(s is not me and (s[2] == p or s[3] == p) for s in SEG_BY_LINE.get((axis, line), []))


def perpendicular(axis, line, p, side=0):
    """Staat er een dwarsmuur op punt p? side=+1/-1: alleen als die dwarsmuur aan die kant van de muur loopt."""
    for s in SEG_BY_LINE.get((OTHER[axis], p), []):
        if s[2] <= line <= s[3]:
            if side == 0 or (side > 0 and s[3] > line) or (side < 0 and s[2] < line):
                return True
    return False


for seg in segments:
    axis, line, a, b, sa, sb = seg
    col = tint(PLASTER if R.random() < 0.6 else PLASTER_DIRTY)
    ext_a = 0.45 if perpendicular(axis, line, a) and not collinear(axis, line, a, seg) else 0
    ext_b = 0.45 if perpendicular(axis, line, b) and not collinear(axis, line, b, seg) else 0
    wall_piece(axis, line, a - ext_a, b + ext_b, 0, H, color=col)
    for side, lab in ((-1, sa), (1, sb)):
        if outside(lab):
            # bakstenen schil aan de buitenkant; op hoeken iets doorlopen zodat er geen kier is
            ba = a - (0.79 if ext_a else 0)
            bb = b + (0.79 if ext_b else 0)
            strip(axis, line, ba, bb, side * 0.65, 0.3, 0, H + (2 if axis == "x" else 1.97), "Brick", BRICK, "Brick")
            continue

        def trim(p, amount, sign):
            # inkorten tot de dwarsmuur aan deze kant (anders overlappen de tegels in de hoek)
            return p + sign * amount if perpendicular(axis, line, p, side) else p
        kind = KIND[lab]
        tile = WAINSCOT.get(kind)
        if kind == "cell":
            t = 1.1 if axis == "x" else 0.5
            strip(axis, line, trim(a, t, 1), trim(b, t, -1), side * 0.8, 0.6, 0, H - 1, "Padding", (200, 195, 180), "Fabric")
            continue
        if tile:
            t = 0.66 if axis == "x" else 0.5
            strip(axis, line, trim(a, t, 1), trim(b, t, -1), side * 0.58, 0.16, 0, 4.2, "Wainscot", tint(tile, 0.9, 1.05), "CeramicTiles", shadow=False)
        if lab in CORRIDORS and lab != "reception" and b - a > 2:
            ra = trim(a, 1.0, 1) if perpendicular(axis, line, a, side) else (a if collinear(axis, line, a, seg) else a + 0.3)
            rb = trim(b, 1.0, -1) if perpendicular(axis, line, b, side) else (b if collinear(axis, line, b, seg) else b - 0.3)
            strip(axis, line, ra, rb, side * 0.85, 0.3, 3.25, 3.55, "Handrail", METAL, "Metal", shadow=False)

# deurposten, bovenstuk, bordjes, deurbladen
for dx, dz, ax, w, sign in DOORS:
    if ax == "z":
        wall_piece("z", dx, dz - w / 2, dz + w / 2, DOOR_H, H, color=PLASTER_DIRTY, name="DoorHeader")
        for s in (-1, 1):
            part(walls, "DoorFrame", [1.3, DOOR_H, 0.35], [dx, DOOR_H / 2, dz + s * (w / 2 - 0.17)], FRAME, "Metal")
        part(walls, "DoorFrame", [1.34, 0.35, w], [dx, DOOR_H - 0.17, dz], FRAME, "Metal")
        cells = [(dx - 1, dz), (dx, dz)]
        U, N = (0, 1), (1, 0)
    else:
        wall_piece("x", dz, dx - w / 2, dx + w / 2, DOOR_H, H, color=PLASTER_DIRTY, name="DoorHeader")
        for s in (-1, 1):
            part(walls, "DoorFrame", [0.35, DOOR_H, 1.3], [dx + s * (w / 2 - 0.17), DOOR_H / 2, dz], FRAME, "Metal")
        part(walls, "DoorFrame", [w, 0.35, 1.34], [dx, DOOR_H - 0.17, dz], FRAME, "Metal")
        cells = [(dx, dz - 1), (dx, dz)]
        U, N = (1, 0), (0, 1)
    labs = [label(*c) for c in cells]
    # kamerkant = de kant die geen gang is (bij binnenplaatsdeur: de binnenkant)
    if labs[1] in CORRIDORS or outside(labs[1]):
        room_s = -1
    else:
        room_s = 1
    In = (N[0] * room_s, N[1] * room_s)
    if sign:
        p = [dx - In[0] * 0.7, DOOR_H + 1.6, dz - In[1] * 0.7]
        yaw = math.degrees(math.atan2(In[0], In[1]))
        part(decor, "RoomSign", [4, 1.2, 0.15], p, (35, 60, 55), "SmoothPlastic", m=rot(yaw=yaw),
             children=[text_gui(sign, "Front", (200, 205, 190), "SpecialElite", 1)])
    leaf_w = w / 2 if w >= 8 else w
    roll = R.random()
    if roll < 0.7:
        s = R.choice((-1, 1))
        ang = math.radians(R.uniform(60, 105))
        jx, jz = dx + U[0] * s * (w / 2 - 0.3) + In[0] * 0.4, dz + U[1] * s * (w / 2 - 0.3) + In[1] * 0.4
        d = (-s * U[0] * math.cos(ang) + In[0] * math.sin(ang), -s * U[1] * math.cos(ang) + In[1] * math.sin(ang))
        part(props, "DoorLeaf", [0.3, DOOR_H - 0.4, leaf_w - 0.2], [jx + d[0] * leaf_w / 2, (DOOR_H - 0.4) / 2, jz + d[1] * leaf_w / 2],
             (88, 108, 100), "Metal", m=rot(yaw=math.degrees(math.atan2(d[0], d[1]))))
    elif roll < 0.85:
        part(props, "DoorLeafFallen", [DOOR_H - 0.4, 0.3, leaf_w - 0.2],
             [dx + In[0] * (DOOR_H / 2 + 1) + R.uniform(-1, 1) * U[0], 0.3, dz + In[1] * (DOOR_H / 2 + 1) + R.uniform(-1, 1) * U[1]],
             (88, 108, 100), "Metal", m=rot(yaw=R.uniform(0, 360), roll=R.uniform(-4, 4)))

# vloeren, plafonds, dak (per gebied)
FLOOR_COLOR = {"corridor": FLOOR_CORRIDOR, "hall": (105, 102, 95), "patient": FLOOR_ROOM, "nurse": FLOOR_ROOM, "bath": TILE_WHITE,
               "surgery": (150, 160, 158), "morgue": FLOOR_DARK, "ward": FLOOR_ROOM, "records": (95, 88, 80), "storage": (90, 88, 82),
               "office": (95, 80, 65), "lab": (140, 145, 140), "cell": (170, 165, 150), "xray": (120, 125, 125), "dayroom": (100, 85, 70),
               "boiler": (70, 66, 60), "collapsed": (100, 98, 92), "chapel": (85, 65, 50), "cafeteria": (120, 115, 100), "yard": (45, 50, 35)}
FLOOR_MAT = {"records": "Concrete", "storage": "Concrete", "office": "WoodPlanks", "hall": "Marble", "boiler": "Concrete",
             "collapsed": "Concrete", "chapel": "WoodPlanks", "dayroom": "WoodPlanks", "cell": "Fabric", "yard": "Ground"}
holes = []
for name, x1, z1, x2, z2, kind in AREAS:
    # stukken waar een gang overheen ligt overslaan (gangen hebben voorrang)
    rects = [(x1, z1, x2, z2)]
    if name in ("crossA", "crossB", "crossC"):
        rects = [(x1, z1, -5, z2), (5, z1, x2, z2)]
        if name in ("crossA", "crossB"):
            rects = [(-120, z1, -5, z2), (5, z1, 120, z2)]
    if name in ("sideW", "sideE"):
        pass
    for rx1, rz1, rx2, rz2 in rects:
        w, d = rx2 - rx1, rz2 - rz1
        cx, cz = (rx1 + rx2) / 2, (rz1 + rz2) / 2
        part(floors, "Floor", [w, 1, d], [cx, -0.5, cz], tint(FLOOR_COLOR[kind], 0.9, 1.05), FLOOR_MAT.get(kind, "CeramicTiles"))
        if kind == "yard":
            continue
        nx, nz = max(1, round(w / 10)), max(1, round(d / 10))
        tw, td = w / nx, d / nz
        for i in range(nx):
            for j in range(nz):
                tx, tz = rx1 + tw * (i + 0.5), rz1 + td * (j + 0.5)
                if R.random() < (0.35 if kind == "collapsed" else 0.1) and name != "reception":
                    holes.append((tx, tz, tw, td))
                    continue
                part(ceilings, "CeilingTile", [tw, 0.6, td], [tx, H + 0.3, tz], tint((140, 140, 132), 0.8, 1.0), "Plaster")
        part(ceilings, "Plenum", [w, 1, d], [cx, H + 6.5, cz], (40, 40, 40), "Concrete")
part(floors, "Ground", [700, 2, 600], [0, -2, -70], (40, 38, 34), "Ground")

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


PLACED_LIGHTS = []


def fluorescent(x, z, along_x=True, state=None):
    if any(abs(x - px) < 4 and abs(z - pz) < 4 for px, pz in PLACED_LIGHTS):
        return
    PLACED_LIGHTS.append((x, z))
    state = state or R.choices(["on", "flicker", "dead"], weights=[3, 4, 3.5])[0]
    size = [5, 0.35, 1.4] if along_x else [1.4, 0.35, 5]
    part(lights_g, "LightHousing", [size[0] + 0.4, 0.3, size[2] + 0.4], [x, H - 0.15, z], (110, 112, 105), "Metal")
    if state == "dead":
        if R.random() < 0.35:
            part(lights_g, "LightFallen", size, [x, H - 2.2, z], (60, 62, 58), "Glass",
                 m=rot(roll=R.choice((-35, 35)) if along_x else 0, pitch=0 if along_x else R.choice((-35, 35))), collide=False)
        else:
            part(lights_g, "LightDead", size, [x, H - 0.45, z], (60, 62, 58), "Glass", collide=False)
        return
    kids = [light("SurfaceLight", (205, 240, 220), 1.4 if state == "on" else 1.8, 20, {"Face": "Bottom", "Angle": 120}, shadows=R.random() < 0.4)]
    if state == "flicker":
        kids.append(light("PointLight", (200, 235, 215), 0.3, 8, shadows=False))
    part(lights_g, "Fluorescent", size, [x, H - 0.45, z], (215, 235, 225), "Neon", transparency=0.1, collide=False, shadow=False,
         tags=FLICKER if state == "flicker" else None, children=kids)


def emergency(x, y, z):
    part(lights_g, "EmergencyLight", [1.2, 0.5, 0.5], [x, y, z], (200, 20, 20), "Neon", collide=False, shadow=False,
         tags=FLICKER if R.random() < 0.4 else None, children=[light("PointLight", (255, 30, 20), 0.9, 14, shadows=False)])


for name, x1, z1, x2, z2, kind in FIXED:
    if kind != "corridor":
        continue
    if x2 - x1 > z2 - z1:
        for x in range(x1 + 6, x2 - 3, 12):
            if not -6 < x < 6:
                fluorescent(x, (z1 + z2) / 2, True)
    else:
        for z in range(z1 + 6, z2 - 3, 12):
            fluorescent((x1 + x2) / 2, z, False)
for x, z in ((-12, 18), (12, 18), (-12, 32), (12, 32), (0, 25)):
    fluorescent(x, z, True, R.choice(["dead", "flicker", "dead"]))
for r in rooms:
    x1, z1, x2, z2 = r["rect"]
    w, d = x2 - x1, z2 - z1
    n = max(1, round(w * d / 260))
    for i in range(n):
        if w >= d:
            fluorescent(x1 + w * (i + 0.5) / n, (z1 + z2) / 2, True)
        else:
            fluorescent((x1 + x2) / 2, z1 + d * (i + 0.5) / n, False)
for dx, dz, ax, w, sign in DOORS:
    if sign and R.random() < 0.3:
        if ax == "z":
            s = -1 if label(dx - 1, dz) in CORRIDORS else 1
            emergency(dx + s * 0.8, H - 1.2, dz + w / 2 + 1)
        else:
            s = -1 if label(dx, dz - 1) in CORRIDORS else 1
            emergency(dx + w / 2 + 1, H - 1.2, dz + s * 0.8)

# ---------------------------------------------------------------- ramen (dichtgetimmerd, maanlicht)
NO_WINDOWS = {"morgue", "cell", "boiler", "surgery"}
for axis, line, a, b, sa, sb in segments:
    if outside(sa) == outside(sb):
        continue
    inside = sb if outside(sa) else sa
    if KIND.get(inside) in NO_WINDOWS:
        continue
    if inside == "reception" and axis == "x" and line == 40:
        continue
    s_in = 1 if outside(sa) else -1
    length = b - a
    if length < 8:
        continue
    n = int((length - 4) // 14)
    for i in range(n):
        t = a + 4 + (length - 8) * (i + 0.5) / max(n, 1)
        if axis == "z":
            pos = [line + s_in * 0.62, 7.5, t]
            m = rot(yaw=90)
        else:
            pos = [t, 7.5, line + s_in * 0.62]
            m = rot(yaw=0)
        part(decor, "WindowGlass", [5, 5, 0.1], pos, (25, 30, 38), "Glass", m=m, transparency=0.2, collide=False)
        part(decor, "WindowFrame", [5.6, 0.4, 0.3], local(pos, m, [0, 2.7, 0]), (60, 60, 55), "Metal", m=m)
        part(decor, "WindowFrame", [5.6, 0.4, 0.3], local(pos, m, [0, -2.7, 0]), (60, 60, 55), "Metal", m=m)
        for _ in range(R.randint(2, 4)):
            part(decor, "Board", [6.2, 0.7, 0.25], local(pos, m, [0, R.uniform(-2, 2), 0.25 * s_in]),
                 (85, 66, 50), "WoodPlanks", m=matmul(m, rot(roll=R.uniform(-18, 18))))
        if R.random() < 0.35:
            lp = [pos[0] + (s_in * 0.6 if axis == "z" else 0), 8.5, pos[2] + (s_in * 0.6 if axis == "x" else 0)]
            face = ("Right" if s_in > 0 else "Left") if axis == "z" else ("Back" if s_in > 0 else "Front")
            part(lights_g, "MoonLight", [1, 1, 1], lp, (0, 0, 0), transparency=1, collide=False, shadow=False,
                 children=[light("SpotLight", (120, 140, 200), 1.6, 26, {"Face": face, "Angle": 50}, shadows=False)])


# ---------------------------------------------------------------- props (bouwstenen)
def bed(g, x, z, yaw, wrecked=False, body=False):
    m = rot(yaw=yaw, roll=R.uniform(-6, 6) if wrecked else 0)
    base = [x, 0, z]

    def p(name, size, off, col, mat="Metal", **kw):
        return part(g, name, size, local(base, m, off), col, mat, m=m, **kw)
    p("BedFrame", [3.4, 0.35, 7.2], [0, 2.1, 0], METAL)
    p("Mattress", [3.1, 0.6, 6.6], [0, 2.6, 0], FABRIC_DIRTY if R.random() < 0.6 else FABRIC, "Fabric")
    p("Headboard", [3.46, 2.6, 0.25], [0, 3.1, -3.5], METAL)
    p("Footboard", [3.46, 1.6, 0.25], [0, 2.6, 3.5], METAL)
    for sx in (-1.5, 1.5):
        for sz in (-3.3, 3.3):
            p("BedLeg", [0.2, 2, 0.2], [sx, 1, sz], METAL_DARK)
    p("Rail", [0.12, 0.12, 3.5], [1.65, 3.3, -1], METAL)
    if R.random() < 0.6:
        p("Pillow", [2.2, 0.5, 1.2], [0, 3.1, -2.6], FABRIC, "Fabric")
    if body or R.random() < 0.2:
        p("SheetBody", [1.6, 0.8, 5.2], [0, 3.2, 0.4], SHEET, "Fabric")
        p("SheetHead", [1.1, 0.8, 1.1], [0, 3.27, -2.3], SHEET, "Fabric")
    if R.random() < 0.3:
        p("BloodStain", [1.6, 0.05, 1.8], [R.uniform(-0.6, 0.6), 2.92, R.uniform(-1, 1)], BLOOD, "SmoothPlastic", collide=False, shadow=False)
    if R.random() < 0.15:
        p("Restraint", [3.6, 0.2, 0.3], [0, 2.95, 1], (90, 70, 50), "Leather", collide=False)
        p("Restraint", [3.6, 0.2, 0.3], [0, 2.95, -1.2], (90, 70, 50), "Leather", collide=False)


def iv_stand(g, x, z):
    part(g, "IVBase", [1.6, 0.2, 1.6], [x, 0.15, z], METAL_DARK, "Metal")
    part(g, "IVPole", [0.15, 6.5, 0.15], [x, 3.4, z], METAL, "Metal", m=rot(roll=R.uniform(-4, 4)))
    part(g, "IVHook", [1.4, 0.12, 0.12], [x, 6.6, z], METAL, "Metal")
    part(g, "IVBag", [0.6, 1, 0.25], [x + 0.6, 5.9, z], (200, 190, 120), "Glass", transparency=0.3, collide=False)


def curtain_line(g, p1, p2, color=CURTAIN):
    dx, dz = p2[0] - p1[0], p2[1] - p1[1]
    L = math.hypot(dx, dz)
    yaw = math.degrees(math.atan2(dx, dz))
    m = rot(yaw=yaw)
    mid = [(p1[0] + p2[0]) / 2, H - 0.8, (p1[1] + p2[1]) / 2]
    part(g, "CurtainRail", [0.15, 0.15, L], mid, METAL, "Metal", m=m, collide=False)
    n = R.randint(2, 4)
    for i in range(n):
        t = (i + 0.5) / n
        w = L / n * R.uniform(0.6, 0.95)
        c = [p1[0] + dx * t, H - 5.2, p1[1] + dz * t]
        part(g, "Curtain", [0.1, 8.5, w], c, tint(color, 0.8, 1.0), "Fabric", m=matmul(m, rot(yaw=R.uniform(-8, 8))), collide=False)


def wheelchair(g, x, z, yaw, tipped=False):
    m = rot(yaw=yaw, roll=80 if tipped else 0)
    base = [x, 1.4 if tipped else 0, z]
    part(g, "WCSeat", [2, 0.25, 2], local(base, m, [0, 1.8, 0]), (40, 40, 45), "Fabric", m=m)
    part(g, "WCBack", [2, 2, 0.2], local(base, m, [0, 2.9, 1]), (40, 40, 45), "Fabric", m=m)
    for s in (-1.15, 1.15):
        part(g, "WCWheel", [0.15, 2.8, 2.8], local(base, m, [s, 1.4, 0.3]), METAL_DARK, "Metal", m=m, shape="Cylinder")
        part(g, "WCFront", [0.15, 0.7, 0.7], local(base, m, [s * 0.85, 0.35, -1]), METAL_DARK, "Metal", m=m, shape="Cylinder")


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
        part(g, "Paper", [0.85, 0.02, 1.1], [x + R.uniform(-spread, spread), R.uniform(0.02, 0.09), z + R.uniform(-spread, spread)],
             (200, 195, 175), "SmoothPlastic", m=rot(yaw=R.uniform(0, 360)), collide=False, shadow=False)


def blood(g, x, z, w, d):
    part(g, "Blood", [w, 0.03, d], [x, R.uniform(0.016, 0.06), z], BLOOD, "SmoothPlastic", m=rot(yaw=R.uniform(0, 360)), collide=False, shadow=False)


def chair(g, x, z, yaw, fallen=False, col=(60, 90, 110)):
    m = rot(yaw=yaw, roll=90 if fallen else 0)
    base = [x, 1.0 if fallen else 0, z]
    part(g, "ChairSeat", [1.8, 0.25, 1.8], local(base, m, [0, 1.8, 0]), col, "Plastic", m=m)
    part(g, "ChairBack", [1.76, 1.8, 0.2], local(base, m, [0, 2.8, 0.83]), col, "Plastic", m=m)
    for sx in (-0.8, 0.8):
        part(g, "ChairLeg", [0.12, 1.8, 0.12], local(base, m, [sx, 0.9, 0]), METAL_DARK, "Metal", m=m)


def table(g, x, z, yaw, w=6, d=3, col=(110, 100, 85), mat="Wood"):
    m = rot(yaw=yaw)
    base = [x, 0, z]
    part(g, "Table", [w, 0.3, d], local(base, m, [0, 3, 0]), col, mat, m=m)
    for sx in (-w / 2 + 0.3, w / 2 - 0.3):
        for sz in (-d / 2 + 0.3, d / 2 - 0.3):
            part(g, "TableLeg", [0.25, 3, 0.25], local(base, m, [sx, 1.5, sz]), METAL_DARK, "Metal", m=m)


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
    if body:
        part(g, "SheetBody", [1.6, 0.9, 4.8], local(base, m, [0, 3.4, 0.4]), SHEET, "Fabric", m=m)
        part(g, "SheetHead", [1.1, 0.9, 1.1], local(base, m, [0, 3.45, -2.4]), SHEET, "Fabric", m=m)


def tree(g, x, z, h):
    part(g, "Trunk", [1.4, h, 1.4], [x, h / 2 - 0.3, z], (40, 32, 26), "Wood", m=rot(roll=R.uniform(-6, 6), pitch=R.uniform(-6, 6)))
    for _ in range(R.randint(4, 7)):
        L = R.uniform(3, 7)
        y = R.uniform(h * 0.45, h * 0.95)
        a = R.uniform(0, 360)
        tilt = R.uniform(35, 70)
        m = rot(yaw=a, roll=tilt)
        part(g, "Branch", [0.45, L, 0.45], local([x, y, z], m, [0, L / 2, 0]), (40, 32, 26), "Wood", m=m, collide=False)


# ---------------------------------------------------------------- kamers inrichten
class Room:
    """Lokaal assenstelsel: u langs de deurmuur (0..W), v de kamer in (0..D). Deur op u = W/2."""

    def __init__(self, r):
        x1, z1, x2, z2 = r["rect"]
        wall = r["wall"]
        if wall == "z1":
            self.o, self.U, self.In, self.W, self.D = (x1, z1), (1, 0), (0, 1), x2 - x1, z2 - z1
        elif wall == "z2":
            self.o, self.U, self.In, self.W, self.D = (x1, z2), (1, 0), (0, -1), x2 - x1, z2 - z1
        elif wall == "x1":
            self.o, self.U, self.In, self.W, self.D = (x1, z1), (0, 1), (1, 0), z2 - z1, x2 - x1
        else:
            self.o, self.U, self.In, self.W, self.D = (x2, z1), (0, 1), (-1, 0), z2 - z1, x2 - x1
        self.r = r
        self.g = props.sub(r["kind"] + "_" + r["name"])
        # yaw waarbij lokaal -Z naar de achtermuur wijst
        self.back = math.degrees(math.atan2(-self.In[0], -self.In[1]))
        self.face_door = self.back + 180
        self.left = math.degrees(math.atan2(self.U[0], self.U[1]))  # -Z naar u = 0
        self.right = self.left + 180  # -Z naar u = W

    def p(self, u, v):
        return (self.o[0] + self.U[0] * u + self.In[0] * v, self.o[1] + self.U[1] * u + self.In[1] * v)

    def wall_text(self, text, v_back=True):
        u = R.uniform(self.W * 0.25, self.W * 0.75)
        x, z = self.p(u, self.D - 0.6)
        part(decor, "WallWriting", [min(12, self.W - 3), 2.8, 0.05], [x, R.uniform(6, 9), z], (0, 0, 0), transparency=1,
             m=rot(yaw=self.back), collide=False, shadow=False, children=[text_gui(text, "Back", (110, 8, 8), "Creepster", 1)])


def fill_patient(rm):
    n = 1 if rm.W < 16 else 2
    for i in range(n):
        u = rm.W * (i + 0.5) / n
        x, z = rm.p(u, rm.D - 4.3)
        bed(rm.g, x, z, rm.back, wrecked=R.random() < 0.5)
        ix, iz = rm.p(u + 2.6, rm.D - 2)
        iv_stand(rm.g, ix, iz)
    if n == 2:
        curtain_line(rm.g, rm.p(rm.W / 2, rm.D - 9), rm.p(rm.W / 2, rm.D - 0.5))
    x, z = rm.p(1.4, 3)
    cabinet(rm.g, x, z, rm.left + 180, 2.5, 4, 1.4, (150, 150, 140), open_door=R.random() < 0.5)
    if R.random() < 0.4:
        x, z = rm.p(R.uniform(3, rm.W - 3), R.uniform(5, rm.D - 9))
        wheelchair(rm.g, x, z, R.uniform(0, 360), tipped=R.random() < 0.4)


def fill_ward(rm):
    for v in range(6, int(rm.D) - 3, 8):
        for side in (0, 1):
            u = 4.2 if side == 0 else rm.W - 4.2
            x, z = rm.p(u, v)
            bed(rm.g, x, z, rm.left if side == 0 else rm.right, wrecked=R.random() < 0.4, body=R.random() < 0.25)
            curtain_line(rm.g, rm.p(0.5 if side == 0 else rm.W - 0.5, v + 4), rm.p(8 if side == 0 else rm.W - 8, v + 4))
    if R.random() < 0.6:
        x, z = rm.p(rm.W / 2, rm.D / 2)
        wheelchair(rm.g, x, z, R.uniform(0, 360))


def fill_office(rm):
    x, z = rm.p(rm.W / 2, rm.D * 0.6)
    table(rm.g, x, z, rm.back, 6, 3, (80, 60, 45))
    cx, cz = rm.p(rm.W / 2, rm.D * 0.6 + 2.5)
    chair(rm.g, cx, cz, rm.back + 180, fallen=R.random() < 0.5, col=(50, 40, 35))
    for k in range(int(rm.W // 4)):
        x, z = rm.p(2 + k * 3.4, rm.D - 1.35)
        if 2 + k * 3.4 < rm.W - 1.5:
            cabinet(rm.g, x, z, rm.face_door, 3, R.choice((6, 7)), 1.6, open_door=R.random() < 0.3)
    x, z = rm.p(rm.W / 2 + 2, rm.D * 0.6)
    part(rm.g, "DeskLamp", [0.6, 1.4, 0.6], [x, 3.9, z], (40, 40, 40), "Metal", tags=FLICKER if R.random() < 0.6 else None,
         children=[light("PointLight", (255, 200, 120), 0.7, 12, shadows=False)] if R.random() < 0.6 else None)


def fill_nurse(rm):
    x, z = rm.p(rm.W / 2, rm.D * 0.5)
    m = rot(yaw=rm.back)
    part(rm.g, "Counter", [rm.W * 0.7, 3.6, 2], [x, 1.8, z], (120, 125, 118), "Plastic", m=m)
    part(rm.g, "CounterTop", [rm.W * 0.7 + 0.6, 0.3, 2.6], [x, 3.75, z], (90, 95, 90), "Plastic", m=m)
    for k in range(3):
        cx, cz = rm.p(2 + k * 3.2, rm.D - 1.35)
        cabinet(rm.g, cx, cz, rm.face_door, 2.8, 6, 1.6, open_door=k == 1)
    cx, cz = rm.p(rm.W / 2, rm.D * 0.5 + 2.5)
    chair(rm.g, cx, cz, rm.back, fallen=True)


def fill_bath(rm):
    n = max(2, int((rm.W - 2) // 4.2))
    for i in range(n):
        u = 1.5 + 4.2 * (i + 0.5)
        if u > rm.W - 1:
            break
        x, z = rm.p(u - 2.1, rm.D - 3.3)
        part(rm.g, "StallWall", [0.2, 7, 5.5], [x, 3.6, z], (110, 120, 115), "Plastic", m=rot(yaw=rm.back))
        x, z = rm.p(u, rm.D - 1.7)
        part(rm.g, "Toilet", [1.6, 1.6, 2.2], [x, 0.8, z], (190, 190, 185), "Marble", m=rot(yaw=rm.back))
        if R.random() < 0.7:
            x, z = rm.p(u, rm.D - 6.1)
            part(rm.g, "StallDoor", [3.6, 6, 0.15], [x, 3.4, z], (110, 120, 115), "Plastic", m=rot(yaw=rm.back + R.uniform(-70, 0)))
    for k in range(int((rm.D - 8) // 5)):
        v = 3 + k * 5
        x, z = rm.p(1.75, v)
        part(rm.g, "Sink", [1.6, 0.6, 2.2], [x, 3.2, z], (190, 190, 185), "Marble", m=rot(yaw=rm.left))
        mx, mz = rm.p(0.56, v)
        # Front-kant van de spiegel kijkt de kamer in (tag Mirror: Stijns spiegel-script)
        part(rm.g, "Mirror", [2.6, 3, 0.1], [mx, 6.3, mz], (30, 35, 40) if R.random() < 0.6 else (160, 170, 175), "Glass",
             m=rot(yaw=rm.left + 180), transparency=0.1, collide=False, tags=["Mirror"])


def fill_storage(rm):
    for k in range(int((rm.W - 2) // 3.2)):
        x, z = rm.p(1.8 + k * 3.2, rm.D - 2.1)
        part(rm.g, "Crate", [3, 3, 3], [x, 1.5, z], (110, 85, 60), "WoodPlanks", m=rot(yaw=R.uniform(-8, 8)))
        if R.random() < 0.5:
            part(rm.g, "Crate", [3, 3, 3], [x, 4.5, z], (110, 85, 60), "WoodPlanks", m=rot(yaw=R.uniform(-8, 8)))
    for v in range(3, int(rm.D) - 4, 3):
        x, z = rm.p(1.5, v)
        part(rm.g, "Shelf", [1.6, 8, 2.8], [x, 4, z], (90, 92, 88), "Metal", m=rot(yaw=rm.left))
        for lvl in range(3):
            if R.random() < 0.7:
                part(rm.g, "Box", [1.2, 1.2, 1.4], [x, 1.2 + lvl * 2.4, z], (150, 120, 85), "Cardboard", m=rot(yaw=R.uniform(-15, 15)))
    if R.random() < 0.5:
        x, z = rm.p(rm.W / 2 + 2, rm.D / 2)
        gurney(rm.g, x, z, R.uniform(0, 360), body=False)


def fill_records(rm):
    for k in range(int((rm.W - 3) // 5.5)):
        u = 3 + k * 5.5
        x, z = rm.p(u, rm.D * 0.55)
        part(rm.g, "Shelf", [1.6, 9, rm.D - 9], [x, 4.5, z], (90, 92, 88), "Metal", m=rot(yaw=rm.back))
        for lvl in range(4):
            for b in range(int((rm.D - 9) // 2)):
                if R.random() < 0.7:
                    bx, bz = rm.p(u, 5 + b * 2)
                    part(rm.g, "Box", [1.4, 1.4, 1.6], [bx, 1 + lvl * 2.2 + 0.75, bz], (150, 120, 85), "Cardboard", m=rot(yaw=R.uniform(-10, 10)))
    x, z = rm.p(rm.W / 2, rm.D / 2)
    papers(rm.g, x, z, 18, min(rm.W, rm.D) / 2.5)


def fill_lab(rm):
    for side in (0, 1):
        u = 1.9 if side == 0 else rm.W - 1.9
        x, z = rm.p(u, rm.D * 0.55)
        part(rm.g, "LabBench", [2.6, 3.4, rm.D - 8], [x, 1.7, z], (60, 62, 60), "Slate", m=rot(yaw=rm.back))
        for k in range(int((rm.D - 9) // 1.6)):
            if R.random() < 0.6:
                jx, jz = rm.p(u + R.uniform(-0.6, 0.6), 5 + k * 1.6)
                liquid = R.choice([(80, 200, 90), (200, 180, 60), (150, 30, 30), (90, 140, 200)])
                part(rm.g, "Jar", [0.5, 1, 0.5], [jx, 3.9, jz], (200, 210, 200), "Glass", transparency=0.5, collide=False)
                part(rm.g, "JarLiquid", [0.4, 0.6, 0.4], [jx, 3.75, jz], liquid, "Neon" if R.random() < 0.2 else "Glass", transparency=0.2, collide=False, shadow=False)
    x, z = rm.p(rm.W / 2, rm.D - 2.2)
    part(rm.g, "SpecimenTank", [4, 6, 2.6], [x, 3.5, z], (100, 200, 120), "Glass", transparency=0.55, m=rot(yaw=rm.back),
         tags=FLICKER, children=[light("PointLight", (90, 255, 120), 0.9, 14, shadows=False)])
    part(rm.g, "TankThing", [1.4, 3.6, 1], [x, 3.8, z], (30, 40, 30), "SmoothPlastic", m=rot(yaw=rm.back + 20, roll=8), collide=False)
    part(rm.g, "TankBase", [4.4, 0.6, 3], [x, 0.3, z], METAL_DARK, "Metal", m=rot(yaw=rm.back))


def fill_cell(rm):
    x, z = rm.p(rm.W / 2, rm.D - 4)
    bed(rm.g, x, z, rm.back, body=False)
    cx, cz = rm.p(rm.W / 2, rm.D * 0.4)
    chair(rm.g, cx, cz, rm.back, col=(90, 70, 50))
    part(rm.g, "Straps", [1.9, 0.15, 1.9], [cx, 2.0, cz], (90, 70, 50), "Leather", collide=False)
    if R.random() < 0.7:
        rm.wall_text(R.choice(["LET ME OUT", "I CAN HEAR IT", "IT KNOWS MY NAME", "NOT CRAZY"]))


def fill_xray(rm):
    x, z = rm.p(rm.W / 2, rm.D * 0.55)
    m = rot(yaw=rm.back)
    part(rm.g, "XrayTable", [3, 0.4, 7], [x, 3, z], (180, 185, 185), "SmoothPlastic", m=m)
    part(rm.g, "XrayBase", [2, 2.8, 4], [x, 1.4, z], METAL_DARK, "Metal", m=m)
    ax_, az_ = rm.p(rm.W / 2 + 3, rm.D * 0.55)
    part(rm.g, "XrayColumn", [1, 10, 1], [ax_, 5, az_], (190, 190, 190), "Metal")
    part(rm.g, "XrayHead", [2, 1.6, 2.4], [x, 8.5, z], (200, 200, 195), "SmoothPlastic", m=m)
    px, pz = rm.p(1.2, rm.D - 3)
    part(rm.g, "Lightbox", [0.3, 3, 5], [px, 6, pz], (200, 220, 230), "Neon", m=rot(yaw=rm.left + 90), tags=FLICKER,
         children=[light("PointLight", (200, 225, 255), 0.6, 10, shadows=False)], collide=False)


def fill_dayroom(rm):
    for k in range(2):
        x, z = rm.p(rm.W * (0.3 + 0.4 * k), rm.D * 0.55)
        table(rm.g, x, z, rm.back, 5, 3)
        for s in (-1, 1):
            cx, cz = rm.p(rm.W * (0.3 + 0.4 * k) + s * 1.5, rm.D * 0.55 + 2.4)
            chair(rm.g, cx, cz, rm.back + 180, fallen=R.random() < 0.3)
    x, z = rm.p(rm.W / 2, rm.D - 1.5)
    part(rm.g, "TVStand", [4, 3, 1.8], [x, 1.5, z], WOOD, "WoodPlanks", m=rot(yaw=rm.back))
    part(rm.g, "TV", [3, 2.4, 1.6], [x, 4.2, z], (30, 30, 30), "SmoothPlastic", m=rot(yaw=rm.back))
    sx, sz = rm.p(rm.W / 2, rm.D - 2.37)
    part(rm.g, "TVStatic", [2.4, 1.8, 0.05], [sx, 4.2, sz], (180, 185, 190), "Neon", m=rot(yaw=rm.back), tags=FLICKER, collide=False,
         children=[light("PointLight", (180, 200, 255), 0.6, 12, shadows=False)])
    rx, rz = rm.p(2.5, 3)
    part(rm.g, "RockingChair", [2, 3, 2.2], [rx, 1.5, rz], WOOD, "Wood", m=rot(yaw=rm.face_door + 30, pitch=-6))


def fill_boiler(rm):
    for k in range(2):
        x, z = rm.p(rm.W * (0.3 + 0.4 * k), rm.D - 4)
        part(rm.g, "Boiler", [7, 5, 5], [x, 4, z], RUST, "CorrodedMetal", m=rot(yaw=rm.back, roll=90), shape="Cylinder")
        part(rm.g, "BoilerPipe", [0.8, H - 7, 0.8], [x, 7 + (H - 7) / 2, z], RUST, "CorrodedMetal")
        vx, vz = rm.p(rm.W * (0.3 + 0.4 * k), rm.D - 6.6)
        part(rm.g, "Valve", [0.2, 1.4, 1.4], [vx, 4, vz], (150, 20, 20), "Metal", m=rot(yaw=rm.back + 90), shape="Cylinder")
    x, z = rm.p(rm.W / 2, rm.D / 2)
    part(rm.g, "BoilerGlow", [1, 1, 1], [x, 3, z], (0, 0, 0), transparency=1, collide=False, tags=FLICKER,
         children=[light("PointLight", (255, 80, 30), 1.4, 20)])
    for k in range(3):
        px, pz = rm.p(R.uniform(2, rm.W - 2), rm.D / 2)
        part(rm.g, "Pipe", [rm.D, 0.6, 0.6], [px, H - 1.5 - k * 0.8, pz], RUST, "CorrodedMetal", m=rot(yaw=rm.back + 90), shape="Cylinder", collide=False)


def fill_collapsed(rm):
    x, z = rm.p(rm.W / 2, rm.D / 2)
    debris(rm.g, x, z, 25, min(rm.W, rm.D) / 2.5)
    for _ in range(3):
        part(rm.g, "Slab", [R.uniform(4, 7), 0.8, R.uniform(3, 5)], [x + R.uniform(-3, 3), R.uniform(0.6, 2.5), z + R.uniform(-3, 3)], (110, 108, 100), "Concrete",
             m=rot(yaw=R.uniform(0, 360), roll=R.uniform(-25, 25), pitch=R.uniform(-15, 15)))


def fill_chapel(rm):
    for row in range(int((rm.D - 10) // 3.5)):
        for side in (-1, 1):
            x, z = rm.p(rm.W / 2 + side * 5, 4 + row * 3.5)
            if R.random() < 0.85:
                m = rot(yaw=rm.back + R.uniform(-6, 6))
                part(rm.g, "Pew", [7, 0.4, 1.6], [x, 1.8, z], WOOD, "Wood", m=m)
                part(rm.g, "PewBack", [7, 2, 0.3], local([x, 0, z], m, [0, 2.8, 0.7]), WOOD, "Wood", m=m)
            else:
                part(rm.g, "PewFallen", [7, 0.4, 1.6], [x, 0.3, z], WOOD, "Wood", m=rot(yaw=rm.back + R.uniform(-30, 30), roll=80))
    x, z = rm.p(rm.W / 2, rm.D - 3)
    part(rm.g, "Altar", [6, 3.5, 2.5], [x, 1.75, z], (90, 70, 55), "Wood", m=rot(yaw=rm.back))
    cx, cz = rm.p(rm.W / 2, rm.D - 0.8)
    part(rm.g, "Cross", [0.6, 7, 0.4], [cx, 8.5, cz], (60, 45, 35), "Wood", m=rot(yaw=rm.back, roll=180 if R.random() < 0.5 else 0))
    part(rm.g, "CrossBar", [3.6, 0.6, 0.4], [cx, 10 if R.random() < 0.5 else 7, cz], (60, 45, 35), "Wood", m=rot(yaw=rm.back))
    for k in range(6):
        kx, kz = rm.p(rm.W / 2 - 2.5 + k, rm.D - 3)
        part(rm.g, "Candle", [0.3, R.uniform(0.6, 1.2), 0.3], [kx, 3.9, kz], (220, 210, 185), "SmoothPlastic", collide=False)
        if k % 2 == 0:
            part(rm.g, "Flame", [0.15, 0.3, 0.15], [kx, 4.7, kz], (255, 170, 80), "Neon", collide=False, shadow=False, tags=FLICKER,
                 children=[light("PointLight", (255, 140, 60), 0.8, 12, shadows=False)])
    rm.wall_text(R.choice(["GOD ISN'T HERE", "PRAY", "HE DOESN'T LISTEN"]))


def fill_cafeteria(rm):
    for row in range(int((rm.D - 8) // 6)):
        for col in range(int((rm.W - 4) // 10)):
            x, z = rm.p(5 + col * 10 + 2, 5 + row * 6)
            if R.random() < 0.85:
                table(rm.g, x, z, rm.back, 7, 2.6, (150, 150, 140), "Plastic")
                for s in (-1, 1):
                    bx, bz = rm.p(5 + col * 10 + 2, 5 + row * 6 + s * 2)
                    part(rm.g, "Bench", [7, 0.3, 1], [bx, 1.8, bz], (120, 60, 50), "Plastic", m=rot(yaw=rm.back),
                         )
            else:
                part(rm.g, "TableFallen", [7, 0.3, 2.6], [x, 1.3, z], (150, 150, 140), "Plastic", m=rot(yaw=rm.back + R.uniform(60, 120), roll=75))
    x, z = rm.p(rm.W / 2, rm.D - 2)
    part(rm.g, "ServingCounter", [rm.W * 0.6, 3.6, 2.2], [x, 1.8, z], METAL, "Metal", m=rot(yaw=rm.back))
    for _ in range(10):
        tx, tz = rm.p(R.uniform(3, rm.W - 3), R.uniform(3, rm.D - 5))
        part(rm.g, "Tray", [1.6, 0.1, 1.1], [tx, 0.05, tz], (150, 120, 90), "Plastic", m=rot(yaw=R.uniform(0, 360)), collide=False)


def fill_surgery(rm):
    x, z = rm.p(rm.W / 2, rm.D * 0.55)
    m = rot(yaw=rm.back)
    part(rm.g, "OpTable", [3.2, 0.5, 7.5], [x, 3.2, z], (170, 175, 175), "Metal", m=m)
    part(rm.g, "OpTableBase", [1.5, 3, 2.5], [x, 1.5, z], METAL_DARK, "Metal", m=m)
    part(rm.g, "OpBody", [1.7, 0.9, 5.2], [x, 3.9, z], SHEET, "Fabric", m=m)
    part(rm.g, "BloodPool", [2.6, 0.05, 3], [x, 3.47, z], BLOOD, "SmoothPlastic", m=m, collide=False, shadow=False)
    part(rm.g, "SurgeryLampArm", [0.4, 4, 0.4], [x, H - 2, z], METAL, "Metal")
    part(rm.g, "SurgeryLamp", [1, 4.5, 4.5], [x, H - 4.2, z], (220, 225, 220), "Metal", m=rot(roll=90 + 12), shape="Cylinder",
         tags=FLICKER, children=[light("SpotLight", (230, 245, 255), 3, 22, {"Face": "Left", "Angle": 50}), light("PointLight", (230, 245, 255), 0.5, 10, shadows=False)])
    tx, tz = rm.p(rm.W / 2 + 5, rm.D * 0.55)
    part(rm.g, "TrayCart", [3, 0.2, 2], [tx, 3.4, tz], METAL, "Metal")
    for _ in range(4):
        part(rm.g, "Tool", [0.1, 0.05, 1.2], [tx + R.uniform(-1, 1), 3.55, tz + R.uniform(-0.6, 0.6)], (200, 200, 205), "Metal",
             m=rot(yaw=R.uniform(0, 180)), collide=False)
    mx, mz = rm.p(rm.W / 2 - 5, rm.D * 0.55)
    part(rm.g, "Monitor", [2.5, 2, 1.5], [mx, 5.5, mz], (30, 30, 32), "SmoothPlastic")
    part(rm.g, "MonitorScreen", [2.1, 1.5, 0.05], [mx, 5.6, mz - 0.78], (20, 120, 40), "Neon", tags=FLICKER, collide=False,
         children=[light("PointLight", (40, 255, 90), 0.4, 6, shadows=False)])
    part(rm.g, "MonitorPole", [0.2, 4.5, 0.2], [mx, 2.25, mz], METAL, "Metal")
    for k in range(3):
        ox, oz = rm.p(1.5 + k * 1.1, rm.D - 1.5)
        part(rm.g, "OxygenTank", [0.9, 4, 0.9], [ox, 2, oz], (40, 110, 60), "Metal")
    rm.wall_text("NO ANESTHESIA")


def fill_morgue(rm):
    for row in range(3):
        for col in range(int((rm.W - 2) // 3.6)):
            x, z = rm.p(2.8 + col * 3.6, rm.D - 0.7)
            y = 1.8 + row * 3.4
            part(rm.g, "BodyDrawer", [3.2, 3, 0.2], [x, y, z], (150, 155, 155), "Metal", m=rot(yaw=rm.back))
            if R.random() < 0.12:
                ox, oz = rm.p(2.8 + col * 3.6, rm.D - 4)
                part(rm.g, "DrawerOut", [3, 0.3, 6], [ox, y - 0.9, oz], (150, 155, 155), "Metal", m=rot(yaw=rm.back))
                part(rm.g, "SheetBody", [1.5, 0.8, 4.8], [ox, y - 0.4, oz], SHEET, "Fabric", m=rot(yaw=rm.back))
    for k in range(3):
        x, z = rm.p(R.uniform(5, rm.W - 5), R.uniform(5, rm.D - 9))
        gurney(rm.g, x, z, R.uniform(0, 360), body=k < 2)
    x, z = rm.p(rm.W / 2, 4)
    part(rm.g, "MorgueLight", [1, 1, 1], [x, H - 1.5, z], (0, 0, 0), transparency=1, collide=False, tags=FLICKER,
         children=[light("PointLight", (140, 170, 255), 1.2, 22)])
    rm.wall_text("IT CRAWLS")


def fill_passage(rm):
    # doorgang naar de binnenplaats: midden vrij houden
    for side in (0, 1):
        u = 1.35 if side == 0 else rm.W - 1.35
        for k in range(int((rm.D - 4) // 3)):
            x, z = rm.p(u, 2.5 + k * 3)
            cabinet(rm.g, x, z, rm.left + 180 if side == 0 else rm.right + 180, 2.6, 7, 1.4, (95, 110, 105), open_door=R.random() < 0.3)
    x, z = rm.p(rm.W / 2, rm.D - 1.2)
    part(rm.g, "CourtyardSign", [5, 1.2, 0.15], [x, DOOR_H + 1.6, z], (35, 60, 55), "SmoothPlastic", m=rot(yaw=rm.face_door),
         children=[text_gui("COURTYARD", "Front", (200, 205, 190), "SpecialElite", 1)])


FILL = {"passage": fill_passage, "patient": fill_patient, "ward": fill_ward, "office": fill_office, "nurse": fill_nurse, "bath": fill_bath,
        "storage": fill_storage, "records": fill_records, "lab": fill_lab, "cell": fill_cell, "xray": fill_xray,
        "dayroom": fill_dayroom, "boiler": fill_boiler, "collapsed": fill_collapsed, "chapel": fill_chapel,
        "cafeteria": fill_cafeteria, "surgery": fill_surgery, "morgue": fill_morgue}

fuse_spots = []
crawler_spawn = None
for r in rooms:
    rm = Room(r)
    FILL[r["kind"]](rm)
    # rommel
    cx, cz = rm.p(rm.W / 2, rm.D / 2)
    if R.random() < 0.6:
        papers(rm.g, cx, cz, R.randint(3, 8), min(rm.W, rm.D) / 3)
    if R.random() < 0.45:
        bx, bz = rm.p(R.uniform(3, rm.W - 3), R.uniform(4, rm.D - 3))
        blood(decor, bx, bz, R.uniform(1.5, 3), R.uniform(2, 5))
    if R.random() < 0.12 and r["kind"] not in ("chapel", "surgery", "morgue", "cell"):
        rm.wall_text(R.choice(WRITINGS))
    # zekering-plek: in ~60% van de kamers, langs een zijmuur halverwege
    if r["kind"] not in ("cell", "collapsed") and R.random() < 0.6:
        u = R.choice((1.6, rm.W - 1.6))
        fx, fz = rm.p(u, max(4.5, rm.D * 0.35))
        fuse_spots.append((fx, fz))
    if r["kind"] == "morgue" and crawler_spawn is None:
        crawler_spawn = rm.p(rm.W / 2, rm.D / 2)

# ---------------------------------------------------------------- receptie (vaste plek)
rec = props.sub("Reception")
part(rec, "Desk", [16, 3.6, 2], [0, 1.8, 18], WOOD, "WoodPlanks")
part(rec, "DeskTop", [16.6, 0.3, 2.6], [0, 3.75, 18], (60, 50, 42), "Wood")
part(rec, "DeskSide", [2, 3.58, 7], [-8, 1.8, 15.5], WOOD, "WoodPlanks")
part(rec, "DeskSide", [2, 3.58, 7], [8, 1.8, 15.5], WOOD, "WoodPlanks")
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
for s in (-1, 1):
    part(rec, "EntranceDoor", [5, 10, 0.4], [s * 2.6, 5, 39.3], FRAME, "Metal")
    part(rec, "EntranceGlass", [3.4, 4, 0.1], [s * 2.6, 6.5, 39.05], (30, 35, 40), "Glass", transparency=0.3)
for i in range(12):
    t = i / 11
    part(rec, "Chain", [0.5, 0.25, 0.15], [-2.5 + 5 * t, 4.6 + math.sin(t * math.pi) * -0.6, 38.9], (90, 85, 80), "Metal",
         m=rot(roll=(i % 2) * 90 + R.uniform(-15, 15)), collide=False)
part(rec, "Padlock", [0.7, 0.9, 0.35], [0, 4, 38.8], (100, 90, 50), "Metal")
part(rec, "ExitSign", [3, 1, 0.3], [0, 11.5, 39.3], (120, 10, 10), "Neon", tags=FLICKER,
     children=[light("PointLight", (255, 40, 30), 0.8, 12, shadows=False), text_gui("EXIT", "Front", (255, 220, 220), "SpecialElite", 0)])
part(rec, "HospitalSign", [14, 2.2, 0.3], [0, 11.2, 10.8], (30, 40, 38), "SmoothPlastic",
     children=[text_gui("ST. MERCY HOSPITAL", "Back", (170, 175, 160), "SpecialElite", 1)])
part(decor, "WallWriting", [12, 3, 0.05], [-20, 8, 39.4], (0, 0, 0), transparency=1, m=rot(yaw=180), collide=False, shadow=False,
     children=[text_gui("THEY NEVER LEFT", "Back", (110, 8, 8), "Creepster", 1)])
blood(decor, -6, 26, 3, 5)
blood(decor, -5, 20, 1.5, 6)
wheelchair(rec, 18, 30, 210, tipped=True)

# ---------------------------------------------------------------- binnenplaatsen
for yard in ("yardW", "yardE"):
    _, x1, z1, x2, z2, _ = next(a for a in FIXED if a[0] == yard)
    g = props.sub(yard)
    cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
    part(g, "FountainBase", [1.5, 10, 10], [cx, 0.75, cz], (110, 110, 105), "Concrete", shape="Cylinder", m=rot(roll=90))
    part(g, "FountainWater", [0.2, 8.6, 8.6], [cx, 1.4, cz], (35, 45, 30), "Glass", shape="Cylinder", m=rot(roll=90), transparency=0.2, collide=False)
    part(g, "FountainPillar", [5, 1.2, 1.2], [cx, 3.5, cz], (110, 110, 105), "Concrete", shape="Cylinder", m=rot(roll=90))
    part(g, "Statue", [1.6, 3.4, 1.2], [cx, 7.6, cz], (95, 95, 92), "Concrete", m=rot(yaw=R.uniform(0, 360), roll=12))
    part(g, "StatueHead", [1, 1, 1], [cx + 1.2, 0.5, cz + 2], (95, 95, 92), "Concrete", shape="Ball")
    for _ in range(9):
        tx, tz = R.uniform(x1 + 4, x2 - 4), R.uniform(z1 + 4, z2 - 4)
        if abs(tx - cx) < 9 and abs(tz - cz) < 9:
            continue
        tree(g, tx, tz, R.uniform(10, 16))
    for k in range(4):
        bx = cx + (-1) ** k * R.uniform(12, 20)
        bz = cz + (1 if k < 2 else -1) * 9
        part(g, "Bench", [6, 0.4, 1.8], [bx, 1.8, bz], WOOD, "WoodPlanks", m=rot(yaw=R.uniform(-10, 10)))
        part(g, "BenchBack", [6, 1.8, 0.3], [bx, 2.9, bz + 0.8], WOOD, "WoodPlanks", m=rot(yaw=R.uniform(-10, 10)))
    wheelchair(g, cx + 6, cz - 6, R.uniform(0, 360))
    fog = part(g, "YardFog", [x2 - x1, 1, z2 - z1], [cx, 1, cz], (0, 0, 0), transparency=1, collide=False, shadow=False)
    fog["children"] = [{
        "name": "Fog", "className": "ParticleEmitter",
        "properties": {
            "Texture": "rbxasset://textures/particles/smoke_main.dds",
            "Rate": 14, "Lifetime": {"NumberRange": [9, 14]}, "Speed": {"NumberRange": [0.4, 0.9]},
            "Size": {"NumberSequence": {"keypoints": [{"time": 0, "value": 14, "envelope": 0}, {"time": 1, "value": 16, "envelope": 0}]}},
            "Transparency": {"NumberSequence": {"keypoints": [{"time": 0, "value": 1, "envelope": 0}, {"time": 0.5, "value": 0.84, "envelope": 0}, {"time": 1, "value": 1, "envelope": 0}]}},
            "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": [0.45, 0.47, 0.5]}, {"time": 1, "color": [0.45, 0.47, 0.5]}]}},
            "SpreadAngle": [180, 0], "LightEmission": 0,
        },
    }]
    part(lights_g, "YardMoon", [1, 1, 1], [cx, 40, cz], (0, 0, 0), transparency=1, collide=False, shadow=False,
         children=[light("SpotLight", (110, 130, 190), 1.3, 60, {"Face": "Bottom", "Angle": 70})])

# ---------------------------------------------------------------- gangen aankleden
corr = props.sub("Corridors")
corridor_rects = [a for a in FIXED if a[5] == "corridor"]
for name, x1, z1, x2, z2, _ in corridor_rects:
    along_x = x2 - x1 > z2 - z1
    length = (x2 - x1) if along_x else (z2 - z1)
    for _ in range(int(length // 18)):
        t = R.uniform(0.1, 0.9)
        side = R.choice((-1, 1))
        if along_x:
            x, z = x1 + (x2 - x1) * t, (z1 + z2) / 2 + side * 2.6
            yaw = 90 + R.uniform(-10, 10)
        else:
            x, z = (x1 + x2) / 2 + side * 2.6, z1 + (z2 - z1) * t
            yaw = R.uniform(-10, 10)
        roll = R.random()
        if roll < 0.35:
            gurney(corr, x, z, yaw, body=R.random() < 0.4)
        elif roll < 0.55:
            wheelchair(corr, x, z, R.uniform(0, 360), tipped=R.random() < 0.3)
        elif roll < 0.75:
            papers(corr, x, z, R.randint(3, 8), 2.5)
        else:
            blood(decor, x, z, R.uniform(0.8, 1.8), R.uniform(2, 4))
    # leidingen langs het plafond
    if along_x:
        part(decor, "Pipe", [x2 - x1, 0.6, 0.6], [(x1 + x2) / 2, H - 1.0, z1 + 1.3], (70, 75, 72), "Metal", collide=False, shape="Cylinder")
    else:
        part(decor, "Pipe", [z2 - z1, 0.6, 0.6], [x1 + 1.3, H - 1.0, (z1 + z2) / 2], RUST, "Metal", collide=False, shape="Cylinder", m=rot(yaw=90))
# muurteksten in de gangen
for text, pos, yaw in (("RUN", [-4.4, 7, -40], -90), ("HELP US", [40, 7, -29.4], 180), ("IT'S IN THE WALLS", [-60, 7, -100.6], 0),
                       ("TURN BACK", [4.4, 7, -140], 90), ("SHE WATCHES", [125, 7, -60], 0)):
    m = rot(yaw=yaw)
    part(decor, "WallWriting", [10, 3, 0.05], pos, (0, 0, 0), transparency=1, m=m, collide=False, shadow=False,
         children=[text_gui(text, "Back", (110, 8, 8), "Creepster", 1)])
# sleepspoor van bloed van het plein naar het mortuarium
for k in range(14):
    blood(decor, R.uniform(-1, 1) + 1.5, -110 - k * 3, 0.9, 2.2)
# ingestorte trappenhuizen aan het eind van gang C
for sx in (-1, 1):
    g = props.sub("CollapsedStairs")
    x = sx * 66
    debris(g, x, -155, 26, 3.5)
    for k in range(5):
        part(g, "Slab", [R.uniform(4, 7), 0.8, R.uniform(3, 5)], [x + R.uniform(-2, 2), 1 + k * 1.3, -155 + R.uniform(-2, 2)], (110, 108, 100),
             "Concrete", m=rot(yaw=R.uniform(-30, 30), roll=R.uniform(-25, 25), pitch=R.uniform(-15, 15)))
    part(g, "Rebar", [0.15, 6, 0.15], [x + 1, 5, -155], RUST, "Metal", m=rot(roll=35))

# ---------------------------------------------------------------- ronde-markers (Round.server.luau, Stijn)
for x, z in fuse_spots:
    part(markers, "FuseSpawn", [1, 1, 1], [x, 0.6, z], (255, 200, 0), transparency=1, collide=False, tags=["FuseSpawn"])
g = props.sub("FuseBox")
part(g, "FuseBox", [3, 4, 0.8], [-9, 4.5, 39.0], METAL_DARK, "Metal", tags=["FuseBox"],
     children=[text_gui("POWER", "Front", (200, 190, 120), "SpecialElite", 1)])
part(g, "FuseBoxConduit", [0.4, H - 6.5, 0.4], [-9, 6.5 + (H - 6.5) / 2, 39.2], RUST, "Metal")
part(markers, "ExitZone", [10, 10, 3], [0, 5, 37.5], (0, 255, 0), transparency=1, collide=False, tags=["ExitZone"])
cs = crawler_spawn or (17, -62)
part(markers, "CrawlerSpawn", [4, 1, 4], [cs[0], 0.5, cs[1]], (255, 0, 0), transparency=1, collide=False)
markers.add({"name": "SpawnLocation", "className": "SpawnLocation", "properties": {
    "Anchored": True, "Size": [8, 1, 6], "CFrame": cframe([0, 0.5, 34]), "Transparency": 1,
    "CanCollide": False, "Duration": 0, "Neutral": True}})

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf8") as f:
    json.dump(root.node, f, separators=(",", ":"))
kinds = {}
for r in rooms:
    kinds[r["kind"]] = kinds.get(r["kind"], 0) + 1
print(f"Hospital: {len(rooms)} kamers {kinds}")
print(f"  {COUNT['parts']} parts, {COUNT['lights']} lichten, {len(fuse_spots)} zekering-plekken, footprint x {X0}..{X1}, z {Z0}..{Z1}")
