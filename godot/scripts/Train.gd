extends Node
# The L: two trains on the elevated tracks, on the same schedule as the web game (it runs on
# the shared world clock), stopping at Calder. They squeal in, chime at the doors and knock
# you flying if you stand on the tracks. Ported from 70_train.js.

var main
var TR = []
var T1 = 17.0
var T2 = 9.0
var T3 = 15.0
var RUN = 270.0
var CYCLE = 96.0
var HALF = 29.2
var warned_t = 0.0
var t_shift = 0.0          # trailer shots move the trains along without touching the time of day

func setup(m):
	main = m
	var D = G.D["TRAIN"]
	T1 = float(D.T1); T2 = float(D.T2); T3 = float(D.T3); RUN = float(D.RUN); CYCLE = float(D.TRAIN_CYCLE); HALF = float(D.TRAIN_HALF)
	var scene = load("res://assets/train/train.glb")
	var deck = float(G.D["DECK_Y"])
	for t in D.list:
		var n = scene.instance()
		_prep(n)
		main.add_child(n)
		n.visible = false
		n.rotation.y = 0.0 if int(t.dir) > 0 else PI
		var box = W.add_box(0, 0, 0, 0, 0, 0, "train")
		# moving box: take it out of the static grid, it lives in DYN
		W.BOXES.erase(box)
		box.x0 = float(t.x) - 1.5; box.x1 = float(t.x) + 1.5; box.y0 = deck + 0.1; box.y1 = deck + 3.7; box.on = false
		W.DYN.append(box)
		var snd = AudioStreamPlayer3D.new(); snd.unit_size = 14; snd.max_db = 3; n.add_child(snd)
		TR.append({ "x": float(t.x), "dir": int(t.dir), "off": float(t.off), "node": n, "box": box, "z": 999.0, "v": 0.0, "state": "gone", "u": 0.0, "screech": false, "closing": false, "snd": snd, "clack_t": 0.0 })

func _prep(n):
	if n is MeshInstance:
		n.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		for i in range(n.mesh.get_surface_count()):
			var m = n.mesh.surface_get_material(i)
			if m is SpatialMaterial:
				m.metallic = 0.0; m.metallic_specular = 0.3
				if n.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
					m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true
	for c in n.get_children(): _prep(c)

func _at(T, t):
	var ph = fposmod(t + T.off, CYCLE)
	var z0 = -T.dir * RUN
	if ph < T1:
		var u = ph / T1
		return [z0 * (1 - (1 - (1 - u) * (1 - u))), -z0 * 2 * (1 - u) / T1, "arrive", u]
	if ph < T1 + T2: return [0.0, 0.0, "dwell", (ph - T1) / T2]
	if ph < T1 + T2 + T3:
		var u2 = (ph - T1 - T2) / T3
		return [T.dir * RUN * u2 * u2, T.dir * RUN * 2 * u2 / T3, "depart", u2]
	return [T.dir * 999.0, 0.0, "gone", 0.0]

func next_train_in():
	var best = 999.0
	for T in TR:
		var ph = fposmod(G.world_seconds() + T.off, CYCLE)
		best = min(best, T1 - ph if ph < T1 else CYCLE - ph + T1)
	return best

func train_near_calder():
	for T in TR:
		if T.state != "gone" and abs(T.z) < 70: return true
	return false

func update(dt):
	var cam = main.camera.global_transform.origin
	var deck = float(G.D["DECK_Y"])
	for T in TR:
		var prev = T.state
		var s = _at(T, G.world_seconds() + t_shift)
		T.z = s[0]; T.v = s[1]; T.state = s[2]; T.u = s[3]
		var vis = T.state != "gone" and abs(T.z) < 330
		T.node.visible = vis
		T.node.translation = Vector3(T.x, deck + 0.12, T.z)
		T.box.on = vis and abs(T.z) < W.BOUND + HALF
		T.box.z0 = T.z - HALF; T.box.z1 = T.z + HALF
		if not vis: continue
		var d = Vector2(T.x - cam.x, max(0.0, abs(T.z - cam.z) - HALF)).length()
		if T.state == "arrive" and T.u > 0.62 and not T.screech and d < 140:
			T.screech = true; _snd(T, "squeal", 0.9)
		if T.state != "arrive": T.screech = false
		if prev == "arrive" and T.state == "dwell" and d < 120:
			_snd(T, "chime", 0.8)
			main.sfx.play3d("door_slide", Vector3(T.x, deck + 1, T.z), 0.5)
		if T.state == "dwell" and T.u > 0.8 and not T.closing:
			T.closing = true
			if d < 120: _snd(T, "chime", 0.7)
		if T.state != "dwell": T.closing = false
		# wheels over the joints
		if abs(T.v) > 2 and d < 120:
			T.clack_t -= dt * abs(T.v) / 12.0
			if T.clack_t <= 0:
				T.clack_t = 1.0
				main.sfx.play3d("clack", Vector3(T.x, deck, clamp(cam.z, T.z - HALF, T.z + HALF)), clamp(0.9 - d / 140.0, 0.1, 0.7))
	_tracks(dt)

func _snd(T, name, vol):
	var s = main.sfx.stream(name)
	if s == null: return
	T.snd.stream = s; T.snd.unit_db = linear2db(vol); T.snd.translation = Vector3(0, 1.5, 0); T.snd.play()

# standing on the tracks when a train comes is a bad idea
func _tracks(dt):
	var P = main.player
	warned_t = max(0, warned_t - dt)
	var deck = float(G.D["DECK_Y"])
	if P.car or P.pos.y < deck - 0.2 or P.pos.y > deck + 2: return
	for T in TR:
		if T.state == "gone" or abs(P.pos.x - T.x) > 1.9: continue
		var rel = P.pos.z - T.z
		var ahead = rel * sign(T.v if abs(T.v) > 0.01 else T.dir)
		if abs(T.v) > 0.6 and ahead > 0 and ahead < HALF + 90 and warned_t <= 0:
			warned_t = 4; main.sfx.play3d("train_horn", Vector3(T.x, deck + 2, T.z), 1.0); main.hud.banner("Train coming", "Get off the tracks")
		if abs(rel) < HALF + P.radius and abs(T.v) > 0.6 and not P.is_ragdoll():
			var side = -1 if P.pos.x < T.x else 1
			P.knock(Vector3(side * 7.5, 6.5, sign(T.v) * 6.0), 26 + abs(T.v) * 0.7, 2.6)
			main.sfx.play("boom", 0.6)
			main.hud.banner("Knocked down by the L", "Stay off the tracks")
			G.S["flags"]["trainHits"] = int(G.S["flags"].get("trainHits", 0)) + 1
			main.story.post_feed("@L_platform_lurker", "somebody really got clipped by the L at Calder %s" % ("AGAIN" if G.S["flags"]["trainHits"] > 1 else ""))
