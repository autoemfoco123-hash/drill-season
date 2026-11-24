extends Node
# A dedicated server: the game started with --server runs this instead of the world.
# Leave it running on any computer or VPS and it stays on the server list of every player in
# the world, day and night. No ports to open: like everyone else it connects OUT to the public
# relay (MQTT brokers), announces itself there (a retained message that the brokers drop if
# the server crashes), checks the password and the player limit for everyone who joins,
# greets them with the message of the day, and logs joins, leaves and chat.
#
#   Linux:    ./DrillSeason.x86_64 --audio-driver Dummy --server --name="My Server"
#             (on a VPS with no screen: xvfb-run -a ./DrillSeason.x86_64 ... ; servidor.sh does it)
#   Windows:  DrillSeason.exe --audio-driver Dummy --server --name="My Server"   (servidor.bat)
#   Mac:      "Drill Season.app/Contents/MacOS/Drill Season" --server
#
# Options: --name=  --max=2..64  --password=  --motd=  --pvp=on|off  --region=  --id=
# (the id keeps the same listing across restarts; it is saved on first start)
#          --port=24680  --addr=your.public.ip[:port]  --direct=on|off
#
# Direct (1.9.1, on by default): the server also listens for players itself on UDP --port,
# opens that port on the router on its own (UPnP) and lists its address, so players connect
# straight to it, quick, and can join by address even with no relay at all (Online → Join by
# address). On a VPS the address is the machine's own; behind a router that won't do UPnP,
# forward the UDP port and pass --addr. Players who come in through the relay and players
# who connect directly see each other: the server passes their messages across.
#
# Turf: the server keeps this server's turf map (which gang or crew holds each block, see
# Turf.gd), sends it to everyone who joins and every 30 seconds, and saves it to
# turf_<id>.json in the user folder, so taken blocks stay taken across restarts.

const Net = preload("res://scripts/Net.gd")
const Turf = preload("res://scripts/Turf.gd")

var links = []
var sid = ""
var room = ""
var cfg = {}
var players = {}            # remote id -> { "name", "seen" }
var rejected = {}
var announce_t = 0.0
var relay_t = 0.0
var broker_i = 0
var seq = 0
var seen = {}
var log_lines = []
var label = null
var status_t = 0.0
var online = false
var log_file = null         # servidor.log next to the game (or in the user folder)
var peer = null             # direct players (ENet)
var enet = {}               # ENet id -> { "name", "seen" }
var drop_at = {}            # ENet id -> time to disconnect (turned away)
var pub_addr = ""
var lan_addr = ""
var upnp = null
var upnp_thread = null
var turf = []               # who holds which block (Turf.gd), saved next to the log
var turf_t = 10.0

func _ready():
	Engine.target_fps = 20
	OS.low_processor_usage_mode = true
	cfg = _args()
	_open_log()
	sid = cfg.id
	room = ("d" + sid).substr(0, 20)
	_turf_load()
	if OS.get_name() != "Server":
		# a plain window on desktops: the status and the log
		var bg = ColorRect.new(); bg.color = Color(0.05, 0.06, 0.08); bg.anchor_right = 1; bg.anchor_bottom = 1; add_child(bg)
		label = Label.new(); label.anchor_right = 1; label.anchor_bottom = 1; label.margin_left = 16; label.margin_top = 12
		label.add_font_override("font", G.font_s); label.add_color_override("font_color", Color(0.85, 0.9, 0.95))
		add_child(label)
	_log("Drill Season dedicated server %s" % Net.VERSION)
	_log("Name: %s · slots %d · PvP %s · password %s · region %s" % [cfg.name, cfg.max, "on" if cfg.pvp else "off", "yes" if cfg.pw != "" else "no", cfg.region])
	if cfg.motd != "": _log("Message of the day: " + cfg.motd)
	_log("Server id %s (keep --id=%s to keep the same listing)" % [sid, sid])
	_fill()
	if cfg.direct: _listen()

func _args():
	var c = { "name": "Drill Season server", "max": 24, "pw": "", "motd": "", "pvp": true, "region": "", "id": "", "brokers": "", "port": Net.PORT, "addr": "", "direct": true }
	for a in OS.get_cmdline_args():
		var kv = a.split("=", true, 1)
		if kv.size() < 2: continue
		var k = kv[0].trim_prefix("--")
		var v = kv[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
		if k == "name": c.name = Net.clean_text(v, 32)
		elif k == "max": c.max = int(clamp(int(v), 2, 64))
		elif k == "password": c.pw = v.substr(0, 32)
		elif k == "motd": c.motd = Net.clean_text(v, 120)
		elif k == "pvp": c.pvp = not (v.to_lower() in ["off", "0", "no", "false"])
		elif k == "region": c.region = Net.clean_text(v, 3).to_upper()
		elif k == "id" and v.is_valid_identifier() and v.length() <= 20: c.id = v
		elif k == "port" and v.is_valid_integer(): c.port = int(clamp(int(v), 1024, 65535))
		elif k == "addr": c.addr = Net.clean_addr(v)
		elif k == "direct": c.direct = not (v.to_lower() in ["off", "0", "no", "false"])
	if c.region == "":
		var parts = OS.get_locale().split("_")
		c.region = (parts[1] if parts.size() > 1 else parts[0]).to_upper().substr(0, 3)
	if c.id == "": c.id = _saved_id()
	return c

func _saved_id():
	var f = File.new()
	var p = "user://server_id.txt"
	if f.open(p, File.READ) == OK:
		var s = f.get_as_text().strip_edges(); f.close()
		if s.is_valid_identifier() and s.length() <= 20: return s
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var s2 = "srv"
	for _i in range(11): s2 += chars[rng.randi_range(0, chars.length() - 1)]
	if f.open(p, File.WRITE) == OK:
		f.store_string(s2); f.close()
	return s2

# ---------- direct players ----------
func _listen():
	peer = NetworkedMultiplayerENet.new()
	if peer.create_server(cfg.port, cfg.max + 4) != OK:
		_log("Could not listen on UDP %d (in use?). Players can still join through the relay." % cfg.port)
		peer = null; return
	get_tree().network_peer = peer
	get_tree().connect("network_peer_connected", self, "_peer_in")
	get_tree().connect("network_peer_disconnected", self, "_peer_out")
	for ip in _ips():
		lan_addr = "%s:%d" % [ip, cfg.port]; break
	if cfg.addr != "":
		pub_addr = cfg.addr if ":" in cfg.addr else "%s:%d" % [cfg.addr, cfg.port]
		_log("Direct: listening on UDP %d, address %s" % [cfg.port, pub_addr])
		return
	for ip in _ips():
		if _public(ip):
			pub_addr = "%s:%d" % [ip, cfg.port]
			_log("Direct: listening on UDP %d, address %s" % [cfg.port, pub_addr])
			return
	_log("Direct: listening on UDP %d (%s on this network). Asking the router to open the port…" % [cfg.port, lan_addr])
	if ClassDB.class_exists("UPNP") and OS.get_environment("DS_NOUPNP") == "":
		upnp_thread = Thread.new()
		upnp_thread.start(self, "_upnp_job", cfg.port)

func _upnp_job(port):
	var u = UPNP.new()
	var res = { "ok": false, "ip": "" }
	if u.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		if u.add_port_mapping(port, port, "Drill Season server", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS:
			res.ok = true; res.ip = u.query_external_address()
	call_deferred("_upnp_done", res, u)

func _upnp_done(res, u):
	upnp_thread.wait_to_finish(); upnp_thread = null
	if res.ok and str(res.ip) != "":
		upnp = u
		pub_addr = "%s:%d" % [res.ip, cfg.port]
		_log("The router opened the port: players anywhere connect to %s" % pub_addr)
	else:
		_log("The router didn't open UDP %d. Forward it by hand and start with --addr=<your public ip>, or players outside this network join through the relay." % cfg.port)
	announce_t = 0.0

func _ips():
	var out = []
	for ip in IP.get_local_addresses():
		if ip.find(":") >= 0 or ip.begins_with("127.") or ip.begins_with("169.254."): continue
		out.append(ip)
	return out

func _public(ip):
	var a = ip.split(".")
	if a.size() != 4: return false
	var b = int(a[1])
	return not (a[0] == "10" or (a[0] == "172" and b >= 16 and b <= 31) or (a[0] == "192" and a[1] == "168") or (a[0] == "100" and b >= 64 and b <= 127))

func _peer_in(id):
	enet[id] = { "name": "", "seen": G.REAL_T, "ok": false }

func _peer_out(id):
	var p = enet.get(id)
	if p != null and p.ok:
		_log("@%s left" % p.name)
		_relay_send("bye", {}, "e%d" % id)
	enet.erase(id); drop_at.erase(id)
	announce_t = min(announce_t, 1.0)

# a direct player's message (players connected directly see it already: ENet passes it on)
remote func msg(kind, d):
	if typeof(d) != TYPE_DICTIONARY or typeof(kind) != TYPE_STRING: return
	var from = get_tree().get_rpc_sender_id()
	var p = enet.get(from)
	if p == null: return
	p.seen = G.REAL_T
	if kind == "hi":
		if not p.ok: _admit_direct(from, d)
	elif not p.ok:
		return
	elif kind == "ev" and str(d.get("t", "")) == "chat":
		_log("@%s: %s" % [p.name, Net.clean_text(d.get("m", ""), 120)])
	elif kind == "ev" and str(d.get("t", "")) == "turf":
		_turf_in(d, p.name)
	if p.ok and kind in ["hi", "st", "ev"]:
		# across to the players on the relay
		var out = d.duplicate()
		if out.has("to") and str(out.to).begins_with("r"): out.to = str(out.to).substr(1)
		_relay_send(kind, out, "e%d" % from)

remote func fwd(_a, _b, _c):
	pass

func _admit_direct(id, d):
	var nm = Net.clean_text(d.get("name", "player"), 18)
	var pw = str(d.get("pw", ""))
	var why = ""
	if cfg.pw != "" and pw != Net.pw_hash(cfg.pw, sid) and pw != Net.pw_hash(cfg.pw, ""): why = "Wrong password"
	elif _count() >= cfg.max: why = "Server full"
	if why != "":
		_log("Turned away @%s: %s" % [nm, why])
		rpc_id(id, "msg", "ev", { "t": "kick", "why": why, "to": "e%d" % id, "q": _q() })
		drop_at[id] = G.REAL_T + 0.6
		return
	enet[id].ok = true; enet[id].name = nm
	_log("@%s joined (direct)" % nm)
	rpc_id(id, "msg", "ev", { "t": "welcome", "name": cfg.name, "motd": cfg.motd, "pvp": cfg.pvp, "max": cfg.max, "tf": turf, "to": "e%d" % id, "q": _q() })
	announce_t = min(announce_t, 1.0)

func _q():
	seq += 1
	return seq

func _count():
	var n = players.size()
	for p in enet.values():
		if p.ok: n += 1
	return n

func _relay_send(kind, d, as_id):
	if links.empty(): return
	var payload = JSON.print(d)
	for l in links: l.publish(Net.PREFIX + room + "/" + kind + "/" + as_id, payload)

func _brokers():
	var env = OS.get_environment("DS_BROKERS")
	if env != "": return env.split(",")
	return Net.BROKERS

func _fill():
	var list = _brokers()
	var alive = 0
	for l in links:
		if l.state != "dead": alive += 1
	var tries = 0
	while alive < 2 and tries < list.size():
		var url = list[broker_i % list.size()]
		broker_i += 1; tries += 1
		var dup = false
		for l in links:
			if l.url == url and l.state != "dead": dup = true
		if dup: continue
		var m = Net.Mqtt.new()
		m.url = url; m.owner = self
		m.client_id = "ds-" + sid + "-" + str(randi() % 9999)
		m.will_topic = Net.PREFIX + "servers/" + sid; m.will_msg = ""; m.will_retain = true
		m.subs = [Net.PREFIX + room + "/#"]
		m.start()
		links.append(m)
		alive += 1

func _process(dt):
	dt = min(dt, 0.25)
	G.REAL_T += dt
	for l in links: l.poll(dt)
	var any = false
	for l in links.duplicate():
		if l.state == "online": any = true
		elif l.state == "dead": links.erase(l)
	if any and not online:
		online = true; announce_t = 0.0
		_log("Online on the relay. Players anywhere can find this server in Online → Servers.")
	elif not any and online:
		online = false; _log("Lost the relay, reconnecting…")
	relay_t -= dt
	if relay_t <= 0:
		relay_t = 3.0; _fill()
	announce_t -= dt
	if online and announce_t <= 0:
		announce_t = 10.0; _announce()
	turf_t -= dt
	if turf_t <= 0:
		turf_t = 30.0
		if online: _send("ev", { "t": "turfmap", "m": turf })
		if peer:
			for id in enet.keys():
				if enet[id].ok: rpc_id(id, "msg", "ev", { "t": "turfmap", "m": turf, "q": _q() })
	for id in drop_at.keys():
		if G.REAL_T > drop_at[id]:
			drop_at.erase(id)
			if peer: peer.disconnect_peer(id)
	for id in players.keys():
		if G.REAL_T - players[id].seen > 15.0:
			_log("@%s left" % players[id].name)
			players.erase(id); announce_t = min(announce_t, 1.0)
	for k in seen.keys():
		if G.REAL_T - seen[k] > 30: seen.erase(k)
	status_t -= dt
	if status_t <= 0:
		status_t = 60.0
		print("[server] %d/%d players" % [_count(), cfg.max])
	if label:
		var where = ("direct " + (pub_addr if pub_addr != "" else lan_addr)) if peer else "relay only"
		label.text = "%s\n%d / %d players · %s · %s\n\n%s" % [cfg.name, _count(), cfg.max, "relay online" if online else "relay connecting…", where, PoolStringArray(log_lines).join("\n")]

func _announce():
	var d = { "n": cfg.name, "m": cfg.motd, "p": _count(), "x": cfg.max, "k": cfg.pw != "", "r": cfg.region, "d": true, "pvp": cfg.pvp,
		"h": "dedicated", "room": room, "v": Net.VERSION, "t": OS.get_unix_time(), "a": pub_addr if peer else "", "l": lan_addr if peer else "" }
	var payload = JSON.print(d)
	for l in links: l.publish(Net.PREFIX + "servers/" + sid, payload, true)

func _send(kind, d, to = ""):
	seq += 1
	d["q"] = seq
	if to != "": d["to"] = to
	var payload = JSON.print(d)
	for l in links: l.publish(Net.PREFIX + room + "/" + kind + "/" + sid, payload)

func _relay_in(topic, payload):
	var pre = Net.PREFIX + room + "/"
	if not topic.begins_with(pre): return
	var parts = topic.substr(pre.length()).split("/")
	if parts.size() != 2: return
	var kind = parts[0]
	var from = parts[1]
	if from == sid or not from.is_valid_identifier() or from.length() > 24: return
	if kind == "bye":
		if players.has(from):
			_log("@%s left" % players[from].name); players.erase(from); announce_t = min(announce_t, 1.0)
			_to_direct("bye", {}, from)
		return
	if from.begins_with("e") and from.substr(1).is_valid_integer(): return     # our own bridge, echoed back
	if payload.length() > 20000: return
	var d = parse_json(payload)
	if typeof(d) != TYPE_DICTIONARY: return
	if kind != "st":
		var k = from + kind + str(d.get("q", ""))
		if seen.has(k): return
		seen[k] = G.REAL_T
	if kind == "hi":
		if not players.has(from): _admit(from, d)
		elif players.has(from): players[from].seen = G.REAL_T
	elif kind == "st":
		if players.has(from): players[from].seen = G.REAL_T
	elif kind == "ev" and str(d.get("t", "")) == "chat" and players.has(from):
		_log("@%s: %s" % [players[from].name, Net.clean_text(d.get("m", ""), 120)])
	elif kind == "ev" and str(d.get("t", "")) == "turf" and players.has(from):
		_turf_in(d, players[from].name)
	if players.has(from): _to_direct(kind, d, from)

# across to the players connected directly (who see relay players as "r" + their id)
func _to_direct(kind, d, from):
	if peer == null: return
	var any = false
	for p in enet.values():
		if p.ok: any = true
	if not any: return
	if kind == "st": rpc_unreliable("fwd", "r" + from, kind, d)
	else: rpc("fwd", "r" + from, kind, d)

func _admit(from, p):
	var nm = Net.clean_text(p.get("name", "player"), 18)
	var why = ""
	if cfg.pw != "" and str(p.get("pw", "")) != Net.pw_hash(cfg.pw, sid): why = "Wrong password"
	elif players.size() >= cfg.max: why = "Server full"
	if why != "":
		if not rejected.has(from): _log("Turned away @%s: %s" % [nm, why])
		rejected[from] = true
		_send("ev", { "t": "kick", "why": why }, from)
		_send("ev", { "t": "reject", "who": from })
		return
	rejected.erase(from)
	players[from] = { "name": nm, "seen": G.REAL_T }
	_log("@%s joined" % nm)
	_send("ev", { "t": "welcome", "name": cfg.name, "motd": cfg.motd, "pvp": cfg.pvp, "max": cfg.max, "tf": turf }, from)
	announce_t = min(announce_t, 1.0)

# ---------- turf: the server keeps the map and saves it, so blocks stay taken across restarts
func _turf_path():
	return "user://turf_%s.json" % sid

func _turf_load():
	var f = File.new()
	if f.open(_turf_path(), File.READ) == OK:
		var m = Turf.clean_map(parse_json(f.get_as_text()))
		f.close()
		if m != null:
			turf = m
			return
	turf = Turf.default_map()

func _turf_save():
	var f = File.new()
	if f.open(_turf_path(), File.WRITE) == OK:
		f.store_string(JSON.print(turf)); f.close()

func _turf_in(d, who):
	var bv = d.get("b")
	if not typeof(bv) in [TYPE_INT, TYPE_REAL]: return
	var b = int(bv)
	if b < 0 or b >= Turf.N or b == Turf.COPS: return
	var o = Turf.clean_owner(d.get("o"))
	if o == null or Turf.same(turf[b], o): return
	turf[b] = o
	_turf_save()
	_log("@%s: block %d now %s" % [who, b, ("[%s] %s" % [o[2], o[1]]) if typeof(o) == TYPE_ARRAY else (o if o != "" else "nobody")])

func _open_log():
	var f = File.new()
	var paths = [OS.get_executable_path().get_base_dir().plus_file("servidor.log"), "user://servidor.log"]
	for p in paths:
		var mode = File.READ_WRITE if f.file_exists(p) else File.WRITE
		if f.open(p, mode) == OK:
			f.seek_end()
			log_file = f
			return

func _log(t):
	var line = "[%s] %s" % [_clock(), t]
	print(line)
	if log_file:
		log_file.store_line(line); log_file.flush()
	log_lines.append(line)
	while log_lines.size() > 22: log_lines.pop_front()

func _clock():
	var d = OS.get_time()
	return "%02d:%02d:%02d" % [d.hour, d.minute, d.second]

func _notification(what):
	if what == NOTIFICATION_WM_QUIT_REQUEST or what == NOTIFICATION_PREDELETE:
		for l in links:
			l.publish(Net.PREFIX + "servers/" + sid, "", true)
			l.close()
		if peer:
			for id in enet.keys():
				rpc_id(id, "msg", "ev", { "t": "closing", "q": _q() })
		if upnp != null: upnp.delete_port_mapping(cfg.port, "UDP")
		if log_file:
			log_file.close(); log_file = null
