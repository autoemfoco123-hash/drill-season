extends Node
# Basement 808: the rhythm game (D F J K, or the controller) on beats recorded from the web
# game's music engine, and the workbench (parts, finishes, charms, new guns) with a turning
# 3D preview. Ported from 91_bench_rhythm.js.

var main
var layer
var root
var BEATS = []
var style = "chi"
# rhythm state
var RH = { "on": false, "ended": false }
var player
var canvas
var card = null
var clock0 = 0.0
# workbench
var bench = null
var bench_gun = "k9"
var bench_msg = ""
var bench_vp = null
var bench_model = null
var bench_rot = 0.6
const LANE_COL = [Color("#71c6ff"), Color("#ff9a3c"), Color("#f4c64e"), Color("#ff4b3a")]
const LANE_KEY = ["D", "F", "J", "K"]
const LANE_PAD = ["◀", "▶", "X", "B"]
const STYLE_NAME = { "chi": "Chicago", "uk": "UK", "ny": "NY" }

class RhythmView extends Control:
	var st
	func _draw():
		st._draw_rhythm(self)

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 6; add_child(layer)
	root = Control.new(); root.anchor_right = 1; root.anchor_bottom = 1; root.visible = false
	layer.add_child(root)
	canvas = RhythmView.new(); canvas.st = self; canvas.anchor_right = 1; canvas.anchor_bottom = 1
	canvas.connect("gui_input", self, "_canvas_input")
	root.add_child(canvas)
	player = AudioStreamPlayer.new(); player.bus = "Master"; add_child(player)
	var f = File.new()
	if f.open("res://assets/studio/beats.json", File.READ) == OK:
		BEATS = parse_json(f.get_as_text()); f.close()
	for a in ["rh_0", "rh_1", "rh_2", "rh_3"]:
		if not InputMap.has_action(a): InputMap.add_action(a)
	var keys = [[KEY_D, KEY_LEFT], [KEY_F, KEY_DOWN], [KEY_J, KEY_UP], [KEY_K, KEY_RIGHT]]
	var pads = [JOY_DPAD_LEFT, JOY_DPAD_RIGHT, JOY_XBOX_X, JOY_XBOX_B]
	for i in range(4):
		for k in keys[i]:
			var e = InputEventKey.new(); e.scancode = k; InputMap.action_add_event("rh_%d" % i, e)
		var p = InputEventJoypadButton.new(); p.button_index = pads[i]; InputMap.action_add_event("rh_%d" % i, p)

func close_all():
	if RH.get("on", false) or root.visible: _stop_music()
	RH = { "on": false, "ended": false }
	root.visible = false
	if card:
		card.queue_free()
		card = null
	if bench:
		bench.queue_free()
		bench = null
	if G.MODE == "studio" or G.MODE == "bench": G.MODE = "play"

# ---------- verse select ----------
func open_select():
	G.MODE = "studio"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.visible = true
	RH = { "on": false, "ended": false, "select": true }
	_show_select()

func _card(w = 560):
	if card: card.queue_free()
	card = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.06, 0.09, 0.95); sb.set_corner_radius_all(18)
	sb.content_margin_left = 26; sb.content_margin_right = 26; sb.content_margin_top = 20; sb.content_margin_bottom = 20
	card.add_stylebox_override("panel", sb)
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.margin_left = -w / 2; card.margin_right = w / 2; card.margin_top = -250; card.margin_bottom = 250
	root.add_child(card)
	var v = VBoxContainer.new(); card.add_child(v)
	return v

func _lbl(parent, text, font, col = Color(0.93, 0.96, 1)):
	var l = Label.new(); l.text = text; l.autowrap = true; l.add_font_override("font", font); l.add_color_override("font_color", col)
	parent.add_child(l); return l

func _btn(parent, text, method, args = [], disabled = false):
	var b = Button.new(); b.text = text; b.add_font_override("font", G.font_m); b.disabled = disabled; b.clip_text = true
	b.connect("pressed", self, method, args); parent.add_child(b); return b

func _show_select():
	var v = _card()
	_lbl(v, "BASEMENT 808 · THE BOOTH", G.font_s, Color(1, 0.7, 0.28))
	_lbl(v, "Pick the verse", G.font_l)
	_lbl(v, "The beat is %s's. Hit D F J K (or the arrows, or ◀ ▶ X B on a controller) as notes cross the line. Accuracy and verse decide Buzz, Heat and cash." % G.D["CAST"]["benny"].name, G.font_s, Color(0.66, 0.72, 0.78))
	var row = HBoxContainer.new(); v.add_child(row)
	for k in ["chi", "uk", "ny"]:
		var b = _btn(row, ("● " if style == k else "") + STYLE_NAME[k] + " drill", "_set_style", [k])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var first = null
	var i = 0
	for k in ["tribute", "wayout", "diss"]:
		i += 1
		var V = G.D["VERSES"][k]
		var desc = V.desc
		if k == "diss":
			desc = "Aimed at %s. Hard chart.%s" % [G.D["CAST"]["saint"].name, (" %s pays %s." % [G.D["CAST"]["vance"].name, G.fmt_money(main.story.vance_pay())]) if G.S["flags"].get("vanceOffer", false) else ""]
		var chips = []
		for c in V.chips: chips.append(c[1])
		var b2 = _btn(v, "%d   %s   · %s" % [i, V.name, PoolStringArray(chips).join("  ")], "start_rhythm", [k, { "style": style }])
		_lbl(v, "      " + desc, G.font_s, Color(0.66, 0.72, 0.78))
		if first == null: first = b2
	_btn(v, "Step out", "_abort")
	if first: first.grab_focus()

func _set_style(k):
	style = k; _show_select()

# ---------- the rhythm game ----------
func start_rhythm(type, opts = {}):
	G.MODE = "studio"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.visible = true
	if card:
		card.queue_free()
		card = null
	var st = opts.get("style", "chi")
	var pool = []
	for b in BEATS:
		if b.style == st: pool.append(b)
	if pool.size() == 0: pool = BEATS
	var beat = G.pick(pool)
	var notes = []
	for n in beat.charts[type]: notes.append({ "t": float(n[0]), "lane": int(n[1]), "hit": "" })
	var showcase = opts.get("showcase", false)
	RH = { "on": true, "ended": false, "select": false, "beat": beat, "notes": notes, "type": type, "opts": opts, "style": st,
		"title": ("Showcase · " + _gen_title("wayout")) if showcase else _gen_title(type),
		"combo": 0, "maxCombo": 0, "pts": 0.0, "counts": { "perfect": 0, "great": 0, "good": 0, "miss": 0 }, "flash": [0.0, 0.0, 0.0, 0.0], "judge": null, "judge_t": -9.0, "started": false }
	player.stream = load("res://assets/studio/" + beat.file + ".ogg")
	player.volume_db = linear2db(0.9 * float(G.S["settings"].get("music", 0.85)))
	clock0 = G.REAL_T + 1.6
	if showcase: main.sfx.cheer()

func _gen_title(type):
	var T = G.D["TITLE_WORDS"][type]
	var used = {}
	for t in G.S["tracks"]: used[t.title] = true
	for _i in range(20):
		var t = G.pick(T.fixed) if randf() < 0.6 else G.pick(T.a) + " " + G.pick(T.b)
		if randf() < 0.18: t += G.pick([" (Freestyle)", " Pt. 2", " (Calder Mix)", " (Intro)"])
		if not used.has(t): return t
	return G.pick(T.fixed) + " Pt. " + str(G.S["tracks"].size() + 2)

func rh_now():
	if RH.get("started", false) and player.playing:
		return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return G.REAL_T - clock0

func _hit(lane):
	if not RH.get("on", false) or RH.ended: return
	RH.flash[lane] = 1.0
	var t = rh_now()
	var best = null
	var bd = 0.17
	for n in RH.notes:
		if n.hit != "" or n.lane != lane: continue
		var d = abs(n.t - t)
		if d < bd:
			bd = d; best = n
		if n.t > t + 0.2: break
	if best == null: return
	var j = "perfect" if bd < 0.05 else ("great" if bd < 0.1 else "good")
	best.hit = j; RH.counts[j] += 1; RH.pts += 1.0 if j == "perfect" else (0.75 if j == "great" else 0.4)
	RH.combo += 1; RH.maxCombo = max(RH.maxCombo, RH.combo)
	RH.judge = j; RH.judge_t = G.REAL_T

func _input(e):
	if not root.visible: return
	if RH.get("on", false) and not RH.ended:
		for i in range(4):
			if e.is_action_pressed("rh_%d" % i) and not e.is_echo():
				_hit(i); get_tree().set_input_as_handled()
	if e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.scancode == KEY_ESCAPE):
		get_tree().set_input_as_handled()
		if bench: close_bench()
		elif RH.get("on", false) or RH.get("select", false): _abort()

func _canvas_input(e):
	if e is InputEventMouseButton and e.pressed and RH.get("on", false):
		var W = canvas.rect_size.x
		var lw = min(110.0, W * 0.2)
		var x0 = W / 2 - lw * 2
		var lane = int(floor((e.position.x - x0) / lw))
		if lane >= 0 and lane < 4: _hit(lane)

func update(dt):
	if not root.visible: return
	if bench and bench_model:
		bench_rot += dt * 0.45
		bench_model.rotation = Vector3(sin(G.REAL_T * 0.6) * 0.06, bench_rot + PI / 2, 0)
		if bench_model.has_node("Charm"): bench_model.get_node("Charm").rotation.z = sin(G.REAL_T * 3) * 0.3
	if RH.get("on", false) and not RH.ended:
		if not RH.started and G.REAL_T >= clock0:
			RH.started = true; player.play()
		var t = rh_now()
		for n in RH.notes:
			if n.hit == "" and n.t < t - 0.17:
				n.hit = "miss"; RH.counts.miss += 1; RH.combo = 0; RH.judge = "miss"; RH.judge_t = G.REAL_T
		if t > float(RH.beat.dur) + 0.5: _finish()
	for i in range(4):
		if RH.has("flash"): RH.flash[i] = max(0.0, RH.flash[i] - dt * 4.8)
	canvas.update()

func _draw_rhythm(c):
	var sz = c.rect_size
	var W = sz.x
	var H = sz.y
	var show = RH.has("opts") and RH.opts.get("showcase", false)
	c.draw_rect(Rect2(Vector2(), sz), Color(0.16, 0.13, 0.09) if show else Color(0.08, 0.06, 0.07))
	# foam panels
	for x in range(0, int(W), 60):
		for y in range(0, int(H * 0.7), 60):
			if (x / 60 + y / 60) % 2 == 0: c.draw_rect(Rect2(x, y, 58, 58), Color(0.16, 0.12, 0.15, 0.5))
	var t = rh_now() if (RH.get("on", false) or RH.get("ended", false)) and RH.has("beat") else 0.0
	var beat_ph = 0.0
	if RH.has("beat"): beat_ph = fposmod(t / (float(RH.beat.step) * 4.0), 1.0)
	var pulse = max(0.0, 1 - beat_ph * 3)
	c.draw_circle(Vector2(W - 40, 40), 9, Color(1, 0.16, 0.12, 0.5 + pulse * 0.5) if RH.get("on", false) else Color(0.25, 0.06, 0.06))
	c.draw_string(G.font_s, Vector2(W - 92, 46), "LIVE" if show else "REC", Color(1, 0.42, 0.35))
	if not RH.has("beat"): return
	var lw = min(110.0, W * 0.2)
	var x0 = W / 2 - lw * 2
	var hitY = H * 0.82
	var speed = H * 0.62
	for i in range(4):
		var x = x0 + i * lw
		c.draw_rect(Rect2(x, 0, lw, H), Color(0.86, 0.94, 1, 0.035 if i % 2 else 0.06))
		if RH.flash[i] > 0:
			var col = LANE_COL[i]; col.a = 0.45 * RH.flash[i]
			c.draw_rect(Rect2(x, hitY - 220, lw, 220), col)
	c.draw_rect(Rect2(x0, hitY - 2, lw * 4, 4), Color(1, 0.6, 0.24, 0.6 + pulse * 0.4))
	for i in range(4):
		var cx = x0 + i * lw + lw / 2
		var col2 = LANE_COL[i]; col2.a = 0.5 + RH.flash[i] * 0.5
		c.draw_arc(Vector2(cx, hitY), 24, 0, TAU, 32, col2, 2)
		var lab = LANE_KEY[i] + "  " + LANE_PAD[i]
		c.draw_string(G.font_m, Vector2(cx - G.font_m.get_string_size(lab).x / 2, hitY + 52), lab, Color(0.86, 0.94, 1))
	for n in RH.notes:
		var y = hitY - (n.t - t) * speed
		if y < -40 or y > H + 40: continue
		if n.hit != "" and n.hit != "miss": continue
		var x2 = x0 + n.lane * lw + lw * 0.12
		var w2 = lw * 0.76
		var nc = LANE_COL[n.lane]
		if n.hit == "miss": nc.a = 0.25
		c.draw_rect(Rect2(x2, y - 9, w2, 18), nc)
		c.draw_rect(Rect2(x2 + 6, y - 6, w2 - 12, 3), Color(1, 1, 1, 0.55 * nc.a))
	c.draw_string(G.font_xl, Vector2(26, 64), RH.title.to_upper(), Color(0.86, 0.94, 1))
	var verse = "SHOWCASE" if show else G.D["VERSES"][RH.type].name.to_upper() + " VERSE"
	c.draw_string(G.font_s, Vector2(26, 90), "%s · %s DRILL · %d BPM · %s" % [verse, STYLE_NAME[RH.style].to_upper(), int(RH.beat.bpm), G.D["CAST"]["benny"].name], Color(1, 0.6, 0.24))
	var judged = 0
	for n in RH.notes:
		if n.hit != "": judged += 1
	var acc = RH.pts / judged if judged > 0 else 1.0
	c.draw_string(G.font_l, Vector2(26, 132), "%d%%" % int(round(acc * 100)), Color(0.86, 0.94, 1))
	c.draw_string(G.font_s, Vector2(26, 156), "combo %d" % RH.combo, Color(0.64, 0.76, 0.86))
	var prog = clamp(t / float(RH.beat.dur), 0, 1)
	c.draw_rect(Rect2(0, H - 4, W, 4), Color(0.86, 0.94, 1, 0.15)); c.draw_rect(Rect2(0, H - 4, W * prog, 4), Color(1, 0.6, 0.24))
	if t < 0 and RH.on:
		var cd = str(int(ceil(-t)))
		c.draw_string(G.font_xl, Vector2(W / 2 - G.font_xl.get_string_size(cd).x / 2, H * 0.45), cd, Color(0.86, 0.94, 1))
	if RH.judge != null and G.REAL_T - RH.judge_t < 0.45:
		var k = (G.REAL_T - RH.judge_t) / 0.45
		var jc = { "perfect": Color("#f4c64e"), "great": Color("#86e3b0"), "good": Color("#71c6ff"), "miss": Color("#ff4b3a") }[RH.judge]
		jc.a = 1 - k
		var js = RH.judge.to_upper()
		c.draw_string(G.font_xl, Vector2(W / 2 - G.font_xl.get_string_size(js).x / 2, hitY - 90 - k * 20), js, jc)

func _grade(acc):
	return "S" if acc >= 0.92 else ("A" if acc >= 0.8 else ("B" if acc >= 0.65 else ("C" if acc >= 0.5 else "D")))

func _finish():
	RH.ended = true; RH.on = false
	var total = max(1, RH.notes.size())
	var acc = RH.pts / total
	var grade = _grade(acc)
	var q = pow(acc, 1.4)
	var type = RH.type
	var showcase = RH.opts.get("showcase", false)
	var buzz
	var heat
	var cash
	if type == "tribute":
		buzz = round(3 + 9 * q); heat = -4; cash = round(80 + 260 * q)
	elif type == "wayout":
		buzz = round(5 + 12 * q); heat = 0; cash = round(120 + 380 * q)
	else:
		buzz = round(9 + 16 * q); heat = round(16 + 8 * (1 - q * 0.4))
		cash = round(main.story.vance_pay() * (0.6 + 0.4 * q)) if G.S["flags"].get("vanceOffer", false) else round(200 + 300 * q)
	if showcase:
		buzz = round(buzz * 1.5); cash = round(cash * 2)
	RH.result = { "acc": acc, "grade": grade, "buzz": buzz, "heat": heat, "cash": cash }
	var comment = { "S": "That's the one. Don't touch it.", "A": "Hard. I'm mixing it tonight.", "B": "Solid. We can punch in the rough spots.", "C": "Eh. The beat carried you.", "D": "Were you even listening to the 808?" }[grade]
	var v = _card(600)
	_lbl(v, "REC CENTER SHOWCASE" if showcase else ("WAY OUT" if type == "wayout" else type.to_upper()) + " VERSE", G.font_s, Color(1, 0.7, 0.28))
	_lbl(v, grade + "   " + RH.title, G.font_xl)
	_lbl(v, "%d%% · best combo %d · %d/%d/%d/%d" % [int(round(acc * 100)), RH.maxCombo, RH.counts.perfect, RH.counts.great, RH.counts.good, RH.counts.miss], G.font_m, Color(0.64, 0.82, 0.96))
	var who = G.D["CAST"]["coach" if showcase else "benny"]
	var says = ("That is how you do it. That is your way out." if acc >= 0.6 else "Shake it off. Come back when you are ready.") if showcase else comment
	_lbl(v, who.name + ": " + says, G.font_m, Color(who.color))
	_lbl(v, "Buzz +%d    Heat %s%d    +%s" % [buzz, "+" if heat >= 0 else "", heat, G.fmt_money(cash)], G.font_m, Color(1, 0.8, 0.4))
	if showcase and acc >= 0.6: main.sfx.cheer()
	var b = _btn(v, ("Take a bow" if acc >= 0.6 else "Step off stage") if showcase else "Release it", "_release")
	b.grab_focus()

func _release():
	_stop_music()
	var r = RH.result
	var showcase = RH.opts.get("showcase", false)
	var type = RH.type
	main.story.add_buzz(r.buzz * main.gang.producer_boost()); main.story.add_heat(r.heat); main.story.add_cash(r.cash)
	var tr = { "title": RH.title, "type": "wayout" if showcase else type, "acc": r.acc, "grade": r.grade, "at": OS.get_unix_time() * 1000, "seed": RH.beat.seed, "style": RH.style }
	G.S["tracks"].append(tr)
	if G.S["tracks"].size() > 60: G.S["tracks"].pop_front()
	G.S["stats"]["tracks"] = int(G.S["stats"].get("tracks", 0)) + 1
	var best = G.S["stats"].get("best")
	if typeof(best) != TYPE_DICTIONARY or r.acc > float(best.acc): G.S["stats"]["best"] = { "title": tr.title, "grade": r.grade, "acc": r.acc }
	if type == "diss" and not showcase:
		G.S["stats"]["disses"] = int(G.S["stats"].get("disses", 0)) + 1
		if G.S["flags"].get("vanceOffer", false): main.story.later(4, main.story, "send_msg", ["vance", "Now that's content. %s sent. Next one pays more." % G.fmt_money(r.cash)])
	if not showcase: main.story.set_cd("studio", 45)
	main.story.on_track_released(tr)
	main.blok.add_post("track", "new %s drill out now: “%s” (%s)" % [STYLE_NAME[RH.style], tr.title, r.grade], null)
	RH = { "on": false, "ended": false }
	root.visible = false
	if card:
		card.queue_free()
		card = null
	G.MODE = "play"
	G.save_game()
	if showcase and r.acc >= 0.6:
		G.S["flags"]["showcaseDone"] = true
		main.story.trigger_ending("wayout"); return
	if not showcase: main.story.studio_menu()

func _stop_music():
	if player.playing: player.stop()

func _abort():
	var showcase = RH.has("opts") and RH.opts.get("showcase", false)
	_stop_music()
	RH = { "on": false, "ended": false }
	root.visible = false
	if card:
		card.queue_free()
		card = null
	G.MODE = "play"
	if not showcase: main.story.studio_menu()

# ---------- the workbench ----------
func open_bench():
	G.MODE = "bench"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	root.visible = true
	RH = { "on": false, "ended": false }
	bench_gun = G.S["cur"]; bench_msg = ""
	_render_bench()

func close_bench():
	if bench:
		bench.queue_free()
		bench = null
	bench_model = null
	root.visible = false
	G.MODE = "play"
	main.story.studio_menu()

func _owns(gid, cat, id):
	if cat == "finish" or cat == "charm": return (cat + ":" + id) in G.S["cos"]
	return (cat + ":" + id) in G.S["parts"][gid]

func _render_bench():
	if bench: bench.queue_free()
	bench_model = null
	bench = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.045, 0.055, 0.08, 0.97); sb.set_corner_radius_all(18)
	sb.content_margin_left = 22; sb.content_margin_right = 22; sb.content_margin_top = 16; sb.content_margin_bottom = 16
	bench.add_stylebox_override("panel", sb)
	bench.anchor_right = 1; bench.anchor_bottom = 1; bench.margin_left = 40; bench.margin_right = -40; bench.margin_top = 30; bench.margin_bottom = -30
	root.add_child(bench)
	var hb = HBoxContainer.new(); bench.add_child(hb)
	# left: preview and stats
	var left = VBoxContainer.new(); left.rect_min_size = Vector2(430, 0); hb.add_child(left)
	var gid = bench_gun
	var Wp = G.D["WEAPONS"][gid]
	var Gs = G.S["guns"][gid]
	_lbl(left, "BASEMENT 808 · WORKBENCH", G.font_s, Color(1, 0.7, 0.28))
	_lbl(left, Wp.name, G.font_l)
	_lbl(left, Wp.cls + "   ·   " + G.fmt_money(G.S["cash"]) + " · Buzz " + str(int(G.S["buzz"])), G.font_s, Color(0.66, 0.72, 0.78))
	var vc = ViewportContainer.new(); vc.stretch = true; vc.rect_min_size = Vector2(420, 230); left.add_child(vc)
	bench_vp = Viewport.new(); bench_vp.size = Vector2(420, 230); bench_vp.own_world = true; bench_vp.transparent_bg = true; bench_vp.msaa = Viewport.MSAA_DISABLED
	vc.add_child(bench_vp)
	var cam = Camera.new(); cam.fov = 30; cam.translation = Vector3(0, 0.14, 1.25); bench_vp.add_child(cam); cam.look_at(Vector3(0, 0.02, 0), Vector3.UP); cam.current = true
	for L in [[Vector3(1, 1.2, 1), Color(1, 0.75, 0.55), 1.6], [Vector3(-0.4, 0.3, 1.5), Color(0.87, 0.91, 1), 0.9], [Vector3(-1.2, 0.6, -1), Color(0.48, 0.75, 1), 1.0]]:
		var dl = DirectionalLight.new(); dl.light_color = L[1]; dl.light_energy = L[2]; bench_vp.add_child(dl)
		dl.look_at_from_position(L[0], Vector3(), Vector3.UP)
	var env = Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR; env.ambient_light_color = Color(0.6, 0.66, 0.78); env.ambient_light_energy = 0.8
	var we = WorldEnvironment.new(); we.environment = env; bench_vp.add_child(we)
	var gun = GUN.build(gid, GUN.cfg_of(gid))
	var holder = Spatial.new()
	var aabb = _aabb(gun)
	gun.translation = -aabb.position - aabb.size / 2
	holder.add_child(gun)
	holder.scale = Vector3.ONE * (0.62 / max(aabb.size.x, max(aabb.size.y, aabb.size.z)))
	bench_vp.add_child(holder)
	bench_model = holder
	var st = GUN.stats(gid)
	var base = GUN.stats(gid, GUN.def_cfg())
	var rows = [["Damage", float(st.dmg) * float(st.pellets), float(base.dmg) * float(base.pellets), 110.0, "%d"], ["Accuracy", 10.0 / float(st.aimSpread), 10.0 / float(base.aimSpread), 25.0, "acc"],
		["Range", float(st.range), float(base.range), 70.0, "%dm"], ["Mag", float(st.mag), float(base.mag), 50.0, "%d"], ["Reload", 1.0 / float(st.reload), 1.0 / float(base.reload), 1.2, "rel"],
		["Control", 1.0 / float(st.recoil), 1.0 / float(base.recoil), 2.2, "ctl"], ["Zoom", float(st.zoom), float(base.zoom), 2.2, "%.2fx"], ["Heat/shot", float(st.heatPerShot), float(base.heatPerShot), 2.2, "%.2f"]]
	for r in rows:
		var h = HBoxContainer.new(); left.add_child(h)
		var n = Label.new(); n.text = r[0]; n.rect_min_size = Vector2(90, 0); n.add_font_override("font", G.font_s); h.add_child(n)
		var bar = ProgressBar.new(); bar.percent_visible = false; bar.max_value = 100; bar.value = clamp(r[1] / r[3] * 100, 3, 100); bar.rect_min_size = Vector2(230, 14); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var better = r[1] < r[2] - 1e-6 if r[0] == "Heat/shot" else r[1] > r[2] + 1e-6
		var worse = r[1] > r[2] + 1e-6 if r[0] == "Heat/shot" else r[1] < r[2] - 1e-6
		var fg = StyleBoxFlat.new(); fg.bg_color = Color(0.48, 0.88, 0.65) if better else (Color(1, 0.45, 0.4) if worse else Color(0.86, 0.94, 1))
		bar.add_stylebox_override("fg", fg)
		h.add_child(bar)
		var val = r[1]
		var txt = ""
		match r[4]:
			"acc": txt = str(int(round(val * 4)))
			"rel": txt = "%.1fs" % (1.0 / val)
			"ctl": txt = str(int(round(val * 45)))
			_: txt = r[4] % (int(round(val)) if r[4] in ["%d", "%dm"] else val)
		var vl = Label.new(); vl.text = txt; vl.add_font_override("font", G.font_s); h.add_child(vl)
	_lbl(left, bench_msg, G.font_m, Color(0.48, 0.88, 0.65))
	# right: guns and parts
	var sc = ScrollContainer.new(); sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.scroll_horizontal_enabled = false
	hb.add_child(sc)
	var right = VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(right)
	var tabs = HBoxContainer.new(); right.add_child(tabs)
	var first = null
	for id in ["k9", "draft", "plow"]:
		var o = G.S["guns"][id]
		var sub = ("equipped" if G.S["cur"] == id else "owned") if o.owned else "%s · Buzz %d" % [G.fmt_money(G.D["WEAPONS"][id].price), G.D["WEAPONS"][id].buzz]
		var b = _btn(tabs, ("● " if id == gid else "") + G.D["WEAPONS"][id].short + " (" + sub + ")", "_bench_tab", [id])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == gid: first = b
	if not Gs.owned:
		var can = G.S["cash"] >= Wp.price and G.S["buzz"] >= Wp.buzz
		_lbl(right, "LOCKED", G.font_s, Color(1, 0.7, 0.28))
		_lbl(right, "%s. Unlocks with %s and Buzz %d." % [Wp.cls, G.fmt_money(Wp.price), Wp.buzz], G.font_m)
		_btn(right, "Unlock " + Wp.short, "_bench_buy", [], not can)
	else:
		for cat in [["optic", "Optic"], ["barrel", "Barrel"], ["mag", "Mag"], ["muzzle", "Muzzle"], ["finish", "Finish"], ["charm", "Charm"]]:
			_lbl(right, cat[1].to_upper(), G.font_s, Color(1, 0.7, 0.28))
			var grid = GridContainer.new(); grid.columns = 3; right.add_child(grid)
			for p in G.D["PARTS"][cat[0]]:
				var own = _owns(gid, cat[0], p.id)
				var on = GUN.cfg_of(gid).get(cat[0]) == p.id
				var lockb = p.has("buzz") and G.S["buzz"] < p.buzz
				var tag = "equipped" if on else ("owned" if own else ("Buzz %d" % p.buzz if lockb else G.fmt_money(p.price)))
				var b2 = _btn(grid, ("● " if on else "") + p.name + " · " + tag, "_bench_part", [cat[0], p.id], not own and (lockb or G.S["cash"] < p.price))
				b2.rect_min_size = Vector2(200, 0)
				if cat[0] == "finish": b2.add_color_override("font_color", G.hex_color(p.c).lightened(0.2))
				if p.has("note"): b2.hint_tooltip = p.note
		if G.S["cur"] != gid: _btn(right, "Equip " + Wp.short, "_bench_equip")
	var close = _btn(right, "Close the bench", "close_bench")
	if first: first.grab_focus()
	else: close.grab_focus()

func _aabb(n):
	var a = null
	for c in n.get_children():
		if c is MeshInstance:
			var b = c.get_transformed_aabb() if c.is_inside_tree() else c.transform.xform(c.mesh.get_aabb())
			a = b if a == null else a.merge(b)
	return a if a != null else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))

func _bench_tab(id):
	bench_gun = id; bench_msg = ""; _render_bench()

func _bench_buy():
	var gid = bench_gun
	var Wp = G.D["WEAPONS"][gid]
	if G.S["cash"] >= Wp.price and G.S["buzz"] >= Wp.buzz:
		main.story.add_cash(-Wp.price); G.S["guns"][gid].owned = true; G.S["guns"][gid].mag = Wp.mag
		main.player.switch_weapon(gid); bench_msg = Wp.short + " unlocked and equipped."; G.save_game()
	_render_bench()

func _bench_part(cat, id):
	var gid = bench_gun
	var p = GUN.part_of(cat, id)
	if not _owns(gid, cat, id):
		if p.has("buzz") and G.S["buzz"] < p.buzz:
			bench_msg = "Needs Buzz %d." % p.buzz; _render_bench(); return
		if G.S["cash"] < p.price:
			bench_msg = "Not enough cash."; _render_bench(); return
		main.story.add_cash(-p.price)
		if cat == "finish" or cat == "charm": G.S["cos"].append(cat + ":" + id)
		else: G.S["parts"][gid].append(cat + ":" + id)
	var g = G.S["guns"][gid]
	if typeof(g.get("cfg")) != TYPE_DICTIONARY: g["cfg"] = GUN.def_cfg()
	g.cfg[cat] = id
	if cat == "mag":
		var st = GUN.stats(gid)
		g.res += max(0, g.mag - st.mag); g.mag = min(g.mag, st.mag)
	if gid == G.S["cur"]: main.player._refresh_gun()
	bench_msg = "%s on the %s." % [p.name, G.D["WEAPONS"][gid].short]
	main.sfx.play("reload", 0.5)
	_render_bench()

func _bench_equip():
	main.player.switch_weapon(bench_gun); _render_bench()
