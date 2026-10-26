# Zoekt in een Rojo .model.json naar z-fighting: twee zichtbare parts met een vlak op exact dezelfde plek
# (zelfde kant op) die elkaar overlappen. Alleen parts die recht staan (rotatie in stappen van 90°) worden gecheckt.
# Gebruik: python tools/maps/check_zfight.py maps/Hospital.model.json
import json
import sys
from collections import Counter, defaultdict

EPS = 0.002
MIN_AREA = 0.05
HIDDEN_Y = (0.0, 14.0)  # vloer- en plafondhoogte: onder-/bovenkanten daar zie je niet


def boxes(node, out):
    p = node.get("properties", {})
    if node.get("className") in ("Part", "SpawnLocation") and "Size" in p and p.get("Transparency", 0) < 1:
        cf = p["CFrame"]["CFrame"]
        m = cf["orientation"]
        if all(abs(v) < 1e-3 or abs(abs(v) - 1) < 1e-3 for row in m for v in row) and p.get("Shape") in (None, "Block"):
            s = p["Size"]
            half = [sum(abs(m[i][k]) * s[k] for k in range(3)) / 2 for i in range(3)]
            pos = cf["position"]
            out.append((node.get("name"), [pos[i] - half[i] for i in range(3)], [pos[i] + half[i] for i in range(3)]))
    for c in node.get("children", []):
        boxes(c, out)


def overlap(a0, a1, b0, b1):
    return max(0.0, min(a1, b1) - max(a0, b0))


def main(path):
    with open(path, encoding="utf8") as f:
        root = json.load(f)
    items = []
    boxes(root, items)
    grid = defaultdict(list)
    for i, (_, lo, hi) in enumerate(items):
        for gx in range(int(lo[0] // 10), int(hi[0] // 10) + 1):
            for gz in range(int(lo[2] // 10), int(hi[2] // 10) + 1):
                grid[(gx, gz)].append(i)
    seen = set()
    hits = Counter()
    examples = {}
    for cell in grid.values():
        for ai in range(len(cell)):
            for bi in range(ai + 1, len(cell)):
                i, j = cell[ai], cell[bi]
                key = (min(i, j), max(i, j))
                if key in seen:
                    continue
                seen.add(key)
                na, alo, ahi = items[i]
                nb, blo, bhi = items[j]
                for k in range(3):
                    o = [d for d in range(3) if d != k]
                    area = overlap(alo[o[0]], ahi[o[0]], blo[o[0]], bhi[o[0]]) * overlap(alo[o[1]], ahi[o[1]], blo[o[1]], bhi[o[1]])
                    if area < MIN_AREA:
                        continue
                    same_lo = abs(alo[k] - blo[k]) < EPS and not (k == 1 and any(abs(alo[k] - y) < EPS for y in HIDDEN_Y))
                    same_hi = abs(ahi[k] - bhi[k]) < EPS and not (k == 1 and any(abs(ahi[k] - y) < EPS for y in HIDDEN_Y))
                    if same_lo or same_hi:
                        pair = tuple(sorted((na, nb)))
                        hits[pair] += 1
                        examples.setdefault(pair, (round((alo[0] + ahi[0]) / 2, 1), round((alo[1] + ahi[1]) / 2, 1), round((alo[2] + ahi[2]) / 2, 1)))
                        break
    total = sum(hits.values())
    print(f"{len(items)} rechte parts gecheckt, {total} paren met z-fighting")
    for pair, n in hits.most_common(25):
        print(f"  {n:5d}  {pair[0]} / {pair[1]}  bv. bij {examples[pair]}")
    return total


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1]) else 0)
