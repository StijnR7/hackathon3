"""Zet een Crawler-animatie uit Blender om naar een Roblox KeyframeSequence (.rbxmx).

Waarom niet via de FBX-import van de Animation Editor? Die rekent de rustpose van deze rig
verkeerd om. Daarom exporteren we zelf per frame de lokale botstand (pose_bone.matrix_basis)
en zetten die om naar Pose.CFrame.

Gebruik:
  1. In Blender (crawler.blend open, actie actief), in de Python-console:
       exec(open(r"tools/crawler_anim_to_rbxmx.py").read()); export_from_blender("assets/monster/crawler_walk.json")
  2. Daarna (gewone Python):
       python tools/crawler_anim_to_rbxmx.py assets/monster/crawler_walk.json src/shared/Monsters/CrawlerWalk.rbxmx CrawlerWalk

Omzetting: de lokale botassen in Roblox zijn die van Blender, 180° gedraaid om de bot-as (Y).
Een lokale transform (x, y, z, qw, qx, qy, qz) wordt dus (-x, y, -z, qw, -qx, qy, -qz).
Verplaatsingen gaan van meter naar studs met dezelfde factor als de 3D-import (1 m = 1/0.28 stud).
"""

import json
import sys
from xml.sax.saxutils import escape

METER_TO_STUD = 1 / 0.28


def export_from_blender(path, armature="CrawlerRig"):
	import bpy

	scene = bpy.context.scene
	arm = bpy.data.objects[armature]
	frames = list(range(scene.frame_start, scene.frame_end + 1))
	data = {}
	for f in frames:
		scene.frame_set(f)
		for pb in arm.pose.bones:
			m = pb.matrix_basis
			loc = m.to_translation()
			q = m.to_quaternion()
			data.setdefault(pb.name, []).append([loc.x, loc.y, loc.z, q.w, q.x, q.y, q.z])
	scene.frame_set(frames[0])
	moving = {
		name: keys
		for name, keys in data.items()
		if any(abs(k[0]) > 1e-5 or abs(k[1]) > 1e-5 or abs(k[2]) > 1e-5 or abs(k[3] - 1) > 1e-6 for k in keys)
	}
	parents = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
	with open(path, "w") as fh:
		json.dump({"fps": scene.render.fps, "frames": len(frames), "parents": parents, "bones": moving}, fh)


def quat_to_matrix(w, x, y, z):
	return [
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
	]


def cframe_xml(name, x, y, z, r):
	parts = [f"<CoordinateFrame name=\"{name}\">"]
	parts += [f"<X>{x:.6f}</X>", f"<Y>{y:.6f}</Y>", f"<Z>{z:.6f}</Z>"]
	for i in range(3):
		for j in range(3):
			parts.append(f"<R{i}{j}>{r[i][j]:.6f}</R{i}{j}>")
	parts.append("</CoordinateFrame>")
	return "".join(parts)


class Writer:
	def __init__(self):
		self.lines = []
		self.ref = 0

	def item(self, cls, props):
		self.ref += 1
		self.lines.append(f"<Item class=\"{cls}\" referent=\"RBX{self.ref}\"><Properties>{props}</Properties>")

	def close(self):
		self.lines.append("</Item>")


def build_rbxmx(data, name):
	fps = data["fps"]
	parents = data["parents"]
	bones = data["bones"]
	children = {}
	for bone, parent in parents.items():
		children.setdefault(parent, []).append(bone)

	# alleen botten die bewegen + hun voorouders
	needed = set()
	for bone in bones:
		while bone:
			needed.add(bone)
			bone = parents[bone]

	w = Writer()
	w.lines.append("<roblox version=\"4\">")
	w.item(
		"KeyframeSequence",
		f"<string name=\"Name\">{escape(name)}</string><bool name=\"Loop\">true</bool>"
		"<token name=\"Priority\">1</token>",  # 1 = Movement
	)

	def write_pose(bone, frame):
		k = bones.get(bone)
		if k:
			v = k[frame]
			x, y, z = -v[0] * METER_TO_STUD, v[1] * METER_TO_STUD, -v[2] * METER_TO_STUD
			r = quat_to_matrix(v[3], -v[4], v[5], -v[6])
			weight = 1
		else:
			x = y = z = 0.0
			r = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
			weight = 0
		w.item("Pose", f"<string name=\"Name\">{escape(bone)}</string>{cframe_xml('CFrame', x, y, z, r)}"
			f"<float name=\"Weight\">{weight}</float>")
		for child in sorted(children.get(bone, [])):
			if child in needed:
				write_pose(child, frame)
		w.close()

	identity = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
	for frame in range(data["frames"]):
		w.item("Keyframe", f"<string name=\"Name\">Keyframe</string><float name=\"Time\">{frame / fps:.6f}</float>")
		w.item("Pose", f"<string name=\"Name\">Body</string>{cframe_xml('CFrame', 0, 0, 0, identity)}"
			"<float name=\"Weight\">0</float>")
		for root in sorted(children.get(None, [])):
			if root in needed:
				write_pose(root, frame)
		w.close()
		w.close()
	w.close()
	w.lines.append("</roblox>")
	return "\n".join(w.lines)


if __name__ == "__main__":
	src, dst, anim_name = sys.argv[1], sys.argv[2], sys.argv[3]
	with open(src) as fh:
		anim = json.load(fh)
	with open(dst, "w", encoding="utf-8") as fh:
		fh.write(build_rbxmx(anim, anim_name))
	print(f"{dst}: {anim['frames']} keyframes, {len(anim['bones'])} bewegende botten")
