extends Node
# Online play for the Godot version. One player hosts (Phone → Online → Host), the others
# join by IP, or pick the game from the list of games on the same network. Everyone sees
# each other walk, drive, shoot, punch, dance and wear their fits; gangs can invite players
# and gang members can't hurt each other. Built on Godot's ENet networking (UDP 24680),
# so it works between Godot players; the browser version keeps its own peer-to-peer rooms.

var main
const PORT = 24680
const LAN_PORT = 24681
var peer = null
var status = "offline"      # offline, hosting, joining, online
var msg = ""
var R = {}                  # peer id -> remote player
var send_t = 0.0
var lan = null
var lan_t = 0.0
var LAN = {}                # "ip:port" -> {name, players, t}
var bcast = null
var invites = []
const EMOTE_IDS = ["", "dance1", "dance2", "dance3", "hype", "clap", "laugh", "shrug", "salute", "point", "facepalm", "flex", "sit", "snowangel"]

class Remote:
	var main
	var id = 0
	var name = "player"
	var skin = {}
	var gang = null
	var h = null
	var pos = Vector3()
	var tpos = Vector3()
	var vel = Vector3()
	var yaw = 0.0
	var tyaw = 0.0
	var st = {}
	var car = null
	var car_key = ""
	var hp = 100.0
	var crouched = false
	var t = 0.0
	func is_down(): return st.get("down", false)
	func take_hit(dmg, head, dir, by_player, melee):
		if by_player: main.net.hit_remote(self, dmg, head, melee)

func setup(m):
	main = m
	get_tree().connect("network_peer_connected", self, "_on_peer")
	get_tree().connect("network_peer_disconnected", self, "_on_peer_gone")
	get_tree().connect("connected_to_server", self, "_on_connected")
	get_tree().connect("connection_failed", self, "_on_failed")
	get_tree().connect("server_disconnected", self, "_on_server_gone")

func online(): return status == "hosting" or status == "online"

# ---------- hosting and joining ----------
func host(port = PORT):
	leave()
	peer = NetworkedMultiplayerENet.new()
	var err = peer.create_server(port, 8)
	if err != OK:
		msg = "Could not host on port %d (is another game using it?)" % port; peer = null; return false
	get_tree().network_peer = peer
	status = "hosting"; msg = "Hosting on port %d. Friends on the same Wi-Fi see you under Games nearby." % port
	bcast = PacketPeerUDP.new(); bcast.set_broadcast_enabled(true)
	bcast.set_dest_address("255.255.255.255", LAN_PORT)
	main.hud.banner("Hosting", "Port %d" % port)
	return true

func join(ip, port = PORT):
	leave()
	ip = ip.strip_edges()
	if ip == "":
		msg = "Type the host's IP address."
		return false
	peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(ip, int(port))
	if err != OK:
		msg = "Could not reach %s" % ip; peer = null; return false
	get_tree().network_peer = peer
	status = "joining"; msg = "Joining %s ..." % ip
	return true

func leave():
	for id in R.keys(): _remove(id)
	if peer:
		peer.close_connection()
		get_tree().network_peer = null
	peer = null; bcast = null
	if status != "offline": main.hud.toast("Left the online game")
	status = "offline"

func _on_connected():
	status = "online"; msg = "Connected."
	main.hud.banner("Online", "Connected to the host")

func _on_failed():
	status = "offline"; msg = "Could not connect. Check the IP, and that the host's port %d is open." % PORT
	call_deferred("_drop_peer")

func _drop_peer():
	get_tree().network_peer = null; peer = null

func _on_server_gone():
	main.hud.banner("Host left", "Back to playing solo")
	call_deferred("leave")

func _on_peer(id):
	rpc_id(id, "hello", _profile())

func _on_peer_gone(id):
	if R.has(id): main.hud.toast("@%s left" % R[id].name)
	_remove(id)

func _profile():
	var g = G.S.get("gang")
	return { "name": str(G.S["name"]), "skin": G.S["skin"], "gang": [str(g.id), g.name, g.tag, int(g.color)] if typeof(g) == TYPE_DICTIONARY else null }

# ---------- what peers send each other ----------
remote func hello(p):
	var id = get_tree().get_rpc_sender_id()
	var r = R.get(id)
	if r == null:
		r = Remote.new(); r.main = main; r.id = id
		R[id] = r
		main.hud.toast("@%s is here" % str(p.get("name", "player")))
	r.name = str(p.get("name", "player")).substr(0, 18)
	r.gang = p.get("gang")
	var skin = p.get("skin", {})
	if typeof(skin) != TYPE_DICTIONARY: skin = {}
	if r.h == null or JSON.print(skin) != JSON.print(r.skin):
		r.skin = skin
		if r.h: r.h.queue_free()
		r.h = load("res://scripts/Human.gd").new().build(G.skin_opts(skin))
		main.add_child(r.h)
		r.h.translation = r.pos

remote func st(s):
	var id = get_tree().get_rpc_sender_id()
	var r = R.get(id)
	if r == null or typeof(s) != TYPE_DICTIONARY: return
	r.st = s; r.t = 0.0
	r.tpos = Vector3(float(s.get("x", 0)), float(s.get("y", 0)), float(s.get("z", 0)))
	r.tyaw = float(s.get("yaw", 0))
	if r.pos == Vector3() or r.pos.distance_to(r.tpos) > 12: r.pos = r.tpos

remote func shot(a, b, kind):
	main.sfx.tracer(a, b)
	main.sfx.shot(kind, a, 0.8)
	main.sfx.flash(a)

remote func hurt(dmg, from, melee):
	var id = get_tree().get_rpc_sender_id()
	var r = R.get(id)
	if r and _same_gang(r): return
	var P = main.player
	if melee: P.take_punch(float(dmg), from)
	else: P.hurt(float(dmg), from)
	if G.S["health"] <= 0 and r: rpc_id(id, "dropped", str(G.S["name"]))

remote func dropped(who):
	G.S["stats"]["pvpDowns"] = int(G.S["stats"].get("pvpDowns", 0)) + 1
	main.hud.banner("You dropped @" + who, "")

remote func gang_invite(g):
	var id = get_tree().get_rpc_sender_id()
	if typeof(g) != TYPE_ARRAY or g.size() < 4: return
	invites.append({ "from": id, "g": g })
	var who = R[id].name if R.has(id) else "someone"
	main.hud.toast("@%s invited you to [%s] %s. Open the phone, Online, to accept." % [who, g[2], g[1]])

remote func gang_joined(who):
	main.hud.toast("@%s joined the gang" % who)
	main.gang.rep(2)

func invite(id):
	var g = G.S.get("gang")
	if typeof(g) != TYPE_DICTIONARY or not online(): return
	rpc_id(id, "gang_invite", [str(g.id), g.name, g.tag, int(g.color)])
	main.hud.toast("Invite sent to @" + R[id].name)

func accept_invite(i):
	var inv = invites[i]
	invites.remove(i)
	var g = inv.g
	if not main.gang.text_ok(g[1]) or not main.gang.text_ok(g[2]): return
	G.S["gang"] = { "id": str(g[0]).substr(0, 12), "name": str(g[1]).substr(0, 18), "tag": str(g[2]).substr(0, 4), "color": int(g[3]) % G.D["GANG_COLORS"].size(), "role": "member",
		"leader": R[inv.from].name if R.has(inv.from) else "", "rep": 0, "created": OS.get_unix_time() * 1000 }
	main.hud.banner("[%s] %s" % [G.S["gang"].tag, G.S["gang"].name], "You joined the gang")
	if online():
		rpc("hello", _profile())
		rpc_id(inv.from, "gang_joined", str(G.S["name"]))

func _same_gang(r):
	var g = G.S.get("gang")
	return typeof(g) == TYPE_DICTIONARY and typeof(r.gang) == TYPE_ARRAY and str(r.gang[0]) == str(g.id)

func hit_remote(r, dmg, head, melee):
	if _same_gang(r):
		main.hud.toast("Same gang. No friendly fire."); return
	main.sfx.blood(r.pos + Vector3(0, 1.3, 0), Vector3())
	rpc_id(r.id, "hurt", dmg * (1.0 if melee else 1.0), main.player.pos, melee)

func send_shot(a, b):
	if online(): rpc_unreliable("shot", a, b, G.S["cur"])

func profile_changed():
	if online(): rpc("hello", _profile())

# remote players as targets for your shots and punches
func targets():
	var out = []
	for r in R.values():
		if r.h and not r.st.get("car", false): out.append(r)
	return out

# ---------- every frame ----------
func update(dt):
	_lan(dt)
	if peer == null: return
	if not online():
		return
	send_t -= dt
	if send_t <= 0:
		send_t = 0.1
		rpc_unreliable("st", _my_state())
	for r in R.values():
		_update_remote(r, dt)

func _my_state():
	var P = main.player
	var s = { "x": P.pos.x, "y": P.pos.y, "z": P.pos.z, "yaw": P.body_yaw, "sp": P.speed, "cr": P.crouch, "aim": P.aim_t, "pitch": P.cam_pitch,
		"fists": G.S.get("fists", false), "punch": P.punch_t / P.punch_dur if P.punch_t > 0 else 0.0, "ps": P.punch_side, "flip": P.flipping(), "wave": P.wave_t > 0,
		"em": EMOTE_IDS.find(P.emote_name), "et": P.emote_t, "down": P.is_ragdoll() or P.dead, "gun": G.S["cur"], "hands": P.hands_up > 0 }
	if P.car:
		s["car"] = true; s["cm"] = P.car.model; s["cc"] = int(P.car.color); s["cx"] = P.car.pos.x; s["cz"] = P.car.pos.z; s["cy"] = P.car.yaw
	return s

func _update_remote(r, dt):
	r.t += dt
	if r.h == null: return
	var s = r.st
	var k = 1 - exp(-dt * 12)
	r.pos = r.pos.linear_interpolate(r.tpos, k)
	r.yaw += G.ang_diff(r.yaw, r.tyaw) * k
	if s.get("car", false):
		r.h.visible = false
		var key = str(s.get("cm", "sedan")) + str(s.get("cc", 0))
		if r.car == null or r.car.dead or r.car_key != key:
			if r.car: main.vehicles.remove(r.car)
			r.car = main.vehicles.spawn(str(s.get("cm", "sedan")), float(s.cx), float(s.cz), float(s.cy), { "owned": false, "color": int(s.get("cc", 0)), "locked": true })
			if r.car: r.car.driver = "remote"
			r.car_key = key
		if r.car:
			var tp = Vector3(float(s.cx), 0, float(s.cz))
			r.car.pos = r.car.pos.linear_interpolate(tp, k) if r.car.pos.distance_to(tp) < 15 else tp
			r.car.yaw += G.ang_diff(r.car.yaw, float(s.cy)) * k
			main.vehicles.place(r.car)
		return
	if r.car:
		main.vehicles.remove(r.car); r.car = null
	r.h.visible = true
	if s.get("down", false):
		if not r.h.is_ragdoll(): r.h.ragdoll_start(Vector3(), Vector3(sin(r.yaw), 0.3, cos(r.yaw)) * -2.0)
		r.h.ragdoll_update(dt)
		return
	if r.h.is_ragdoll(): r.h.ragdoll_stop()
	r.h.translation = r.pos
	r.h.rotation = Vector3(0, r.yaw, 0)
	var em = int(s.get("em", 0))
	r.crouched = s.get("cr", false)
	r.h.animate(dt, { "speed": float(s.get("sp", 0)), "crouch": 1.0 if r.crouched else 0.0, "aim": 0.0 if s.get("fists", false) else float(s.get("aim", 0)), "pitch": float(s.get("pitch", 0)),
		"fists": s.get("fists", false), "guard": s.get("fists", false) and float(s.get("aim", 0)) > 0.5, "punch": float(s.get("punch", 0)), "punchSide": int(s.get("ps", 1)),
		"flip": s.get("flip", false), "wave": s.get("wave", false), "hands": s.get("hands", false), "twoHand": s.get("gun", "k9") != "k9",
		"emote": EMOTE_IDS[em] if em > 0 and em < EMOTE_IDS.size() else "", "et": float(s.get("et", 0)), "down": 1.0 if EMOTE_IDS[em] == "snowangel" else 0.0 })
	if r.t > 6:
		r.h.visible = false

func _remove(id):
	var r = R.get(id)
	if r == null: return
	if r.h: r.h.queue_free()
	if r.car: main.vehicles.remove(r.car)
	R.erase(id)

# ---------- games on the same network ----------
func lan_listen(on):
	if on and lan == null:
		lan = PacketPeerUDP.new()
		if lan.listen(LAN_PORT) != OK: lan = null
	elif not on and lan:
		lan.close(); lan = null

func _lan(dt):
	lan_t -= dt
	if status == "hosting" and bcast and lan_t <= 0:
		lan_t = 1.0
		bcast.put_packet(JSON.print({ "ds": 1, "name": str(G.S["name"]), "port": PORT, "players": R.size() + 1 }).to_utf8())
	if lan:
		while lan.get_available_packet_count() > 0:
			var pk = lan.get_packet().get_string_from_utf8()
			var ip = lan.get_packet_ip()
			var o = parse_json(pk)
			if typeof(o) == TYPE_DICTIONARY and o.get("ds") == 1:
				LAN[ip + ":" + str(o.get("port", PORT))] = { "ip": ip, "port": int(o.get("port", PORT)), "name": str(o.get("name", "?")).substr(0, 18), "players": int(o.get("players", 1)), "t": G.REAL_T }
		for k in LAN.keys():
			if G.REAL_T - LAN[k].t > 5: LAN.erase(k)

func my_ips():
	var out = []
	for a in IP.get_local_addresses():
		if a.find(":") < 0 and not a.begins_with("127.") and not a.begins_with("169.254"): out.append(a)
	return out
