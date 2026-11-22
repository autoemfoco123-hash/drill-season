extends Node
# In-engine cutscenes like the web game's (78_cutscenes.js): letterboxed camera moves with a
# title card and subtitles. Space, Enter or a controller's A skips.

var main
var on = false
var shots = []
var i = -1
var t = 0.0
var end_obj = null
var end_m = ""
var end_args = []
var layer
var bar_top
var bar_bot
var title_l
var sub_l
var hint
var cur = null

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 8; add_child(layer)
	bar_top = ColorRect.new(); bar_top.color = Color(0, 0, 0); bar_top.anchor_right = 1; bar_top.margin_bottom = 0
	bar_bot = ColorRect.new(); bar_bot.color = Color(0, 0, 0); bar_bot.anchor_right = 1; bar_bot.anchor_top = 1; bar_bot.anchor_bottom = 1
	for b in [bar_top, bar_bot]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(b)
	title_l = Label.new(); title_l.add_font_override("font", G.font_xl); title_l.add_color_override("font_color", Color(1, 0.7, 0.28))
	title_l.anchor_top = 1; title_l.anchor_bottom = 1; title_l.margin_left = 48; title_l.margin_top = -190
	sub_l = Label.new(); sub_l.add_font_override("font", G.font_m); sub_l.add_color_override("font_color", Color(0.86, 0.92, 1))
	sub_l.anchor_top = 1; sub_l.anchor_bottom = 1; sub_l.margin_left = 52; sub_l.margin_top = -118
	hint = Label.new(); hint.add_font_override("font", G.font_s); hint.add_color_override("font_color", Color(1, 1, 1, 0.55)); hint.text = "Space to skip"
	hint.anchor_left = 1; hint.anchor_right = 1; hint.anchor_top = 1; hint.anchor_bottom = 1; hint.margin_left = -150; hint.margin_top = -40
	for l in [title_l, sub_l, hint]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(l)
	layer.visible = false

func play(list, obj = null, method = "", args = []):
	if on:
		if obj: obj.callv(method, args)
		return
	on = true; shots = list; i = -1
	end_obj = obj; end_m = method; end_args = args
	G.MODE = "cutscene"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	main.phone.close(); main.hud.close_menu()
	layer.visible = true
	main.sfx.play("riser", 0.35)
	_next()

func _next():
	i += 1
	if i >= shots.size():
		end(); return
	cur = shots[i]; t = 0.0
	if cur.has("start"): cur.start[0].callv(cur.start[1], cur.start.slice(2, cur.start.size() - 1) if cur.start.size() > 2 else [])
	if cur.has("say"): main.hud.say(cur.say[0], cur.say[1])
	title_l.text = cur.get("title", ""); sub_l.text = cur.get("sub", "")
	main.camera.fov = cur.get("fov", 50)

func end():
	if not on: return
	on = false
	layer.visible = false
	main.camera.fov = 62
	if G.MODE == "cutscene": G.MODE = "play"
	var P = main.player
	if P.car: P.cam_yaw = P.car.yaw + PI
	var o = end_obj
	end_obj = null
	if o: o.callv(end_m, end_args)

func _ease(x):
	return 2 * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 2) / 2

func update(dt):
	if not on or cur == null: return
	t += dt
	var k = _ease(clamp(t / float(cur.dur), 0, 1))
	var h = get_viewport().get_visible_rect().size.y
	var bh = h * 0.1 * min(1.0, (t + (0.0 if i == 0 else 1.0)) * 3)
	bar_top.margin_bottom = bh; bar_bot.margin_top = -bh
	title_l.modulate.a = clamp(t * 2.0, 0, 1) * clamp((float(cur.dur) - t) * 2.0, 0, 1)
	sub_l.modulate.a = title_l.modulate.a
	var cam = main.camera
	if cur.has("orbit"):
		var o = cur.orbit
		var a = lerp(o.a0, o.a1, k)
		cam.translation = o.c + Vector3(cos(a) * o.r, lerp(o.h0, o.h1, k), sin(a) * o.r)
		cam.look_at(o.c + Vector3(0, 1.4, 0), Vector3.UP)
	else:
		cam.translation = cur.from.linear_interpolate(cur.get("to", cur.from), k)
		var look = cur.look.linear_interpolate(cur.get("look_to", cur.look), k)
		if cam.translation.distance_to(look) > 0.01: cam.look_at(look, Vector3.UP)
	if t >= float(cur.dur): _next()

func _unhandled_input(e):
	if on and (e.is_action_pressed("ui_accept") or e.is_action_pressed("jump") or e.is_action_pressed("pause")):
		get_tree().set_input_as_handled()
		end()

# ---------- the scenes ----------
func _head():
	var P = main.player
	return P.pos + Vector3(0, 1.5, 0)

func _beside(side, back, up):
	var P = main.player
	var y = P.body_yaw
	var f = Vector3(sin(y), 0, cos(y))
	var l = Vector3(cos(y), 0, -sin(y))
	return P.pos + l * side + f * back + Vector3(0, up, 0)

func cut_intro():
	return [
		{ "dur": 6, "from": Vector3(-78, 52, 112), "to": Vector3(-30, 36, 74), "look": Vector3(30, 2, -30), "look_to": Vector3(48, 6, -40), "fov": 46, "title": "Calder Park", "sub": "Chicago · " + G.clock_str() },
		{ "dur": 5, "from": Vector3(6, 1.4, 6.5), "to": Vector3(30, 2.0, 5.2), "look": Vector3(70, 8, -6), "look_to": Vector3(70, 8.6, -9), "fov": 42 },
		{ "dur": 4.5, "from": _beside(1.8, 3.2, 1.9), "to": _beside(0.9, 2.2, 1.7), "look": _head(), "fov": 40, "title": "@" + str(G.S["name"]), "sub": "Day " + str(G.S.get("day", 1)) },
	]

func cut_studio():
	var C = G.D["CAST"]
	return [
		{ "dur": 3.4, "from": Vector3(35.5, 1.1, -1.5), "to": Vector3(38.2, 1.5, -4.2), "look": Vector3(41, 1.9, -10.4), "fov": 40, "say": [C.benny.name, "Booth's warm. Come down."], "start": [self, "_benny_wave"] },
		{ "dur": 2.6, "from": Vector3(44.5, 2.8, -4.5), "to": Vector3(42.4, 1.5, -6.6), "look": Vector3(41, 0, -9.8), "fov": 44 },
	]

func _benny_wave():
	if main.story.NPCS.has("benny"): main.story.NPCS.benny.wave_t = 3

func cut_video():
	return [{ "dur": 3.6, "from": Vector3(62.0, 8.6, 18), "to": Vector3(63.2, 8.2, 5), "look": _head(), "fov": 38, "title": "Rolling", "sub": "Hit your marks", "start": [main.player, "emote", "point", 2.5] }]

func cut_busted():
	var P = main.player
	return [
		{ "dur": 2.8, "from": _beside(3.2, 1.5, 0.6), "to": _beside(2.4, 2.4, 0.9), "look": _head(), "fov": 42, "say": ["POLICE", "Hands where I can see them!"], "start": [P, "hands_up_for", 3.6] },
		{ "dur": 2.6, "from": P.pos + Vector3(4, 9, 5), "to": P.pos + Vector3(5, 13, 7), "look": P.pos, "fov": 46, "title": "Busted", "sub": "Heat maxed out" if G.S["heat"] >= 90 else "Area 7 police" },
	]

func cut_downed():
	var P = main.player
	var c = P.human.ragdoll_center() if P.human.is_ragdoll() else P.pos
	return [{ "dur": 3.4, "from": c + Vector3(1.6, 1.4, 1.6), "to": c + Vector3(2.4, 7, 2.4), "look": c + Vector3(0, 0.2, 0), "fov": 44, "title": "Down", "sub": "Calder General" }]

func cut_saint(s):
	var P = main.player
	var a = s.pos + (P.pos - s.pos) * 0.35
	var b = s.pos + (P.pos - s.pos) * 0.25
	return [
		{ "dur": 3.6, "from": Vector3(a.x, 1.3, a.z), "to": Vector3(b.x, 1.5, b.z), "look": Vector3(s.pos.x, 1.6, s.pos.z), "fov": 38, "say": [G.D["CAST"]["saint"].name, "You keep saying my name. Say it now."] },
		{ "dur": 2.4, "from": _beside(0.7, -1.6, 1.8), "to": _beside(0.6, -1.2, 1.7), "look": Vector3(s.pos.x, 1.5, s.pos.z), "fov": 44 },
	]

func cut_ending(id):
	var P = main.player
	var C = G.D["CAST"]
	if id == "wayout":
		return [
			{ "dur": 3.5, "from": Vector3(-2, 1.6, 66), "to": Vector3(-4, 2.2, 63), "look": Vector3(-12, 2.4, 63), "fov": 40, "start": [P, "emote", "hype", 4.0] },
			{ "dur": 3.5, "from": _beside(0, 4, 1.8), "to": _beside(0, 9, 6), "look": _head(), "fov": 44, "start": [main.sfx, "cheer"] },
		]
	if id == "witness":
		return [
			{ "dur": 3.5, "from": Vector3(60, 1.2, -94), "to": Vector3(63, 1.6, -99), "look": Vector3(67.1, 1.1, -104), "fov": 38, "say": [C.reyes.name, "Start from the beginning."] },
			{ "dur": 3, "from": Vector3(66, 8.4, -86), "to": Vector3(70, 9.5, -80), "look": Vector3(67, 1, -104), "fov": 46 },
		]
	if id == "crown":
		return [{ "dur": 6, "orbit": { "c": P.pos, "r": 4.2, "a0": 0.0, "a1": 1.6, "h0": 1.4, "h1": 2.9 }, "fov": 40, "start": [P, "emote", "flex", 6.0] }]
	return [
		{ "dur": 3.2, "from": _beside(2.5, 2.5, 0.8), "to": _beside(2, 3, 1.2), "look": _head(), "fov": 42, "say": [C.reyes.name, "Hands where I can see them."], "start": [P, "hands_up_for", 6.0] },
		{ "dur": 3, "from": P.pos + Vector3(3, 1.2, 3), "to": P.pos + Vector3(3, 1.0, 3), "look": P.pos + Vector3(3, 16, -30), "fov": 50 },
	]
