extends Node
# Collision world (autoload "W"), ported from the web game: axis-aligned boxes in a
# uniform grid, ray casts, ground height and the body mover everyone uses.

const CELL = 12.0
var BOXES = []
var GRID = {}
var DYN = []          # moving boxes (cars, the train)
var qstamp = 0
var STEP_UP = 0.7
var GRAV = 22.0
var BOUND = 247.0

func _gkey(cx, cz):
	return (cx + 200) * 1000 + (cz + 200)

func setup(D):
	STEP_UP = float(D.get("STEP_UP", 0.7))
	GRAV = float(D.get("GRAV", 22))
	BOUND = float(D.get("MAP_HALF", 250)) - 3.0
	BOXES.clear(); GRID.clear()
	for b in D["BOXES"]:
		add_box(b[0], b[1], b[2], b[3], b[4], b[5], b[6])

func add_box(x0, y0, z0, x1, y1, z1, tag = "solid"):
	var b = { "x0": min(x0, x1), "y0": min(y0, y1), "z0": min(z0, z1), "x1": max(x0, x1), "y1": max(y0, y1), "z1": max(z0, z1), "tag": tag if tag != "" else "solid", "q": 0, "on": true }
	BOXES.append(b)
	for cx in range(int(floor(b.x0 / CELL)), int(floor(b.x1 / CELL)) + 1):
		for cz in range(int(floor(b.z0 / CELL)), int(floor(b.z1 / CELL)) + 1):
			var k = _gkey(cx, cz)
			if not GRID.has(k):
				GRID[k] = []
			GRID[k].append(b)
	return b

func query(x0, z0, x1, z1):
	qstamp += 1
	var out = []
	for cx in range(int(floor(x0 / CELL)), int(floor(x1 / CELL)) + 1):
		for cz in range(int(floor(z0 / CELL)), int(floor(z1 / CELL)) + 1):
			var c = GRID.get(_gkey(cx, cz))
			if c == null:
				continue
			for b in c:
				if b.q != qstamp:
					b.q = qstamp
					out.append(b)
	return out

func _ray_box(o, inv, b):
	var t1 = (b.x0 - o.x) * inv.x
	var t2 = (b.x1 - o.x) * inv.x
	var tmin = min(t1, t2)
	var tmax = max(t1, t2)
	t1 = (b.y0 - o.y) * inv.y; t2 = (b.y1 - o.y) * inv.y
	tmin = max(tmin, min(t1, t2)); tmax = min(tmax, max(t1, t2))
	t1 = (b.z0 - o.z) * inv.z; t2 = (b.z1 - o.z) * inv.z
	tmin = max(tmin, min(t1, t2)); tmax = min(tmax, max(t1, t2))
	if tmax >= max(tmin, 0.0):
		return tmin if tmin > 0 else 0.0
	return INF

# distance to the first solid hit, INF when nothing within max_t
func raycast(o, d, max_t, ignore_low = 0.0):
	var inv = Vector3(1.0 / (d.x if abs(d.x) > 1e-9 else 1e-9), 1.0 / (d.y if abs(d.y) > 1e-9 else 1e-9), 1.0 / (d.z if abs(d.z) > 1e-9 else 1e-9))
	var e = o + d * max_t
	var best = max_t
	for b in query(min(o.x, e.x), min(o.z, e.z), max(o.x, e.x), max(o.z, e.z)):
		if ignore_low > 0 and b.y1 < ignore_low:
			continue
		var t = _ray_box(o, inv, b)
		if t < best:
			best = t
	for b in DYN:
		if not b.on:
			continue
		var t = _ray_box(o, inv, b)
		if t < best:
			best = t
	if d.y < 0:
		var tg = -o.y / d.y
		if tg >= 0 and tg < best:
			best = tg
	return best if best < max_t else INF

func seg_clear(a, b):
	var dv = b - a
	var L = dv.length()
	if L < 0.01:
		return true
	return raycast(a, dv / L, L - 0.05) == INF

func ground_at(x, z, y):
	var g = 0.0
	for b in query(x - 0.05, z - 0.05, x + 0.05, z + 0.05):
		if x >= b.x0 and x <= b.x1 and z >= b.z0 and z <= b.z1 and b.y1 <= y + STEP_UP and b.y1 > g:
			g = b.y1
	for b in DYN:
		if b.on and x >= b.x0 and x <= b.x1 and z >= b.z0 and z <= b.z1 and b.y1 <= y + STEP_UP and b.y1 > g:
			g = b.y1
	return g

func is_blocked(x, z, m = 0.5):
	for b in query(x - m, z - m, x + m, z + m):
		if b.y0 < 1.8 and b.y1 > 0.3 and x > b.x0 - m and x < b.x1 + m and z > b.z0 - m and z < b.z1 + m:
			return true
	return false

func _push_out(body, b):
	var r = body.radius
	var px = body.pos.x
	var pz = body.pos.z
	var cx = clamp(px, b.x0, b.x1)
	var cz = clamp(pz, b.z0, b.z1)
	var ddx = px - cx
	var ddz = pz - cz
	var d2 = ddx * ddx + ddz * ddz
	if d2 >= r * r:
		return false
	if d2 > 1e-8:
		var d = sqrt(d2)
		var k = (r - d) / d
		body.pos.x += ddx * k; body.pos.z += ddz * k
	else:
		var l = px - b.x0
		var rr = b.x1 - px
		var t = pz - b.z0
		var bb = b.z1 - pz
		var m = min(min(l, rr), min(t, bb))
		if m == l: body.pos.x = b.x0 - r
		elif m == rr: body.pos.x = b.x1 + r
		elif m == t: body.pos.z = b.z0 - r
		else: body.pos.z = b.z1 + r
	return true

# body: an object with pos, vel (Vector3), radius, height, on_ground, air_y
func move_body(body, dx, dz, dt):
	var steps = max(1, int(ceil(Vector2(dx, dz).length() / 0.3)))
	var hit_wall = false
	for _s in range(steps):
		body.pos.x += dx / steps; body.pos.z += dz / steps
		var r = body.radius + 0.05
		for b in query(body.pos.x - r, body.pos.z - r, body.pos.x + r, body.pos.z + r):
			if b.y1 <= body.pos.y + STEP_UP or b.y0 >= body.pos.y + body.height:
				continue
			if _push_out(body, b):
				hit_wall = true
		for b in DYN:
			if not b.on or b.y1 <= body.pos.y + STEP_UP or b.y0 >= body.pos.y + body.height:
				continue
			if _push_out(body, b):
				hit_wall = true
	body.pos.x = clamp(body.pos.x, -BOUND, BOUND); body.pos.z = clamp(body.pos.z, -BOUND, BOUND)
	var was_ground = body.on_ground
	body.vel.y -= GRAV * dt
	body.pos.y += body.vel.y * dt
	var g = ground_at(body.pos.x, body.pos.z, body.pos.y - body.vel.y * dt)
	var landed = 0.0
	if body.pos.y <= g or (was_ground and body.vel.y <= 0 and body.pos.y - g < 0.75):
		if not was_ground:
			landed = body.air_y - g
		body.pos.y = g; body.vel.y = 0; body.on_ground = true; body.air_y = g
	else:
		if was_ground:
			body.air_y = body.pos.y
		body.air_y = max(body.air_y, body.pos.y)
		body.on_ground = false
	return { "hit_wall": hit_wall, "landed": landed }

# a body standing on the ground at x, z (for spawning)
class Body:
	var pos = Vector3()
	var vel = Vector3()
	var radius = 0.34
	var height = 1.75
	var on_ground = true
	var air_y = 0.0

# pushes a point (radius r) out of any box it sank into, by the shortest way; for ragdolls
# and thrown things. Returns [new position, touched something]
func collide_point(p, r):
	var touched = false
	if p.y < r:
		p.y = r; touched = true
	var cand = query(p.x - r, p.z - r, p.x + r, p.z + r)
	for b in DYN:
		if b.on: cand.append(b)
	for b in cand:
		if p.x < b.x0 - r or p.x > b.x1 + r or p.z < b.z0 - r or p.z > b.z1 + r or p.y < b.y0 - r or p.y > b.y1 + r:
			continue
		var pen = [p.x - (b.x0 - r), (b.x1 + r) - p.x, p.y - (b.y0 - r), (b.y1 + r) - p.y, p.z - (b.z0 - r), (b.z1 + r) - p.z]
		var m = 0
		for i in range(1, 6):
			if pen[i] < pen[m]: m = i
		if m == 0: p.x = b.x0 - r
		elif m == 1: p.x = b.x1 + r
		elif m == 2: p.y = b.y0 - r
		elif m == 3: p.y = b.y1 + r
		elif m == 4: p.z = b.z0 - r
		else: p.z = b.z1 + r
		touched = true
	return [p, touched]
