extends Node
# The eras of drill on Calder's corners: eight original characters, one for each era from 2012
# to today, each dressed in that era's look (the same looks as the Eras section of the
# wardrobe). They hang out by the studio, the Mini Mart, the pond, the L stairs, the courts,
# the rec center, the pavilion and Bishop St. Walk up and they talk about their time; pull a
# gun on them and their hands go up. The people and names are made up (named after the
# neighbourhood's own streets and places).

var main
var CREW = []

# [era, name, place, offset from it, the idle they do, what they say]
const PEOPLE = [
	[0, "Lowend Quan", "studio", Vector3(3.5, 0, 1.4), "hype", ["I was on this corner before the snow got famous.", "Back then a video was a cracked phone and a stairwell.", "The booth downstairs? I wore that carpet out."]],
	[1, "Ironside Moe", "store", Vector3(-3.4, 0, 1.2), "", ["Leather in January. You learn to suffer for the look.", "Everybody wanted a bucket hat that year. Nobody knew why.", "Grab a coffee. The cold up here is personal."]],
	[2, "Snowday Tay", "park", Vector3(4.5, 0, -4.0), "dance2", ["Goggles on, wind chill minus twenty. That was the uniform.", "We used to film by the pond when it froze over.", "Ski pants, no skiing. Calder style."]],
	[3, "Shoreline Dre", "stairs", Vector3(-3.0, 0, 2.5), "", ["Came up from somewhere warm. Still not used to this.", "Freeform locs and a tracksuit, all year round.", "Take the L to the lake one night. Trust me."]],
	[4, "Garnet Kiki", "court", Vector3(4.0, 0, -3.0), "clap", ["Jersey over the hoodie. That's how we knew who ran the court.", "Durag under everything. Keep the waves right.", "You hoop? Nah? Then you write."]],
	[5, "Sable Bink", "rec", Vector3(3.0, 0, -3.5), "laugh", ["You see the gold before you hear the voice.", "Shearling coat, fur collar. My grandma's closet, my rules.", "Coach Rec put me on a stage when nobody else would."]],
	[6, "Pavilion Nia", "pavilion", Vector3(4.0, 0, 3.0), "dance1", ["Headphones on, world off. Everybody's a producer now.", "Made a whole tape on a laptop with one working key.", "Post it, then post it again. Nobody sees it the first time."]],
	[7, "Bishop Zay", "home", Vector3(4.5, 0, 2.0), "", ["New year, same block. Make your name, then make it last.", "Every era thinks it invented the cold.", "Stay out of trouble. Trouble's got a long memory here."]],
]
const ERA_COL = [Color(1, 0.36, 0.3), Color(0.8, 0.6, 0.4), Color(0.65, 0.85, 1), Color(0.35, 0.65, 1), Color(1, 0.8, 0.25), Color(0.85, 0.7, 0.45), Color(0.45, 0.85, 0.5), Color(0.85, 0.6, 1)]

func setup(m):
	main = m

func build():
	if CREW.size() > 0: return
	var L = G.D["LOC"]
	var E = G.D["SKIN"]["ERAS"]
	for p in PEOPLE:
		var loc = L.get(p[2])
		if loc == null: continue
		var at = _free_spot(Vector3(loc.x, 0, loc.z) + p[3])
		var sk = G.era_skin(p[0])
		sk["tone"] = [5, 3, 2, 4, 1, 5, 0, 3][p[0]]
		var h = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
		main.add_child(h)
		G.toon_tree(h, true)
		h.translation = at
		var yaw = atan2(loc.x - at.x, loc.z - at.z) + PI * 0.5
		h.rotation.y = yaw
		# a slim box so you can't walk through them (and bullets stop at them)
		var col = W.add_box(at.x - 0.25, 0, at.z - 0.25, at.x + 0.25, 1.75, at.z + 0.25, "npc")
		CREW.append({ "h": h, "pos": at, "yaw": yaw, "name": p[1], "era": E[p[0]][0], "col": ERA_COL[p[0]], "idle": p[4], "lines": p[5],
			"line_i": 0, "line_t": 0.0, "et": 0.0, "hands": 0.0, "box": col })

# the nearest spot on the pavement that isn't inside a building
func _free_spot(at):
	if not W.is_blocked(at.x, at.z, 0.45): return at
	for r in [1.0, 2.0, 3.0, 4.0, 5.5]:
		for k in range(12):
			var a = k * TAU / 12.0
			var q = at + Vector3(cos(a), 0, sin(a)) * r
			if not W.is_blocked(q.x, q.z, 0.45): return q
	return at

func update(dt):
	if CREW.empty(): return
	var P = main.player
	var armed = not G.S.get("fists", false) and P.aiming
	for c in CREW:
		var d = Vector2(c.pos.x - P.pos.x, c.pos.z - P.pos.z).length()
		c.h.visible = d < 95
		if not c.h.visible: continue
		c.et += dt
		c.line_t -= dt
		# guns out: hands up
		if armed and d < 12:
			c.hands = 2.0
		c.hands = max(0, c.hands - dt)
		var want = c.yaw
		if d < 9:
			want = atan2(P.pos.x - c.pos.x, P.pos.z - c.pos.z)
		c.h.rotation.y += G.ang_diff(c.h.rotation.y, want) * (1 - exp(-dt * 3))
		if d < 5 and c.line_t <= 0 and G.MODE == "play" and not P.car:
			c.line_t = 40.0
			main.hud.say(c.name, c.lines[c.line_i % c.lines.size()])
			c.line_i += 1
		var em = ""
		if c.hands <= 0 and c.idle != "" and fmod(c.et, 12.0) < 6.0 and d > 3.5:
			em = c.idle
		c.h.animate(dt, { "speed": 0.0, "hands": c.hands > 0, "emote": em, "et": fmod(c.et, 12.0), "mug": em == "" and d < 9 })

# for the name tags over their heads
func tags():
	var out = []
	for c in CREW:
		if c.h.visible: out.append([c.pos, c.name, "ERA '" + str(c.era).substr(2, 2), c.col])
	return out
