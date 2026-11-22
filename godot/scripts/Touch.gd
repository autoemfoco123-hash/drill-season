extends Node
# On-screen controls for phones and tablets (and touchscreen laptops):
#  - left side: a joystick that appears where your thumb lands; push it to the edge to sprint
#  - right side: drag to look around
#  - buttons: fire, aim (toggle), jump, crouch, reload, car, use, and a row for the phone,
#    the weapon wheel (tap to switch, hold and slide to pick), emotes (hold and slide),
#    snowball, first/third person
#  - in a car the buttons become gas, brake, handbrake, horn, radio and exit
# Every touch is tracked by its finger index, so you can move, look and shoot at once.

var main
var layer
var view
var enabled = false
var fingers = {}            # index -> {kind, start, pos, btn}
var stick_center = Vector2()
var stick_vec = Vector2()
var stick_finger = -1
var aim_on = false
var held = {}               # action -> true while a button holds it
const STICK_R = 70.0

class View extends Control:
	var tc
	func _draw():
		tc._draw_on(self)

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 4; add_child(layer)
	view = View.new(); view.tc = self; view.anchor_right = 1; view.anchor_bottom = 1; view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(view)
	var want = str(G.S.get("settings", {}).get("touch", "auto"))
	enabled = want == "on" or (want == "auto" and (OS.has_touchscreen_ui_hint() or OS.get_name() in ["Android", "iOS"])) or OS.get_environment("DS_TOUCH") != ""
	apply()

func apply():
	view.visible = enabled
	main.hud.set_touch_layout(enabled)
	# on a touchscreen the emulated mouse must not fire or aim
	for a in ["fire", "aim"]:
		for e in InputMap.get_action_list(a):
			if e is InputEventMouseButton and enabled: InputMap.action_erase_event(a, e)
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func set_mode(mode):
	G.S["settings"]["touch"] = mode
	var was = enabled
	enabled = mode == "on" or (mode == "auto" and (OS.has_touchscreen_ui_hint() or OS.get_name() in ["Android", "iOS"]))
	if was != enabled:
		_release_all()
		if not enabled:
			# give the mouse back its buttons
			for p in [["fire", BUTTON_LEFT], ["aim", BUTTON_RIGHT]]:
				var me = InputEventMouseButton.new(); me.button_index = p[1]; InputMap.action_add_event(p[0], me)
		apply()

# ---------- the buttons ----------
func _size():
	return view.rect_size if view.rect_size.x > 10 else Vector2(1280, 720)

func buttons():
	var s = _size()
	var W = s.x
	var H = s.y
	var P = main.player
	var out = []
	if P.car:
		out.append({ "id": "gas", "label": "GAS", "act": "fire", "c": Vector2(W - 120, H - 170), "r": 62, "hold": true })
		out.append({ "id": "brake", "label": "BRAKE", "act": "aim", "c": Vector2(W - 255, H - 110), "r": 48, "hold": true })
		out.append({ "id": "hand", "label": "DRIFT", "act": "jump", "c": Vector2(W - 255, H - 245), "r": 40, "hold": true })
		out.append({ "id": "exit", "label": "EXIT", "act": "car", "c": Vector2(W - 110, H - 330), "r": 38 })
		out.append({ "id": "horn", "label": "HORN", "act": "horn", "c": Vector2(W - 370, H - 90), "r": 34 })
		out.append({ "id": "radio", "label": "RADIO", "act": "reload", "c": Vector2(W - 380, H - 200), "r": 34 })
	else:
		var fists = G.S.get("fists", false)
		out.append({ "id": "fire", "label": "PUNCH" if fists else "FIRE", "act": "fire", "c": Vector2(W - 120, H - 170), "r": 62, "hold": true })
		out.append({ "id": "aim", "label": "GUARD" if fists else "AIM", "act": "aim", "c": Vector2(W - 255, H - 245), "r": 44, "toggle": true })
		out.append({ "id": "jump", "label": "JUMP", "act": "jump", "c": Vector2(W - 255, H - 105), "r": 42, "hold": true })
		out.append({ "id": "crouch", "label": "DUCK", "act": "crouch", "c": Vector2(W - 375, H - 85), "r": 34 })
		out.append({ "id": "reload", "label": "RELOAD", "act": "reload", "c": Vector2(W - 380, H - 195), "r": 34 })
		out.append({ "id": "car", "label": "CAR", "act": "car", "c": Vector2(W - 110, H - 330), "r": 38 })
		out.append({ "id": "use", "label": "E", "act": "use", "c": Vector2(W - 215, H - 375), "r": 38, "hold": true, "hi": main.hud.help_box.visible })
	var y = 262.0
	var row = [["phone", "PHONE", "phone"], ["weapon", "WEAPON", "next_weapon"], ["emote", "EMOTE", "emote"], ["snow", "SNOW", "snowball"], ["cam", "VIEW", "camera"]]
	if P.car: row = [["phone", "PHONE", "phone"], ["cam", "VIEW", "camera"]]
	for i in range(row.size()):
		var b = { "id": row[i][0], "label": row[i][1], "act": row[i][2], "c": Vector2(W - 52 - i * 74, y), "r": 30 }
		if row[i][0] in ["weapon", "emote"]:
			b["hold"] = true
			b["wheel"] = true
		out.append(b)
	return out

func _hit(pos):
	for b in buttons():
		if pos.distance_to(b.c) <= b.r + 10: return b
	return null

# ---------- touches ----------
func _input(e):
	if not enabled: return
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag): return
	var live = G.MODE == "play" and not main.hud.menu_box
	if not live:
		if e is InputEventScreenTouch and not e.pressed: _end(e.index)
		return
	var s = _size()
	if e is InputEventScreenTouch:
		if e.pressed:
			var b = _hit(e.position)
			if b:
				_press(e.index, b)
			elif e.position.x < s.x * 0.42 and e.position.y > s.y * 0.3:
				fingers[e.index] = { "kind": "stick" }
				stick_finger = e.index; stick_center = e.position; stick_vec = Vector2()
			else:
				fingers[e.index] = { "kind": "look", "pos": e.position }
		else:
			_end(e.index)
		get_tree().set_input_as_handled()
	elif e is InputEventScreenDrag:
		var f = fingers.get(e.index)
		if f == null: return
		if f.kind == "stick":
			var d = e.position - stick_center
			if d.length() > STICK_R * 1.6: stick_center = e.position - d.normalized() * STICK_R * 1.6
			stick_vec = (e.position - stick_center) / STICK_R
			if stick_vec.length() > 1: stick_vec = stick_vec.normalized()
		elif f.kind == "look":
			var k = 1.8 * float(G.S["settings"].get("touchSens", 1.0))
			main.player.look(e.relative.x * k, e.relative.y * k)
		elif f.kind == "button" and f.get("wheel", false):
			main.hud.wheel_vec += e.relative * 1.6
			if main.hud.wheel_vec.length() > 120: main.hud.wheel_vec = main.hud.wheel_vec.normalized() * 120
		get_tree().set_input_as_handled()

func _press(idx, b):
	if b.get("toggle", false):
		aim_on = not aim_on
		_action(b.act, aim_on)
		fingers[idx] = { "kind": "tap", "btn": b.id }
		return
	fingers[idx] = { "kind": "button", "btn": b.id, "act": b.act, "wheel": b.get("wheel", false) }
	_action(b.act, true)
	if not b.get("hold", false):
		_action(b.act, false)
		fingers[idx].kind = "tap"
	Input.start_joy_vibration(0, 0.2, 0.0, 0.03)

func _end(idx):
	var f = fingers.get(idx)
	if f == null: return
	if f.kind == "stick":
		stick_finger = -1; stick_vec = Vector2()
	elif f.kind == "button":
		_action(f.act, false)
	fingers.erase(idx)

func _action(a, on):
	var ev = InputEventAction.new(); ev.action = a; ev.pressed = on
	Input.parse_input_event(ev)
	if on: held[a] = true
	else: held.erase(a)

func _release_all():
	for a in held.keys(): _action(a, false)
	for a in ["move_f", "move_b", "move_l", "move_r", "sprint"]: Input.action_release(a)
	fingers.clear(); stick_finger = -1; stick_vec = Vector2(); aim_on = false

func update(dt):
	if not enabled: return
	var live = G.MODE == "play" and not main.hud.menu_box
	view.visible = live or G.MODE == "phone"
	if not live:
		if held.size() > 0 or stick_vec != Vector2(): _release_all()
		view.update(); return
	if aim_on and main.player.car: aim_on = false
	if aim_on and not held.has("aim"): _action("aim", true)
	# joystick -> movement strengths; at the edge you sprint
	var v = stick_vec
	_strength("move_r", max(0.0, v.x)); _strength("move_l", max(0.0, -v.x))
	_strength("move_b", max(0.0, v.y)); _strength("move_f", max(0.0, -v.y))
	if v.length() > 0.95 and -v.y > 0.6 and not main.player.car: Input.action_press("sprint")
	else: Input.action_release("sprint")
	view.update()

func _strength(a, s):
	if s > 0.05: Input.action_press(a, min(1.0, s * 1.15))
	else: Input.action_release(a)

# ---------- drawing ----------
func _draw_on(c):
	if not (G.MODE == "play" and not main.hud.menu_box): return
	var f = G.font_xs
	for b in buttons():
		var pressed = false
		for k in fingers.keys():
			if fingers[k].get("btn") == b.id: pressed = true
		if b.id == "aim" and aim_on: pressed = true
		var fill = Color(1, 0.62, 0.22, 0.55) if pressed else (Color(1, 1, 1, 0.22) if b.get("hi", false) else Color(0.05, 0.06, 0.09, 0.38))
		c.draw_circle(b.c, b.r, fill)
		c.draw_arc(b.c, b.r, 0, TAU, 40, Color(1, 1, 1, 0.55), 2.0)
		var tw = f.get_string_size(b.label).x
		c.draw_string(f, b.c + Vector2(-tw / 2, 5), b.label, Color(1, 1, 1, 0.92))
	if stick_finger >= 0:
		c.draw_circle(stick_center, STICK_R, Color(0.05, 0.06, 0.09, 0.3))
		c.draw_arc(stick_center, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.45), 2.0)
		c.draw_circle(stick_center + stick_vec * STICK_R, 30, Color(1, 1, 1, 0.5))
	else:
		var s = _size()
		var hint = Vector2(150, s.y - 150)
		c.draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.16), 2.0)
		c.draw_string(f, hint + Vector2(-f.get_string_size("MOVE").x / 2, 5), "MOVE", Color(1, 1, 1, 0.3))
