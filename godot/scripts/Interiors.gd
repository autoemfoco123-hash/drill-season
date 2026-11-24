extends Node
# Places you walk into. At the door press E: the screen fades and you are inside a real room
# you walk around in, in third or first person, with things to use:
#  - Basement 808, the studio under Calder Ave: a glass vocal booth with the mic (record a
#    session), the mixing desk (the studio's board), a couch under the plaques, LED strips,
#    and the steps back up to the street.
#  - Ironside Arms, a gun shop on Calder Ave & Bishop St: a glass counter with the clerk (guns,
#    ammo, first aid), rifles on the pegboard, ammo shelves, and the workbench (parts and
#    finishes).
#  - Home, on Bishop St: the living room (mama asleep on the couch, the TV on), the kitchen
#    (the fridge, the laptop on the table to save), the bedroom (the bed to lay low, the
#    closet for the wardrobe).
#  - The Calder Mini Mart: aisles, the drinks coolers, the coffee machine, the counter.
# The rooms are built out of sight above the city: the physics keeps everyone on a floor, the
# camera stops at the walls, the snow stops falling, guns stay holstered, and the light inside
# is the room's own.

const MB = preload("res://scripts/MeshBuild.gd")

var main
var inside = ""
var busy = false
var clerk = null
var clerk_t = 0.0
var cashier = null
var mama = null
var tv_mat = null
var spots = []          # interaction points added to G.D["INTERACT"]

const ROOMS = {
	"studio": { "o": Vector3(-200, 300, 200), "name": "Basement 808", "addr": "2242 W Calder Ave · downstairs",
		"door": Vector3(41, 0, -8.0), "out": Vector3(0, 0, 1.2), "out_yaw": PI, "spawn": Vector3(3.6, 0, 3.2), "amb": Color(0.46, 0.4, 0.5), "sound": "lock" },
	"gunshop": { "o": Vector3(-168, 300, 200), "name": "Ironside Arms", "addr": "Calder Ave & Bishop St",
		"door": Vector3(-15.2, 0, -8.2), "out": Vector3(0, 0, 1.2), "out_yaw": PI, "spawn": Vector3(0, 0, 3.4), "amb": Color(0.42, 0.41, 0.39), "sound": "shopbell" },
	"home": { "o": Vector3(-136, 300, 200), "name": "Home", "addr": "6127 S Bishop St",
		"door": Vector3(-8.4, 0, -42), "out": Vector3(1.3, 0, 0), "out_yaw": -PI / 2, "spawn": Vector3(3.8, 0, 3.5), "amb": Color(0.38, 0.34, 0.31), "sound": "lock" },
	"store": { "o": Vector3(-104, 300, 200), "name": "Calder Mini Mart", "addr": "Calder Ave & Bishop St · open late",
		"door": Vector3(16, 0, -8.4), "out": Vector3(0, 0, 1.3), "out_yaw": PI, "spawn": Vector3(2.5, 0, 3.4), "amb": Color(0.37, 0.38, 0.37), "sound": "shopbell" },
}

func setup(m):
	main = m
	_build_studio()
	_build_gunshop()
	_build_gunshop_front()
	_build_home()
	_build_store()
	# the doors and everything you can use inside
	var I = G.D["INTERACT"]
	_spot(I, "gunshop", Vector3(-15.2, 0, -8.6), 2.4)
	var so = ROOMS.studio.o
	_spot(I, "in_exit_studio", so + Vector3(3.6, 0.54, 5.4), 1.1)
	_spot(I, "in_booth", so + Vector3(-3.3, 0, -4.1), 1.3)
	_spot(I, "in_desk", so + Vector3(0.7, 0, -3.9), 1.5)
	_spot(I, "in_couch", so + Vector3(3.0, 0, 0.5), 1.4)
	var go = ROOMS.gunshop.o
	_spot(I, "in_exit_gunshop", go + Vector3(0, 0, 4.2), 1.3)
	_spot(I, "in_counter", go + Vector3(-0.5, 0, 0.3), 1.8)
	_spot(I, "in_bench", go + Vector3(-4.3, 0, 2.4), 1.5)
	var ho = ROOMS.home.o
	_spot(I, "in_exit_home", ho + Vector3(3.8, 0, 4.3), 1.2)
	_spot(I, "in_bed", ho + Vector3(-3.2, 0, -2.4), 1.3)
	_spot(I, "in_closet", ho + Vector3(-4.4, 0, -1.2), 1.0)
	_spot(I, "in_fridge", ho + Vector3(-4.4, 0, 0.9), 1.1)
	_spot(I, "in_laptop", ho + Vector3(-2.4, 0, 3.4), 1.1)
	_spot(I, "in_tv", ho + Vector3(2.2, 0, -0.4), 1.3)
	var to = ROOMS.store.o
	_spot(I, "in_exit_store", to + Vector3(2.5, 0, 4.3), 1.2)
	_spot(I, "in_register", to + Vector3(-3.6, 0, 3.6), 1.4)
	_spot(I, "in_coffee", to + Vector3(4.3, 0, 2.0), 1.2)

func _spot(I, id, p, r):
	var it = { "id": id, "x": p.x, "y": p.y, "z": p.z, "r": r }
	I.append(it); spots.append(it)

# ---------------------------------------------------------------- building helpers
var _mb
var _o = Vector3()
var _mats = {}

func _m(k, col, ink = false, unshaded = false, alpha = 1.0):
	if not _mats.has(k):
		var m = SpatialMaterial.new(); m.albedo_color = Color(col.r, col.g, col.b, alpha); m.roughness = 0.8
		if unshaded: m.flags_unshaded = true
		if alpha < 1.0:
			m.flags_transparent = true; m.params_cull_mode = SpatialMaterial.CULL_DISABLED
		elif not unshaded:
			G.toon(m, ink)
		_mats[k] = m
	_mb.mat(k, _mats[k])
	return k

# a box: centre and size in the room's own coordinates; solid ones also block movement
func _b(k, c, s, solid = false, rot = Vector3()):
	var xf = Transform(Basis().rotated(Vector3(1, 0, 0), rot.x).rotated(Vector3(0, 1, 0), rot.y).rotated(Vector3(0, 0, 1), rot.z), _o + c)
	_mb.box(k, xf, s, 0.5, false)
	if solid:
		var h = s * 0.5
		W.add_box(_o.x + c.x - h.x, _o.y + c.y - h.y, _o.z + c.z - h.z, _o.x + c.x + h.x, _o.y + c.y + h.y, _o.z + c.z + h.z, "interior")

func _shell(w, d, h):
	# floor, ceiling and four walls, 0.3 m thick, all solid
	_b("floor", Vector3(0, -0.15, 0), Vector3(w + 0.6, 0.3, d + 0.6), true)
	_b("ceil", Vector3(0, h + 0.15, 0), Vector3(w + 0.6, 0.3, d + 0.6), true)
	_b("wall", Vector3(-w / 2 - 0.15, h / 2, 0), Vector3(0.3, h, d + 0.6), true)
	_b("wall", Vector3(w / 2 + 0.15, h / 2, 0), Vector3(0.3, h, d + 0.6), true)
	_b("wall", Vector3(0, h / 2, -d / 2 - 0.15), Vector3(w, h, 0.3), true)
	_b("wall", Vector3(0, h / 2, d / 2 + 0.15), Vector3(w, h, 0.3), true)

func _light(p, col, energy, rng):
	var l = OmniLight.new(); l.light_color = col; l.light_energy = energy; l.omni_range = rng; l.omni_attenuation = 1.4
	l.translation = _o + p
	main.add_child(l)
	return l

func _commit():
	var root = Spatial.new(); main.add_child(root)
	_mb.commit(root)

func _gun(id, p, rot, s = 1.0):
	var g = GUN.build(id)
	main.add_child(g)
	g.translation = _o + p; g.rotation = rot; g.scale = Vector3(s, s, s)

# ---------------------------------------------------------------- Basement 808
func _build_studio():
	_mb = MB.new(); _mats.clear()
	_o = ROOMS.studio.o
	var w = 10.0
	var d = 12.0
	var h = 3.0
	_m("floor", Color(0.14, 0.15, 0.17)); _m("ceil", Color(0.11, 0.11, 0.13)); _m("wall", Color(0.23, 0.24, 0.28))
	_m("rug", Color(0.36, 0.16, 0.14)); _m("foam", Color(0.08, 0.08, 0.1)); _m("wood", Color(0.24, 0.16, 0.11), true)
	_m("black", Color(0.05, 0.05, 0.06), true); _m("metal", Color(0.5, 0.52, 0.56), true); _m("leather", Color(0.3, 0.18, 0.12), true)
	_m("glass", Color(0.65, 0.8, 1.0), false, true, 0.16); _m("frame", Color(0.1, 0.1, 0.12), true); _m("gold", Color(0.86, 0.68, 0.26), true)
	_m("plat", Color(0.82, 0.84, 0.88), true); _m("ledp", Color(0.62, 0.36, 1.0), false, true); _m("ledo", Color(1.0, 0.55, 0.2), false, true)
	_m("screen", Color(0.22, 0.46, 0.9), false, true); _m("white", Color(0.9, 0.9, 0.88), true); _m("red", Color(0.85, 0.12, 0.12), false, true)
	_m("duct", Color(0.3, 0.32, 0.36)); _m("poster1", Color(0.85, 0.4, 0.15)); _m("poster2", Color(0.15, 0.45, 0.75)); _m("poster3", Color(0.9, 0.85, 0.75))
	_shell(w, d, h)
	_b("rug", Vector3(1.0, 0.01, 0.6), Vector3(3.6, 0.02, 2.6))
	# ducts and pipes under the ceiling
	_b("duct", Vector3(-1.5, h - 0.25, 0), Vector3(0.5, 0.35, d))
	_b("duct", Vector3(2.8, h - 0.12, 0), Vector3(0.12, 0.12, d))
	# LED strips along the top of the walls: purple on the booth side, orange on the couch side
	_b("ledp", Vector3(-w / 2 + 0.03, h - 0.08, 0), Vector3(0.04, 0.04, d))
	_b("ledp", Vector3(0, h - 0.08, -d / 2 + 0.03), Vector3(w, 0.04, 0.04))
	_b("ledo", Vector3(w / 2 - 0.03, h - 0.08, 0), Vector3(0.04, 0.04, d))
	_b("ledo", Vector3(0, h - 0.08, d / 2 - 0.03), Vector3(w, 0.04, 0.04))
	# the steps up to the street door (+z wall), and the door with a red exit light
	for i in range(3):
		_b("wood", Vector3(3.6, 0.09 * (i + 1), 3.95 + i * 0.3), Vector3(1.8, 0.18 * (i + 1), 0.3), true)
	_b("floor", Vector3(3.6, 0.27, 5.35), Vector3(1.8, 0.54, 1.3), true)
	_b("frame", Vector3(3.6, 0.54 + 1.1, 5.98), Vector3(1.2, 2.2, 0.06))
	_b("metal", Vector3(3.15, 0.54 + 1.05, 5.93), Vector3(0.06, 0.06, 0.06))
	_b("red", Vector3(3.6, 0.54 + 2.35, 5.96), Vector3(0.5, 0.14, 0.04))
	# the vocal booth in the far corner: glass on two sides with a frame, foam inside
	var bx0 = -w / 2
	var bx1 = -1.9
	var bz0 = -d / 2
	var bz1 = -2.9
	_b("frame", Vector3(bx1, h / 2, (bz0 + bz1) / 2), Vector3(0.08, h, 0.08) + Vector3(0, 0, 0))
	_b("glass", Vector3(bx1, h / 2, (bz0 + bz1) / 2), Vector3(0.05, h, bz1 - bz0), true)
	_b("frame", Vector3(bx1, h / 2, bz1), Vector3(0.1, h, 0.1), true)
	_b("glass", Vector3((bx0 + bx1 - 1.15) / 2, h / 2, bz1), Vector3(bx1 - bx0 - 1.15, h, 0.05), true)
	_b("frame", Vector3(bx1 - 1.15, h / 2, bz1), Vector3(0.1, h, 0.1), true)
	_b("frame", Vector3((bx0 + bx1) / 2, h - 0.15, bz1), Vector3(bx1 - bx0, 0.3, 0.12))
	for fy in range(5):
		for fz in range(5):
			_b("foam", Vector3(bx0 + 0.05, 0.5 + fy * 0.5, bz0 + 0.4 + fz * 0.62), Vector3(0.1, 0.42, 0.5))
	for fy2 in range(5):
		for fx in range(5):
			_b("foam", Vector3(bx0 + 0.4 + fx * 0.6, 0.5 + fy2 * 0.5, bz0 + 0.05), Vector3(0.5, 0.42, 0.1))
	# the mic: tripod, stand, shock mount, pop filter; a music stand; headphones on a hook
	var mc = Vector3(-3.4, 0, -4.6)
	for a in [0.0, 2.1, 4.2]:
		_b("black", mc + Vector3(cos(a) * 0.18, 0.04, sin(a) * 0.18), Vector3(0.38, 0.03, 0.03), false, Vector3(0, -a, 0))
	_b("black", mc + Vector3(0, 0.78, 0), Vector3(0.03, 1.5, 0.03))
	_b("metal", mc + Vector3(0, 1.58, 0.06), Vector3(0.07, 0.18, 0.07))
	_b("black", mc + Vector3(0, 1.58, 0.22), Vector3(0.16, 0.16, 0.01))
	_b("black", mc + Vector3(0.9, 0.55, 0.4), Vector3(0.02, 1.1, 0.02))
	_b("black", mc + Vector3(0.9, 1.1, 0.4), Vector3(0.45, 0.32, 0.02), false, Vector3(-0.3, 0, 0))
	_b("white", mc + Vector3(0.9, 1.12, 0.42), Vector3(0.36, 0.26, 0.01), false, Vector3(-0.3, 0, 0))
	_b("black", Vector3(-1.95 - 0.06, 1.55, -4.0), Vector3(0.06, 0.18, 0.16))
	# the mixing desk against the back wall: desk, console with lights, monitors, a screen, keys
	var dz = -d / 2 + 0.5
	_b("wood", Vector3(0.8, 0.76, dz), Vector3(3.6, 0.06, 0.95), true)
	for lx in [-0.9, 2.5]:
		_b("wood", Vector3(lx, 0.37, dz), Vector3(0.08, 0.74, 0.85), true)
	_b("black", Vector3(0.8, 0.86, dz + 0.1), Vector3(1.6, 0.12, 0.6), false, Vector3(-0.18, 0, 0))
	var leds = ["ledo", "ledp", "screen", "red"]
	for i in range(24):
		_b(leds[i % 4], Vector3(0.12 + (i % 12) * 0.12, 0.94 + (i / 12) * 0.02, dz + 0.02 + (i / 12) * 0.18), Vector3(0.03, 0.02, 0.03))
	for sx in [-0.55, 2.15]:
		_b("black", Vector3(sx, 1.0, dz - 0.12), Vector3(0.3, 0.42, 0.3))
		_b("metal", Vector3(sx, 0.96, dz + 0.04), Vector3(0.18, 0.18, 0.01))
	_b("black", Vector3(0.8, 1.25, dz - 0.25), Vector3(1.0, 0.6, 0.05))
	_b("screen", Vector3(0.8, 1.25, dz - 0.22), Vector3(0.92, 0.52, 0.01))
	_b("white", Vector3(0.8, 0.8, dz + 0.36), Vector3(0.9, 0.03, 0.18))
	# the chair
	var ch = Vector3(0.7, 0, -4.3)
	_b("black", ch + Vector3(0, 0.25, 0), Vector3(0.05, 0.5, 0.05))
	_b("black", ch + Vector3(0, 0.03, 0), Vector3(0.6, 0.04, 0.06))
	_b("black", ch + Vector3(0, 0.03, 0), Vector3(0.06, 0.04, 0.6))
	_b("leather", ch + Vector3(0, 0.52, 0), Vector3(0.55, 0.1, 0.55), true)
	_b("leather", ch + Vector3(0, 0.9, 0.26), Vector3(0.52, 0.7, 0.08))
	# the couch along the right wall, a low table, plaques above it
	var cx = w / 2 - 0.55
	_b("leather", Vector3(cx, 0.22, 0.5), Vector3(1.0, 0.44, 4.0), true)
	_b("leather", Vector3(cx + 0.38, 0.7, 0.5), Vector3(0.25, 0.6, 4.0))
	for az in [-1.6, 2.6]:
		_b("leather", Vector3(cx, 0.55, az), Vector3(1.0, 0.25, 0.2))
	for i2 in range(3):
		_b("leather", Vector3(cx - 0.05, 0.5, -0.8 + i2 * 1.3), Vector3(0.8, 0.14, 1.22))
	_b("wood", Vector3(2.4, 0.38, 0.5), Vector3(0.8, 0.06, 1.6), true)
	for tz in [-0.2, 1.2]:
		for tx in [2.1, 2.7]:
			_b("wood", Vector3(tx, 0.18, tz), Vector3(0.05, 0.36, 0.05))
	_b("white", Vector3(2.35, 0.46, 0.2), Vector3(0.08, 0.1, 0.08))
	_b("red", Vector3(2.5, 0.45, 0.75), Vector3(0.07, 0.08, 0.07))
	_b("black", Vector3(2.3, 0.42, 1.0), Vector3(0.3, 0.02, 0.22))
	for pi in range(4):
		var pz = -1.4 + pi * 1.25
		_b("frame", Vector3(w / 2 - 0.03, 1.95, pz), Vector3(0.04, 0.62, 0.52))
		_b("gold" if pi % 2 == 0 else "plat", Vector3(w / 2 - 0.06, 2.0, pz), Vector3(0.02, 0.36, 0.36))
		_b("black", Vector3(w / 2 - 0.075, 2.0, pz), Vector3(0.02, 0.07, 0.07))
	# posters on the left wall, outside the booth
	_b("poster1", Vector3(-w / 2 + 0.03, 1.7, 0.2), Vector3(0.03, 0.9, 0.65))
	_b("poster2", Vector3(-w / 2 + 0.03, 1.75, 1.3), Vector3(0.03, 0.75, 0.55))
	_b("poster3", Vector3(-w / 2 + 0.03, 1.6, 2.6), Vector3(0.03, 1.0, 0.7))
	_commit()
	_light(Vector3(2.0, 2.6, 0.6), Color(1, 0.66, 0.42), 1.25, 8.0)
	_light(Vector3(-3.0, 2.6, -3.6), Color(0.68, 0.48, 1.0), 1.1, 6.0)
	_light(Vector3(0.8, 2.4, -4.4), Color(0.7, 0.8, 1.0), 0.6, 4.0)

# ---------------------------------------------------------------- Ironside Arms
func _build_gunshop():
	_mb = MB.new(); _mats.clear()
	_o = ROOMS.gunshop.o
	var w = 12.0
	var d = 10.0
	var h = 3.4
	_m("floor", Color(0.7, 0.68, 0.63)); _m("tile", Color(0.22, 0.24, 0.27)); _m("ceil", Color(0.78, 0.77, 0.74)); _m("wall", Color(0.6, 0.57, 0.51))
	_m("panel", Color(0.35, 0.23, 0.15)); _m("peg", Color(0.42, 0.44, 0.47)); _m("counter", Color(0.17, 0.18, 0.2), true); _m("glass", Color(0.7, 0.85, 1.0), false, true, 0.18)
	_m("lamp", Color(1, 1, 0.96), false, true); _m("wood", Color(0.42, 0.29, 0.19), true); _m("steel", Color(0.34, 0.36, 0.4), true); _m("red", Color(0.85, 0.15, 0.12), true)
	_m("green", Color(0.24, 0.42, 0.24), true); _m("yellow", Color(0.88, 0.7, 0.2), true); _m("white", Color(0.92, 0.92, 0.9), true); _m("neon", Color(1.0, 0.22, 0.2), false, true)
	_m("felt", Color(0.12, 0.2, 0.16))
	_shell(w, d, h)
	# a checker floor
	for ix in range(12):
		for iz in range(10):
			if (ix + iz) % 2 == 0:
				_b("tile", Vector3(-w / 2 + 0.5 + ix, 0.005, -d / 2 + 0.5 + iz), Vector3(1.0, 0.01, 1.0))
	# wood panelling on the lower walls
	_b("panel", Vector3(-w / 2 + 0.02, 0.55, 0), Vector3(0.04, 1.1, d))
	_b("panel", Vector3(w / 2 - 0.02, 0.55, 0), Vector3(0.04, 1.1, d))
	_b("panel", Vector3(0, 0.55, d / 2 - 0.02), Vector3(w, 1.1, 0.04))
	# fluorescent panels
	for lx in [-3.0, 0.0, 3.0]:
		for lz in [-2.2, 1.6]:
			_b("lamp", Vector3(lx, h - 0.03, lz), Vector3(1.3, 0.04, 0.32))
	# the back wall: pegboard with rifles and pistols, a neon sign
	_b("peg", Vector3(0, 1.85, -d / 2 + 0.03), Vector3(8.0, 2.2, 0.04))
	_b("neon", Vector3(0, 3.05, -d / 2 + 0.05), Vector3(2.4, 0.08, 0.04))
	_b("neon", Vector3(0, 2.92, -d / 2 + 0.05), Vector3(0.08, 0.2, 0.04))
	# the counter: dark base, glass top with pistols inside
	_b("counter", Vector3(-0.5, 0.45, -0.8), Vector3(7.0, 0.9, 0.7), true)
	_b("glass", Vector3(-0.5, 1.0, -0.8), Vector3(7.0, 0.2, 0.7), true)
	_b("felt", Vector3(-0.5, 0.905, -0.8), Vector3(6.8, 0.01, 0.6))
	_b("counter", Vector3(3.15, 0.5, -2.3), Vector3(0.7, 1.0, 2.3), true)
	_b("steel", Vector3(-3.2, 1.2, -0.85), Vector3(0.38, 0.22, 0.28))
	_b("lamp", Vector3(-3.2, 1.22, -0.7), Vector3(0.3, 0.14, 0.01))
	# the workbench along the left wall: top, legs, vise, tool board, a lamp
	_b("wood", Vector3(-w / 2 + 0.45, 0.9, 2.4), Vector3(0.9, 0.08, 3.0), true)
	for bz in [1.0, 3.8]:
		_b("steel", Vector3(-w / 2 + 0.45, 0.45, bz), Vector3(0.8, 0.9, 0.06))
	_b("steel", Vector3(-w / 2 + 0.7, 1.02, 1.6), Vector3(0.2, 0.16, 0.24))
	_b("peg", Vector3(-w / 2 + 0.03, 1.7, 2.4), Vector3(0.04, 1.2, 2.8))
	for ti in range(6):
		_b("steel" if ti % 2 == 0 else "red", Vector3(-w / 2 + 0.07, 1.5 + (ti % 2) * 0.35, 1.3 + ti * 0.42), Vector3(0.04, 0.3 + (ti % 3) * 0.08, 0.06))
	_b("yellow", Vector3(-w / 2 + 0.5, 1.25, 3.4), Vector3(0.12, 0.5, 0.04))
	_b("lamp", Vector3(-w / 2 + 0.5, 1.5, 3.3), Vector3(0.14, 0.08, 0.14))
	# shelves of ammo along the right wall
	for sy in [0.5, 1.1, 1.7]:
		_b("wood", Vector3(w / 2 - 0.35, sy, 1.6), Vector3(0.6, 0.05, 3.6), true)
		for k in range(10):
			var col = ["red", "green", "yellow", "steel"][(k + int(sy * 3)) % 4]
			_b(col, Vector3(w / 2 - 0.35, sy + 0.12, 0.05 + k * 0.34), Vector3(0.3, 0.2, 0.22))
	# the front: windows with bars either side of the door, the door, a mat
	for wx in [-3.5, 3.5]:
		_b("glass", Vector3(wx, 1.6, d / 2 - 0.02), Vector3(2.4, 1.4, 0.03))
		for bi in range(7):
			_b("steel", Vector3(wx - 1.1 + bi * 0.37, 1.6, d / 2 - 0.08), Vector3(0.04, 1.4, 0.04))
	_b("counter", Vector3(0, 1.1, d / 2 - 0.03), Vector3(1.2, 2.2, 0.05))
	_b("steel", Vector3(0.45, 1.05, d / 2 - 0.08), Vector3(0.05, 0.25, 0.05))
	_b("felt", Vector3(0, 0.012, d / 2 - 0.8), Vector3(1.6, 0.02, 1.0))
	_commit()
	# the guns themselves, built like the ones you carry
	# pistols lying on their side in the case, rifles hung sideways on the pegboard
	for i in range(5):
		_gun(["k9", "buzz", "k9", "buzz", "k9"][i], Vector3(-3.4 + i * 1.5, 0.95, -0.8), Vector3(0, PI / 2 + 0.25, PI / 2), 0.9)
	for i2 in range(6):
		_gun(["draft", "plow", "dragon"][i2 % 3], Vector3(-3.0 + (i2 % 3) * 3.0, 1.45 + int(i2 / 3) * 0.75, -d / 2 + 0.14), Vector3(0, -PI / 2, 0), 1.35)
	_light(Vector3(-3.0, 3.0, 0.0), Color(1, 0.96, 0.88), 0.72, 9.0)
	_light(Vector3(3.0, 3.0, 0.0), Color(1, 0.96, 0.88), 0.72, 9.0)
	_light(Vector3(0, 2.8, -3.8), Color(1, 0.5, 0.45), 0.5, 4.0)
	# Vic, behind the counter
	clerk = load("res://scripts/Human.gd").new().build(G.skin_opts({ "tone": 2, "hair": "buzz", "beard": 1, "head": "cap", "headCol": 0x2a3a2a, "top": "leather", "topCol": 0x3a2a1e, "top2": 0x262b33, "pants": "jeans", "pantsCol": 0x1e2f4a, "shoes": "boot", "shoesCol": 0x4a3a2a, "build": 2, "glasses": 1 }))
	main.add_child(clerk)
	G.toon_tree(clerk, true)
	clerk.translation = _o + Vector3(-0.6, 0, -1.9)

# the front of the shop on Calder Ave: a door, barred windows and a lit sign
func _build_gunshop_front():
	_mb = MB.new(); _mats.clear()
	_o = Vector3(-15.2, 0, -10.0)
	_m("door", Color(0.14, 0.15, 0.17), true); _m("steel", Color(0.3, 0.32, 0.36), true); _m("glass", Color(0.4, 0.5, 0.6), false, true, 0.6)
	_m("sign", Color(0.09, 0.09, 0.11), true)
	_b("door", Vector3(0, 1.15, 0.05), Vector3(1.3, 2.3, 0.1))
	_b("steel", Vector3(0.45, 1.1, 0.12), Vector3(0.05, 0.25, 0.05))
	for wx in [-2.4, 2.4]:
		_b("glass", Vector3(wx, 1.5, 0.03), Vector3(2.0, 1.3, 0.04))
		for bi in range(6):
			_b("steel", Vector3(wx - 0.9 + bi * 0.36, 1.5, 0.08), Vector3(0.04, 1.35, 0.04))
	_b("sign", Vector3(0, 2.75, 0.1), Vector3(3.6, 0.7, 0.12))
	_commit()
	var s = MeshInstance.new(); var q = QuadMesh.new(); q.size = Vector2(3.4, 0.6); s.mesh = q
	var sm = SpatialMaterial.new(); sm.flags_unshaded = true; sm.flags_transparent = true
	sm.albedo_texture = load("res://assets/ui/sign_gunshop.png")
	s.material_override = sm
	s.translation = _o + Vector3(0, 2.75, 0.17)
	main.add_child(s)

# ---------------------------------------------------------------- going in and out
func label(it):
	match it.id:
		"gunshop": return "Enter Ironside Arms"
		"in_exit_studio": return "Go up to Calder Ave"
		"in_exit_gunshop": return "Leave the shop"
		"in_booth": return "Step in the booth · record" + ((" · busy %ds" % int(ceil(main.story.cd_left("studio")))) if main.story.cd_left("studio") > 0 else "")
		"in_desk": return "The board"
		"in_couch": return "Sit down · warm up"
		"in_counter": return "Talk to Vic · guns and ammo"
		"in_bench": return "Workbench · parts and finishes"
		"in_exit_home": return "Go out to Bishop St"
		"in_bed": return "Lay low · sleep it off" + ((" · %ds" % int(ceil(main.story.cd_left("laylow")))) if main.story.cd_left("laylow") > 0 else "")
		"in_closet": return "Closet · change your fit"
		"in_fridge": return "Fridge · eat something" + ((" · %ds" % int(ceil(main.story.cd_left("fridge")))) if main.story.cd_left("fridge") > 0 else "")
		"in_laptop": return "Laptop · save progress"
		"in_tv": return "Watch TV with mama · warm up"
		"in_exit_store": return "Leave the store"
		"in_register": return "Counter · coffee, warmers, first aid, ammo"
		"in_coffee": return "Coffee machine · $8"
	return null

func use(it):
	match it.id:
		"gunshop": enter("gunshop")
		"in_exit_studio", "in_exit_gunshop": leave()
		"in_booth":
			if main.story.cd_left("studio") > 0:
				main.hud.toast("Booth's busy. Come back in a bit.")
			else:
				main.studio.open_select()
		"in_desk": main.story.studio_menu()
		"in_couch":
			main.player.emote("sit", 6.0)
			G.S["warmth"] = min(100, float(G.S.get("warmth", 100)) + 25)
			main.hud.toast("Warm in here. Warmth +25")
		"in_counter": counter_menu()
		"in_bench": main.studio.open_bench()
		"in_exit_home", "in_exit_store": leave()
		"in_bed":
			if main.story.cd_left("laylow") > 0: main.hud.toast("You just slept. Not tired yet.")
			else: main.story.lay_low()
		"in_closet": main.wardrobe.open()
		"in_fridge":
			if main.story.cd_left("fridge") > 0:
				main.hud.toast("Nothing left but mustard.")
			else:
				main.story.set_cd("fridge", 90)
				G.S["health"] = min(100, float(G.S["health"]) + 25); G.S["warmth"] = min(100, float(G.S.get("warmth", 100)) + 10)
				main.hud.toast("Leftover greens from mama. Health +25")
		"in_laptop":
			G.save_game(); main.hud.toast("Saved.")
		"in_tv":
			main.player.emote("sit", 6.0)
			G.S["warmth"] = min(100, float(G.S.get("warmth", 100)) + 25)
			main.hud.toast("Some old movie. Mama's snoring. Warmth +25")
		"in_register": main.story.store_menu("store")
		"in_coffee":
			if G.S["cash"] < 8:
				main.hud.toast("Not enough cash.")
			else:
				main.story.add_cash(-8)
				G.S["warmth"] = min(100, float(G.S["warmth"]) + 35); G.S["buffs"]["coffee"] = 60
				main.sfx.play("tap", 0.4)
				main.hud.toast("Coffee. Black, still hot.")
	return true

func owns(it):
	return label(it) != null

func enter(id):
	if busy: return
	if main.story._blocked_inside(): return
	if id == "studio" and not G.S["flags"].get("studioCut", false):
		G.S["flags"]["studioCut"] = true
		main.cutscene.play(main.cutscene.cut_studio(), self, "_enter_studio")
		return
	busy = true
	main.hud.fade_to(1.0, 0.22)
	yield(get_tree().create_timer(0.26), "timeout")
	var R = ROOMS[id]
	var sp = R.o + R.spawn
	main.player.place(sp.x, sp.y, sp.z, 0.0)
	main.player.cam_pitch = -0.08
	inside = id
	main.sfx.play(R.sound, 0.45)
	main.hud.fade_to(0.0, 0.35)
	main.hud.banner(R.name, R.addr)
	busy = false

func _enter_studio(_a = null):
	enter("studio")

func leave():
	if busy or inside == "": return
	busy = true
	var R = ROOMS[inside]
	main.hud.fade_to(1.0, 0.22)
	yield(get_tree().create_timer(0.26), "timeout")
	var op = R.door + R.get("out", Vector3(0, 0, 1.2))
	main.player.place(op.x, 0, op.z, R.get("out_yaw", PI))
	main.player.cam_pitch = -0.05
	inside = ""
	main.sfx.play(R.sound, 0.4)
	main.hud.fade_to(0.0, 0.35)
	busy = false

func room_name():
	return ROOMS[inside].name if inside != "" else ""
func room_addr():
	return ROOMS[inside].addr if inside != "" else ""

# ---------------------------------------------------------------- the counter
func counter_menu(_a = null):
	var items = []
	for id in GUN.IDS:
		var Wp = G.D["WEAPONS"][id]
		if G.S["guns"][id].owned:
			var A = Wp.ammo
			items.append(_act(main.story._item("%s ammo" % Wp.short, "%d rounds for your %s." % [A.n, Wp.short], G.fmt_money(A.price), ""), "_shop_buy", ["ammo:" + id, A.price]))
		else:
			var can = G.S["cash"] >= Wp.price and G.S["buzz"] >= Wp.buzz
			var why = ("Buzz %d first" % Wp.buzz) if G.S["buzz"] < Wp.buzz else G.fmt_money(Wp.price)
			items.append(_act(main.story._item("Buy the %s" % Wp.short, "%s. Comes with a full mag." % Wp.cls, why, "", [], not can), "_buy_gun", id))
	# up close and thrown
	var ML = G.S.get("melee", {})
	if not ML.get("bat", false): items.append(_act(main.story._item("Bat", "Aluminum-handled wood. Swings slow, hits hard, knocks them down.", "$120", ""), "_shop_buy", ["bat", 120]))
	if not ML.get("knife", false): items.append(_act(main.story._item("Knife", "Quick and quiet. Takedowns from behind make no noise.", "$90", ""), "_shop_buy", ["knife", 90]))
	var nG = main.offense.count("grenade")
	var nM = main.offense.count("molly")
	items.append(_act(main.story._item("Grenade", "Hold to see the arc, let go to throw. You carry %d of 6." % nG, "$150", "", [], nG >= 6), "_shop_buy", ["grenade", 150]))
	items.append(_act(main.story._item("Fire bottle", "Breaks and burns the ground for a few seconds. You carry %d of 6." % nM, "$70", "", [], nM >= 6), "_shop_buy", ["molly", 70]))
	items.append(_act(main.story._item("Bandage", "Press B to heal 40 health.", "$25", ""), "_shop_buy", ["bandage", 25]))
	var wb = main.story._item("Workbench", "Parts, finishes and charms for what you own.", "", "")
	wb["act"] = funcref(main.studio, "open_bench")
	items.append(wb)
	items.append(main.story._leave())
	var lines = ["Everything here's legal and everything here's loud.", "Cash only. Don't make it weird.", "You want it or you just looking?", "Keep it pointed at the floor in my shop."]
	main.hud.menu(ROOMS.gunshop.addr, "Ironside Arms", 'Vic: "%s"' % G.pick(lines), items)
	main.sfx.play("shopbell", 0.3)

func _buy_gun(id):
	var Wp = G.D["WEAPONS"][id]
	if G.S["cash"] < Wp.price or G.S["buzz"] < Wp.buzz:
		main.hud.toast("Vic:  Not yet."); return
	main.story.add_cash(-Wp.price)
	G.S["guns"][id].owned = true; G.S["guns"][id].mag = Wp.mag
	main.player.switch_weapon(id)
	main.hud.banner(Wp.short, "Yours")
	G.save_game()
	counter_menu()

func _act(it, method, arg):
	it["act"] = funcref(self, method); it["arg"] = arg
	return it

func _shop_buy(a):
	var what = a[0]
	var price = a[1]
	if G.S["cash"] < price:
		main.hud.toast("Vic:  Cash first."); counter_menu(); return
	main.story.add_cash(-price)
	if what == "bandage":
		G.S["bandages"] = int(G.S.get("bandages", 0)) + 1; main.hud.toast("Bandage in your pocket.")
	elif what == "bat" or what == "knife":
		G.S["melee"][what] = true
		main.player.set_hold(what)
		main.hud.banner("Bat" if what == "bat" else "Knife", "Yours · on the weapon wheel")
		G.save_game()
	elif what == "grenade" or what == "molly":
		if main.offense.count(what) >= 6:
			main.story.add_cash(price); main.hud.toast("Vic:  You can't carry more."); counter_menu(); return
		G.S["throw"][what] = main.offense.count(what) + 1
		G.S["thr"] = what
		main.hud.toast("%s · %d on you. X to throw." % ["Grenade" if what == "grenade" else "Fire bottle", G.S["throw"][what]])
	elif what.begins_with("ammo:"):
		var id = what.substr(5)
		G.S["guns"][id].res += G.D["WEAPONS"][id].ammo.n; main.hud.toast("%d rounds for the %s." % [G.D["WEAPONS"][id].ammo.n, G.D["WEAPONS"][id].short])
	counter_menu()

# ---------------------------------------------------------------- every frame
func update(dt):
	var P = main.player
	# a save made inside, or a respawn outside: work out where we are from the height
	if inside == "" and P.pos.y > 200 and not busy:
		var bd = INF
		for k in ROOMS.keys():
			var dd = P.pos.distance_to(ROOMS[k].o)
			if dd < bd:
				bd = dd; inside = k
	elif inside != "" and P.pos.y < 200 and not busy:
		inside = ""
	main.fx.snow.visible = inside == ""
	if tv_mat and inside == "home":
		# the TV flickers through scenes
		var f = fmod(G.REAL_T * 0.7, 3.0)
		var tc = Color(0.35, 0.5, 0.85) if f < 1.0 else (Color(0.85, 0.55, 0.35) if f < 2.0 else Color(0.5, 0.75, 0.5))
		tv_mat.albedo_color = tc * (0.85 + 0.15 * sin(G.REAL_T * 23.0))
	if mama: mama.visible = inside == "home"
	if cashier:
		cashier.visible = inside == "store"
		if cashier.visible: cashier.animate(dt, { "speed": 0.0, "mug": true })
	if clerk:
		clerk.visible = inside == "gunshop"
		if clerk.visible:
			clerk_t += dt
			var want = atan2(P.pos.x - clerk.translation.x, P.pos.z - clerk.translation.z)
			clerk.rotation.y += G.ang_diff(clerk.rotation.y, want) * (1 - exp(-dt * 2.5))
			clerk.animate(dt, { "speed": 0.0, "mug": true })

# called after the day-night update: inside, the light is the room's own
func light_inside(env, sun):
	if inside == "": return
	sun.light_energy *= 0.12
	env.ambient_light_color = ROOMS[inside].amb
	env.ambient_light_energy = 0.6

func tags():
	if inside == "gunshop" and clerk:
		return [[clerk.translation, "Vic", "IRONSIDE ARMS", Color(0.9, 0.35, 0.3)]]
	if inside == "store" and cashier:
		return [[cashier.translation, "Ray", "CALDER MINI MART", Color(1, 0.62, 0.22)]]
	return []

# ---------------------------------------------------------------- Home, 6127 S Bishop St
func _build_home():
	_mb = MB.new(); _mats.clear()
	_o = ROOMS.home.o
	var w = 11.0
	var d = 10.0
	var h = 2.8
	_m("floor", Color(0.34, 0.23, 0.15)); _m("plank", Color(0.4, 0.27, 0.17)); _m("ceil", Color(0.74, 0.72, 0.68)); _m("wall", Color(0.55, 0.5, 0.4))
	_m("trim", Color(0.92, 0.9, 0.85), true); _m("wood", Color(0.36, 0.23, 0.14), true); _m("couch", Color(0.42, 0.24, 0.2), true); _m("blanket", Color(0.24, 0.36, 0.52), true)
	_m("white", Color(0.92, 0.92, 0.9), true); _m("black", Color(0.07, 0.07, 0.08), true); _m("steel", Color(0.62, 0.64, 0.66), true); _m("rug", Color(0.5, 0.18, 0.16))
	_m("glass", Color(0.7, 0.82, 0.95), false, true, 0.25); _m("lampw", Color(1, 0.9, 0.7), false, true); _m("sheet", Color(0.86, 0.86, 0.9), true); _m("bedcover", Color(0.32, 0.18, 0.4), true)
	_m("photo1", Color(0.75, 0.6, 0.45)); _m("photo2", Color(0.45, 0.55, 0.7)); _m("tv", Color(0.35, 0.5, 0.85), false, true); _m("tile", Color(0.82, 0.82, 0.78))
	_shell(w, d, h)
	tv_mat = _mats["tv"]
	# plank floor and baseboards
	for i in range(22):
		if i % 2 == 0: _b("plank", Vector3(-w / 2 + 0.25 + i * 0.5, 0.004, 0), Vector3(0.5, 0.008, d))
	for side in [[Vector3(0, 0.06, -d / 2 + 0.02), Vector3(w, 0.12, 0.03)], [Vector3(0, 0.06, d / 2 - 0.02), Vector3(w, 0.12, 0.03)], [Vector3(-w / 2 + 0.02, 0.06, 0), Vector3(0.03, 0.12, d)], [Vector3(w / 2 - 0.02, 0.06, 0), Vector3(0.03, 0.12, d)]]:
		_b("trim", side[0], side[1])
	# the bedroom walls: a partition with a doorway into the living room
	_b("wall", Vector3(-1.6, h / 2, -3.4), Vector3(0.12, h, 3.2), true)
	_b("wall", Vector3(-3.55, h / 2, -0.4), Vector3(3.9, h, 0.12), true)
	_b("trim", Vector3(-1.6, h - 0.15, -1.1), Vector3(0.14, 0.3, 1.4))
	# the bed, a nightstand with a lamp, the closet, a poster
	_b("wood", Vector3(-4.3, 0.22, -3.7), Vector3(1.6, 0.44, 2.2), true)
	_b("sheet", Vector3(-4.3, 0.5, -3.7), Vector3(1.5, 0.14, 2.1))
	_b("bedcover", Vector3(-4.3, 0.59, -3.35), Vector3(1.52, 0.06, 1.45))
	_b("sheet", Vector3(-4.3, 0.64, -4.55), Vector3(1.1, 0.14, 0.35))
	_b("wood", Vector3(-4.3, 0.7, -4.85), Vector3(1.6, 1.0, 0.08))
	_b("wood", Vector3(-2.95, 0.3, -4.6), Vector3(0.5, 0.6, 0.45), true)
	_b("lampw", Vector3(-2.95, 0.78, -4.6), Vector3(0.22, 0.26, 0.22))
	_b("wood", Vector3(-5.2, 1.0, -1.3), Vector3(0.55, 2.0, 1.4), true)
	_b("black", Vector3(-4.92, 1.0, -1.3), Vector3(0.02, 1.9, 0.02))
	_b("photo2", Vector3(-1.68, 1.6, -3.4), Vector3(0.02, 0.8, 0.6))
	# the kitchen: counters, sink, stove, fridge, upper cabinets, a table with a laptop
	_b("white", Vector3(-5.15, 0.45, 2.7), Vector3(0.65, 0.9, 3.4), true)
	_b("tile", Vector3(-5.15, 0.92, 2.7), Vector3(0.7, 0.04, 3.45))
	_b("steel", Vector3(-5.15, 0.93, 3.6), Vector3(0.45, 0.02, 0.6))
	_b("black", Vector3(-5.15, 0.93, 1.7), Vector3(0.55, 0.02, 0.6))
	for bz in [1.55, 1.85]:
		for bx in [-5.3, -5.0]:
			_b("steel", Vector3(bx, 0.95, bz), Vector3(0.14, 0.01, 0.14))
	_b("white", Vector3(-5.2, 1.85, 2.7), Vector3(0.45, 0.7, 3.4))
	_b("white", Vector3(-5.05, 0.95, 0.4), Vector3(0.8, 1.9, 0.75), true)
	_b("steel", Vector3(-4.63, 1.2, 0.65), Vector3(0.03, 0.5, 0.03))
	_b("wood", Vector3(-2.6, 0.74, 2.8), Vector3(1.2, 0.05, 0.85), true)
	for lx in [-3.1, -2.1]:
		for lz in [2.45, 3.15]:
			_b("wood", Vector3(lx, 0.36, lz), Vector3(0.05, 0.72, 0.05))
	for cz in [2.05, 3.55]:
		_b("wood", Vector3(-2.6, 0.45, cz), Vector3(0.42, 0.05, 0.42))
		_b("wood", Vector3(-2.6, 0.7, cz + (0.2 if cz > 3 else -0.2)), Vector3(0.42, 0.5, 0.04))
	_b("black", Vector3(-2.5, 0.78, 2.9), Vector3(0.36, 0.02, 0.25))
	_b("black", Vector3(-2.5, 0.9, 2.78), Vector3(0.36, 0.24, 0.02), false, Vector3(-0.25, 0, 0))
	_b("tv", Vector3(-2.5, 0.9, 2.79), Vector3(0.32, 0.2, 0.01), false, Vector3(-0.25, 0, 0))
	# the living room: rug, couch, coffee table, TV on a stand, windows with a radiator, photos
	_b("rug", Vector3(2.2, 0.01, -1.2), Vector3(3.2, 0.02, 2.6))
	_b("couch", Vector3(2.2, 0.22, 0.8), Vector3(2.8, 0.44, 0.9), true)
	_b("couch", Vector3(2.2, 0.62, 1.15), Vector3(2.8, 0.55, 0.22))
	for ax in [0.75, 3.65]:
		_b("couch", Vector3(ax, 0.5, 0.8), Vector3(0.22, 0.3, 0.9))
	_b("blanket", Vector3(2.9, 0.48, 0.75), Vector3(1.3, 0.08, 0.86))
	_b("wood", Vector3(2.2, 0.35, -0.8), Vector3(1.2, 0.05, 0.6), true)
	_b("white", Vector3(2.0, 0.42, -0.8), Vector3(0.1, 0.1, 0.1))
	_b("wood", Vector3(2.2, 0.3, -4.6), Vector3(1.8, 0.6, 0.5), true)
	_b("black", Vector3(2.2, 1.05, -4.7), Vector3(1.4, 0.82, 0.08))
	_b("tv", Vector3(2.2, 1.05, -4.655), Vector3(1.3, 0.72, 0.01))
	for wz in [-2.2, 1.8]:
		_b("glass", Vector3(w / 2 - 0.02, 1.55, wz), Vector3(0.03, 1.1, 1.3))
		_b("trim", Vector3(w / 2 - 0.05, 1.55, wz), Vector3(0.06, 1.2, 0.06))
		_b("trim", Vector3(w / 2 - 0.05, 2.12, wz), Vector3(0.08, 0.06, 1.42))
		_b("trim", Vector3(w / 2 - 0.05, 0.98, wz), Vector3(0.12, 0.06, 1.42))
		for ri in range(8):
			_b("white", Vector3(w / 2 - 0.15, 0.5, wz - 0.55 + ri * 0.155), Vector3(0.1, 0.6, 0.06))
	_b("photo1", Vector3(-1.52, 1.6, -2.2), Vector3(0.02, 0.4, 0.5))
	_b("photo2", Vector3(0.3, 1.7, -4.97), Vector3(0.5, 0.4, 0.02))
	_b("photo1", Vector3(4.3, 1.7, -4.97), Vector3(0.4, 0.5, 0.02))
	# the front door and a mat
	_b("wood", Vector3(3.8, 1.05, d / 2 - 0.03), Vector3(1.0, 2.1, 0.06))
	_b("steel", Vector3(3.45, 1.0, d / 2 - 0.08), Vector3(0.05, 0.05, 0.06))
	_b("rug", Vector3(3.8, 0.012, d / 2 - 0.7), Vector3(1.2, 0.02, 0.7))
	# ceiling lamps
	for lp in [Vector3(2.2, h - 0.03, -1.0), Vector3(-3.3, h - 0.03, 2.4), Vector3(-3.5, h - 0.03, -2.6)]:
		_b("lampw", lp, Vector3(0.5, 0.04, 0.5))
	_commit()
	_light(Vector3(2.2, 2.4, -0.8), Color(1, 0.8, 0.6), 0.62, 7.0)
	_light(Vector3(-3.3, 2.4, 2.4), Color(1, 0.86, 0.68), 0.55, 6.0)
	_light(Vector3(-3.4, 2.2, -2.8), Color(1, 0.74, 0.52), 0.45, 5.0)
	_light(Vector3(2.2, 1.0, -4.0), Color(0.5, 0.65, 1.0), 0.45, 4.0)
	# mama, asleep on the couch under the blanket
	mama = load("res://scripts/Human.gd").new().build(G.skin_opts({ "tone": 3, "hair": "braids", "hairCol": 0x2a1a12, "head": "none", "top": "hoodie", "topCol": 0x6a3a5a, "top2": 0x6a3a5a, "pants": "joggers", "pantsCol": 0x2a2a3a, "shoes": "sneaker", "shoesCol": 0xe8e8ea, "build": 1 }))
	main.add_child(mama)
	G.toon_tree(mama, true)
	mama.animate(0.016, { "speed": 0.0 })
	# lying on her side along the couch, facing the TV, head on the left arm
	mama.translation = _o + Vector3(3.35, 0.66, 0.75)
	mama.rotation = Vector3(0, PI, -PI / 2)
	if mama.shadow: mama.shadow.visible = false
	mama.visible = false

# ---------------------------------------------------------------- the Calder Mini Mart
func _build_store():
	_mb = MB.new(); _mats.clear()
	_o = ROOMS.store.o
	var w = 12.0
	var d = 10.0
	var h = 3.2
	_m("floor", Color(0.62, 0.62, 0.6)); _m("ceil", Color(0.76, 0.76, 0.74)); _m("wall", Color(0.66, 0.64, 0.57))
	_m("shelf", Color(0.85, 0.86, 0.88), true); _m("cool", Color(0.75, 0.9, 1.0), false, true); _m("glass", Color(0.8, 0.92, 1.0), false, true, 0.2)
	_m("counter", Color(0.62, 0.12, 0.1), true); _m("top", Color(0.2, 0.2, 0.22), true); _m("black", Color(0.06, 0.06, 0.07), true); _m("lamp", Color(1, 1, 0.97), false, true)
	_m("red", Color(0.9, 0.18, 0.14), false, true); _m("mat", Color(0.18, 0.2, 0.24)); _m("cup", Color(0.95, 0.95, 0.92), true)
	var cols = [Color(0.9, 0.25, 0.2), Color(1.0, 0.75, 0.15), Color(0.25, 0.55, 0.9), Color(0.3, 0.7, 0.35), Color(0.95, 0.5, 0.15), Color(0.6, 0.3, 0.7), Color(0.95, 0.95, 0.9), Color(0.15, 0.15, 0.18)]
	for i in range(cols.size()): _m("p%d" % i, cols[i], true)
	_shell(w, d, h)
	for lx in [-3.5, 0.0, 3.5]:
		for lz in [-2.5, 1.0]:
			_b("lamp", Vector3(lx, h - 0.03, lz), Vector3(1.4, 0.04, 0.3))
	# three double-sided aisles of products
	var R = RandomNumberGenerator.new(); R.seed = 808
	for ax in [-2.6, 0.2, 3.0]:
		_b("shelf", Vector3(ax, 0.8, -1.0), Vector3(0.9, 1.6, 4.4), true)
		for sy in [0.35, 0.8, 1.25]:
			_b("shelf", Vector3(ax, sy - 0.05, -1.0), Vector3(1.05, 0.04, 4.4))
			for side in [-1, 1]:
				var z = -3.0
				while z < 1.1:
					var ln = R.randf_range(0.16, 0.34)
					_b("p%d" % R.randi_range(0, cols.size() - 1), Vector3(ax + side * 0.46, sy + 0.1, z + ln / 2), Vector3(0.12, R.randf_range(0.14, 0.26), ln - 0.03))
					z += ln
	# the drinks coolers along the back wall, lit from inside, bottles on the shelves
	_b("shelf", Vector3(0, 1.1, -d / 2 + 0.4), Vector3(w - 1.0, 2.2, 0.75), true)
	_b("cool", Vector3(0, 1.1, -d / 2 + 0.78), Vector3(w - 1.2, 2.0, 0.02))
	for bx in range(22):
		for by in [0.5, 1.05, 1.6]:
			_b("p%d" % ((bx + int(by * 10)) % cols.size()), Vector3(-w / 2 + 0.8 + bx * 0.47, by, -d / 2 + 0.72), Vector3(0.12, 0.3, 0.08))
	_b("glass", Vector3(0, 1.1, -d / 2 + 0.82), Vector3(w - 1.1, 2.1, 0.03))
	for dx in range(7):
		_b("black", Vector3(-w / 2 + 0.6 + dx * 1.8, 1.1, -d / 2 + 0.84), Vector3(0.04, 2.1, 0.04))
	# the counter by the door, the register, the shelf behind it, a lottery stand
	_b("counter", Vector3(-3.8, 0.5, 2.6), Vector3(2.6, 1.0, 0.7), true)
	_b("top", Vector3(-3.8, 1.02, 2.6), Vector3(2.7, 0.04, 0.8))
	_b("black", Vector3(-4.2, 1.15, 2.55), Vector3(0.4, 0.22, 0.3))
	_b("cool", Vector3(-4.2, 1.2, 2.72), Vector3(0.3, 0.12, 0.01))
	_b("red", Vector3(-3.0, 1.2, 2.6), Vector3(0.5, 0.3, 0.2))
	_b("shelf", Vector3(-5.6, 1.4, 1.5), Vector3(0.5, 2.0, 2.6), true)
	for k in range(18):
		_b("p%d" % (k % cols.size()), Vector3(-5.4, 0.7 + (k / 6) * 0.45, 0.45 + (k % 6) * 0.38), Vector3(0.1, 0.2, 0.28))
	# the coffee station
	_b("top", Vector3(5.5, 0.5, 2.0), Vector3(0.8, 1.0, 1.6), true)
	_b("black", Vector3(5.6, 1.3, 1.7), Vector3(0.45, 0.6, 0.4))
	_b("red", Vector3(5.35, 1.45, 1.7), Vector3(0.02, 0.06, 0.06))
	for cz in [2.3, 2.45, 2.6]:
		_b("cup", Vector3(5.5, 1.08, cz), Vector3(0.08, 0.12, 0.08))
	# the door, windows, a mat
	_b("glass", Vector3(2.5, 1.1, d / 2 - 0.03), Vector3(1.4, 2.2, 0.04))
	_b("black", Vector3(2.5, 2.25, d / 2 - 0.03), Vector3(1.6, 0.1, 0.06))
	for wx in [-1.8, 5.0]:
		_b("glass", Vector3(wx, 1.4, d / 2 - 0.02), Vector3(2.2, 1.6, 0.03))
	_b("mat", Vector3(2.5, 0.012, d / 2 - 0.7), Vector3(1.6, 0.02, 1.0))
	_commit()
	_light(Vector3(-3.0, 2.9, 0.0), Color(1, 1, 0.95), 0.55, 9.0)
	_light(Vector3(3.0, 2.9, 0.0), Color(1, 1, 0.95), 0.55, 9.0)
	_light(Vector3(0, 2.0, -3.6), Color(0.7, 0.9, 1.0), 0.6, 5.0)
	# Ray at the register
	cashier = load("res://scripts/Human.gd").new().build(G.skin_opts({ "tone": 1, "hair": "short", "hairCol": 0x3a2a1a, "beard": 3, "head": "cap", "headCol": 0xc8202a, "top": "hoodie", "topCol": 0x1e2f4a, "top2": 0x1e2f4a, "pants": "jeans", "pantsCol": 0x262b33, "shoes": "sneaker", "shoesCol": 0x15171a, "build": 1 }))
	main.add_child(cashier)
	G.toon_tree(cashier, true)
	cashier.translation = _o + Vector3(-3.9, 0, 1.75)
	cashier.visible = false
