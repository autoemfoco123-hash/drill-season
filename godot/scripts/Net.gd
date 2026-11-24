extends Node
# Online play between copies of the Godot version on Android, Linux, Windows and Mac.
#
# Servers: anyone can create a server (from the phone, or a dedicated one with --server, see
# Server.gd), and it shows up in the server list of every player in the world. The host
# announces it on the relay as a retained message (PREFIX + "servers/<id>"): name, players,
# slots, password or not, PvP, region, message of the day. Joining sends the password hash;
# the host answers with a welcome (or a kick: wrong password, full, banned). There is chat.
# Nobody opens ports: hosts and players all connect OUT to the relay below.
#
# Direct servers (1.9.1): a server created on a computer listens for players itself (ENet,
# UDP 24680), opens that port on the router on its own (UPnP), and lists its address next to
# its name, so players connect straight to it: quick, and it doesn't lean on the public
# relay for anything but the list. If the router won't open the port, the server runs on the
# relay instead, as before. Any server can also be joined by its address (ip:port), with no
# list and no relay at all. A dedicated server (Server.gd) takes both: players who connect
# directly and players on the relay, and passes their messages across, so they all meet.
#
# Two ways to connect, both carrying the same messages:
#  - Online (internet): every player connects OUT to public MQTT message brokers over a
#    secure WebSocket, and the brokers pass the game's messages around. Nobody hosts and
#    nobody opens ports. There is a public room, and private rooms with a short code you
#    share with friends. The game keeps two brokers connected at once, so one broker going
#    down (or being blocked on a network) doesn't drop you.
#  - Same Wi-Fi / direct IP: one player hosts with Godot's ENet (UDP 24680), the others
#    join by IP or pick the game from the list of games on the network.
#
# Everyone sees each other walk, drive, shoot, punch, dance and wear their fits; gangs can
# invite players, and gang members can't hurt each other. Messages from others are
# untrusted: everything is type-checked and clamped.

var main
const PORT = 24680
const LAN_PORT = 24681
const PREFIX = "drillseason/g1/"
const PUBLIC_ROOM = "calder"
const BROKERS = [
	"wss://broker.emqx.io:8084/mqtt", "wss://broker.hivemq.com:8884/mqtt", "wss://mqtt.eclipseprojects.io:443/mqtt",
	"tcp://broker.emqx.io:1883", "tcp://broker.hivemq.com:1883",
]
var mode = "off"            # off, relay, lan_host, lan_client
var status = "offline"      # offline, connecting, online
var note = ""
var room = PUBLIC_ROOM
var uid = ""
var links = []
var broker_i = 0
var relay_t = 0.0
var seq = 0
var peer = null             # ENet
var R = {}                  # remote id (String) -> Remote
var send_t = 0.0
var hello_t = 0.0
var lan = null
var lan_t = 0.0
var LAN = {}
var bcast = null
var invites = []
var seen_ev = {}
# servers
const VERSION = "1.1"
var servers = {}            # browser: sid -> info
var browsing = false
var server = null           # the server we are on: { sid, name, motd, max, pw, pvp, ded }
var hosting = false
var host_pw = ""
var announce_t = 0.0
var join_pw = ""
var welcomed = false
var welcome_t = 0.0
var rejected = {}           # ids the host turned away (everyone ignores them)
var kicked = {}             # host: id -> until
var chat = []               # [{ "n": name, "m": text }]
var chat_t = 0.0
var pub_addr = ""            # a direct server's address on the internet (ip:port), once the port is open
var lan_addr = ""            # and on its own network
var port_state = ""          # "", checking, open, closed
var upnp = null
var upnp_port = 0
var upnp_thread = null
const EMOTE_IDS = ["", "dance1", "dance2", "dance3", "hype", "clap", "laugh", "shrug", "salute", "point", "facepalm", "flex", "sit", "snowangel", "pray", "sturdy", "griddy", "shmoney", "woah", "hitfolks"]
const CAR_MODELS = ["hatch", "sedan", "suv", "pickup", "coupe", "van", "police", "taxi", "bruiser", "boulder"]

# ---------- a tiny MQTT 3.1.1 client (QoS 0) over a WebSocket or plain TCP ----------
class Mqtt extends Reference:
	var url = ""
	var ws = null
	var tcp = null
	var buf = PoolByteArray()
	var state = "connecting"    # connecting, online, dead
	var t = 0.0
	var ping_t = 0.0
	var owner
	var client_id = ""
	var will_topic = ""
	var will_msg = ""
	var will_retain = false
	var sub = ""
	var subs = []
	var sent_connect = false
	var host = ""

	func start():
		host = url.split("://")[1].split("/")[0].split(":")[0]
		if url.begins_with("tcp://"):
			var hp = url.substr(6).split(":")
			tcp = StreamPeerTCP.new()
			if tcp.connect_to_host(hp[0], int(hp[1]) if hp.size() > 1 else 1883) != OK: state = "dead"
		else:
			ws = WebSocketClient.new()
			ws.verify_ssl = true
			ws.connect("connection_established", self, "_ws_open")
			ws.connect("connection_closed", self, "_ws_closed")
			ws.connect("connection_error", self, "_ws_error")
			if ws.connect_to_url(url, PoolStringArray(["mqtt"])) != OK: state = "dead"

	func _ws_open(_proto):
		ws.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_BINARY)
		_send_connect()
	func _ws_closed(_clean): state = "dead"
	func _ws_error(): state = "dead"

	func close():
		if state == "online": _send(PoolByteArray([0xE0, 0]))
		state = "dead"
		if ws: ws.disconnect_from_host()
		if tcp: tcp.disconnect_from_host()

	static func _rl(n):
		var out = PoolByteArray()
		while true:
			var b = n % 128
			n = n / 128
			if n > 0: b |= 128
			out.append(b)
			if n == 0: break
		return out

	static func _str(s):
		var u = s.to_utf8()
		var out = PoolByteArray([u.size() >> 8, u.size() & 255])
		out.append_array(u)
		return out

	func _packet(head, body):
		var out = PoolByteArray([head])
		out.append_array(_rl(body.size()))
		out.append_array(body)
		return out

	func _send(bytes):
		if ws:
			if ws.get_peer(1).is_connected_to_host(): ws.get_peer(1).put_packet(bytes)
		elif tcp and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			tcp.put_data(bytes)

	func _send_connect():
		if sent_connect: return
		sent_connect = true
		var vh = _str("MQTT")
		vh.append(4)            # protocol level 3.1.1
		# clean session; a will (QoS 0) if there is one, retained for a host's listing
		vh.append(0x02 | ((0x04 | (0x20 if will_retain else 0)) if will_topic != "" else 0))
		vh.append(0); vh.append(45)   # keep alive 45 s
		var body = vh
		body.append_array(_str(client_id))
		if will_topic != "":
			body.append_array(_str(will_topic))
			body.append_array(_str(will_msg))
		_send(_packet(0x10, body))

	func subscribe(topic):
		var body = PoolByteArray([0, 1])
		body.append_array(_str(topic))
		body.append(0)
		_send(_packet(0x82, body))

	func publish(topic, payload, retain = false):
		if state != "online": return
		var body = _str(topic)
		body.append_array(payload.to_utf8())
		_send(_packet(0x31 if retain else 0x30, body))

	func add_sub(topic):
		if topic in subs: return
		subs.append(topic)
		if state == "online": subscribe(topic)

	func poll(dt):
		if state == "dead": return
		t += dt
		if ws:
			ws.poll()
			var p = ws.get_peer(1)
			while p.get_available_packet_count() > 0:
				buf.append_array(p.get_packet())
		elif tcp:
			var st = tcp.get_status()
			if st == StreamPeerTCP.STATUS_CONNECTED:
				_send_connect()
				var n = tcp.get_available_bytes()
				if n > 0:
					var r = tcp.get_partial_data(n)
					if r[0] == OK: buf.append_array(r[1])
			elif st == StreamPeerTCP.STATUS_ERROR or (st == StreamPeerTCP.STATUS_NONE and sent_connect):
				state = "dead"
		_parse()
		if state == "connecting" and t > 12: state = "dead"
		if state == "online":
			ping_t -= dt
			if ping_t <= 0:
				ping_t = 20.0; _send(PoolByteArray([0xC0, 0]))

	func _parse():
		while buf.size() >= 2:
			var mul = 1
			var n = 0
			var i = 1
			var ok = false
			while i < buf.size() and i <= 4:
				var b = buf[i]
				n += (b & 127) * mul
				mul *= 128
				i += 1
				if b & 128 == 0:
					ok = true; break
			if not ok: return
			if buf.size() < i + n: return
			var head = buf[0]
			var body = buf.subarray(i, i + n - 1) if n > 0 else PoolByteArray()
			buf = buf.subarray(i + n, buf.size() - 1) if buf.size() > i + n else PoolByteArray()
			var kind = head >> 4
			if kind == 2:
				if body.size() >= 2 and body[1] == 0:
					state = "online"; ping_t = 20.0
					if sub != "": subscribe(sub)
					for s in subs: subscribe(s)
				else:
					state = "dead"
			elif kind == 3:
				var tl = (body[0] << 8) | body[1]
				var topic = body.subarray(2, 1 + tl).get_string_from_utf8()
				var off = 2 + tl + (2 if (head >> 1) & 3 > 0 else 0)
				var payload = body.subarray(off, body.size() - 1).get_string_from_utf8() if body.size() > off else ""
				owner._relay_in(topic, payload)

class Remote:
	var main
	var id = ""
	var name = "player"
	var skin = {}
	var gang = null
	var h = null
	var pos = Vector3()
	var tpos = Vector3()
	var tvel = Vector3()
	var yaw = 0.0
	var tyaw = 0.0
	var st = {}
	var st_q = -1
	var car = null
	var car_key = ""
	var crouched = false
	var t = 0.0
	var dmg_t = 0.0
	var dmg_acc = 0.0
	var has_hello = false
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
	uid = _load_uid()

func _load_uid():
	var f = File.new()
	var p = "user://net_id.txt"
	if f.open(p, File.READ) == OK:
		var s = f.get_as_text().strip_edges(); f.close()
		if s.length() >= 8 and s.length() <= 24 and s.is_valid_identifier(): return s
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var s2 = "g"
	for _i in range(13): s2 += chars[rng.randi_range(0, chars.length() - 1)]
	if f.open(p, File.WRITE) == OK:
		f.store_string(s2); f.close()
	return s2

func online(): return status == "online"
func room_label(): return "PUBLIC" if room == PUBLIC_ROOM else room.to_upper()

func clean_room(code):
	var out = ""
	for ch in str(code).to_lower():
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789": out += ch
	return out.substr(0, 20)

func new_room_code():
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var chars = "abcdefghjkmnpqrstuvwxyz23456789"
	var s = ""
	for _i in range(5): s += chars[rng.randi_range(0, chars.length() - 1)]
	return s

# ---------- online through the brokers ----------
func go_online(code = PUBLIC_ROOM):
	leave(true)
	_connect_room(code)

func _connect_room(code):
	for l in links: l.close()
	links.clear()
	code = clean_room(code)
	if code == "": code = PUBLIC_ROOM
	room = code
	mode = "relay"; status = "connecting"; broker_i = 0; relay_t = 0
	note = "Connecting to the online relay…"
	_fill_links()

func _topics():
	var t = []
	if mode == "relay": t.append(PREFIX + room + "/#")
	if browsing or mode == "browse" or hosting: t.append(PREFIX + "servers/+")
	return t

func _broker_list():
	var env = OS.get_environment("DS_BROKERS")
	if env != "": return env.split(",")
	return BROKERS

func _fill_links():
	var list = _broker_list()
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
		var m = Mqtt.new()
		m.url = url; m.owner = self
		m.client_id = "ds-" + uid + "-" + str(randi() % 9999)
		if hosting:
			# if this game drops, the broker takes the server off the list
			m.will_topic = PREFIX + "servers/" + server.sid; m.will_msg = ""; m.will_retain = true
		elif mode == "relay":
			m.will_topic = PREFIX + room + "/bye/" + uid; m.will_msg = "{}"
		m.subs = _topics()
		m.start()
		links.append(m)
		alive += 1

func _relay_poll(dt):
	for l in links: l.poll(dt)
	var any = false
	var names = []
	for l in links.duplicate():
		if l.state == "online":
			any = true; names.append(l.host)
		elif l.state == "dead":
			links.erase(l)
	relay_t -= dt
	if relay_t <= 0:
		relay_t = 3.0
		_fill_links()
	if mode == "lan_host":
		return       # a direct server: the relay only carries its listing; players reach it on its port
	if any and status != "online":
		status = "online"
		if mode == "relay":
			if server == null: main.hud.banner("Online", "Room " + room_label())
			elif hosting: main.hud.banner(server.name, "Your server is online")
			_send("hi", _profile())
			if hosting: announce_t = 0.0
	elif not any and status == "online":
		status = "connecting"
	if any: note = "Connected via " + PoolStringArray(names).join(" + ")
	elif links.size() == 0: note = "Can't reach the online relay. Check the internet connection."

func _relay_in(topic, payload):
	if topic.begins_with(PREFIX + "servers/"):
		_server_info(topic.substr((PREFIX + "servers/").length()), payload)
		return
	if mode != "relay" or not topic.begins_with(PREFIX + room + "/"): return
	var parts = topic.substr(PREFIX.length() + room.length() + 1).split("/")
	if parts.size() != 2: return
	var kind = parts[0]
	var from = parts[1]
	if from == uid or not from.is_valid_identifier() or from.length() > 24: return
	if kind == "bye":
		_remove("r" + from); return
	if rejected.has("r" + from) and kind != "ev": return
	if payload.length() > 20000: return
	var d = parse_json(payload)
	if typeof(d) != TYPE_DICTIONARY: return
	# both brokers deliver the same message: drop repeats
	if kind != "st":
		var k = from + kind + str(d.get("q", ""))
		if seen_ev.has(k): return
		seen_ev[k] = G.REAL_T
	_on_msg("r" + from, kind, d)

func _send(kind, d, to = ""):
	seq += 1
	d["q"] = seq
	if to != "": d["to"] = to
	if mode == "relay":
		var topic = PREFIX + room + "/" + kind + "/" + uid
		var payload = JSON.print(d)
		for l in links: l.publish(topic, payload)
	elif peer != null and online():
		if to != "" and to.begins_with("e"):
			rpc_id(int(to.substr(1)), "msg", kind, d)
		elif kind == "st":
			rpc_unreliable("msg", kind, d)
		else:
			rpc("msg", kind, d)

# ---------- same Wi-Fi / direct IP (ENet) ----------
func host(port = PORT):
	leave(true)
	peer = NetworkedMultiplayerENet.new()
	if peer.create_server(port, 8) != OK:
		note = "Could not host on port %d (is another copy of the game using it?)" % port; peer = null; return false
	get_tree().network_peer = peer
	mode = "lan_host"; status = "online"; room = "lan"
	note = "Hosting on port %d. Players on the same Wi-Fi see you under Games nearby." % port
	bcast = PacketPeerUDP.new(); bcast.set_broadcast_enabled(true)
	bcast.set_dest_address("255.255.255.255", LAN_PORT)
	main.hud.banner("Hosting", "Port %d" % port)
	return true

func join(ip, port = PORT):
	leave(true)
	ip = str(ip).strip_edges()
	if ip == "":
		note = "Type the host's IP address."; return false
	peer = NetworkedMultiplayerENet.new()
	if peer.create_client(ip, int(port)) != OK:
		note = "Could not reach %s" % ip; peer = null; return false
	get_tree().network_peer = peer
	mode = "lan_client"; status = "connecting"; room = "lan"
	note = "Joining %s …" % ip
	return true

remote func msg(kind, d):
	if typeof(d) != TYPE_DICTIONARY or typeof(kind) != TYPE_STRING: return
	var from = get_tree().get_rpc_sender_id()
	if kind == "ev" and d.has("to") and d.to != "e" + str(get_tree().get_network_unique_id()): return
	_on_msg("e" + str(from), kind, d)

func _on_connected():
	status = "online"; note = "Connected."
	main.hud.banner("Online", "Connected to the host")

func _on_failed():
	status = "offline"; note = "Could not connect. Check the address, and that the server's UDP port is open."
	if server != null:
		main.hud.banner("Couldn't reach the server", server.name)
		server = null; welcomed = false
	call_deferred("_drop_peer")

func _drop_peer():
	get_tree().network_peer = null; peer = null; mode = "off"

func _on_server_gone():
	main.hud.banner("Host left", "Back to playing solo")
	call_deferred("leave")

func _on_peer(id):
	rpc_id(id, "msg", "hi", _profile())

func _on_peer_gone(id):
	_remove("e" + str(id))

# ---------- leaving ----------
func leave(quiet = false):
	for id in R.keys(): _remove(id)
	if hosting and server != null and server.get("direct", false) and peer != null:
		_send("ev", { "t": "closing" })            # straight to the players on our port
	if mode == "relay" or mode == "browse" or links.size() > 0:
		for l in links:
			if hosting:
				if mode == "relay": _send("ev", { "t": "closing" })
				l.publish(PREFIX + "servers/" + server.sid, "", true)
			if mode == "relay": l.publish(PREFIX + room + "/bye/" + uid, "{}")
			l.close()
	links.clear()
	_close_port()
	if peer:
		peer.close_connection()
		get_tree().network_peer = null
	peer = null; bcast = null
	if status != "offline" and not quiet and mode == "relay": main.hud.toast("Left the online game")
	status = "offline"; mode = "off"
	server = null; hosting = false; host_pw = ""; join_pw = ""; welcomed = false
	rejected.clear(); chat.clear()

# ---------- what players tell each other ----------
func _profile():
	var g = G.S.get("gang")
	var p = { "name": str(G.S["name"]).substr(0, 18), "skin": G.S["skin"], "gang": [str(g.id), g.name, g.tag, int(g.color)] if typeof(g) == TYPE_DICTIONARY else null }
	if server != null and not hosting:
		p["srv"] = server.sid; p["v"] = VERSION
		if join_pw != "": p["pw"] = pw_hash(join_pw, server.sid)
	return p

func _on_msg(id, kind, d):
	# a host only listens to players it has let in (their hello carries the password)
	if hosting and kind != "hi" and not R.has(id) and not (kind == "ev" and str(d.get("t", "")) == "chat"): return
	if kind == "hi": _hello(id, d)
	elif kind == "st": _state(id, d)
	elif kind == "ev": _event(id, d)

func _remote(id):
	var r = R.get(id)
	if r == null:
		r = Remote.new(); r.main = main; r.id = id
		R[id] = r
	return r

func _hello(id, p):
	if hosting and not R.has(id) and not _admit(id, p): return
	if not hosting and mode == "lan_host" and p.has("srv") and not R.has(id):
		_send("ev", { "t": "welcome", "name": "@%s's game" % str(G.S["name"]).substr(0, 18), "motd": "", "pvp": true, "max": 8 }, _to(id))
	var r = _remote(id)
	var first = not r.has_hello
	r.has_hello = true
	var nm = ""
	for ch in str(p.get("name", "player")):
		if ch.is_valid_identifier() or ch in "0123456789.-_": nm += ch
	r.name = nm.substr(0, 18) if nm != "" else "player"
	r.gang = p.get("gang") if typeof(p.get("gang")) == TYPE_ARRAY and p.gang.size() >= 4 else null
	var skin = p.get("skin", {})
	if typeof(skin) != TYPE_DICTIONARY: skin = {}
	if r.h == null or JSON.print(skin) != JSON.print(r.skin): _build(r, skin)
	if first:
		main.hud.toast("@%s is on the block" % r.name)
		main.sfx.play("notif", 0.4)
		_send("hi", _profile())    # so they know us too

func _build(r, skin):
	r.skin = skin
	var old = r.h
	r.h = load("res://scripts/Human.gd").new().build(G.skin_opts(G.clean_skin(skin)))
	main.add_child(r.h)
	r.h.translation = r.pos
	if old: old.queue_free()

func _num(v, lo, hi):
	var f = float(v) if typeof(v) in [TYPE_REAL, TYPE_INT] else 0.0
	return clamp(f, lo, hi)

func _state(id, s):
	var r = _remote(id)
	var q = int(s.get("q", 0))
	if q <= r.st_q and r.st_q - q < 100000: return
	r.st_q = q
	r.st = s; r.t = 0.0
	if r.h == null: _build(r, {})
	r.tpos = Vector3(_num(s.get("x"), -300, 300), _num(s.get("y"), -5, 60), _num(s.get("z"), -300, 300))
	r.tvel = Vector3(_num(s.get("vx"), -60, 60), 0, _num(s.get("vz"), -60, 60))
	r.tyaw = _num(s.get("yaw"), -100, 100)
	if r.pos == Vector3() or r.pos.distance_to(r.tpos) > 12: r.pos = r.tpos
	if not r.has_hello and randf() < 0.1: _send("hi", _profile())

func _event(id, e):
	var me = uid if mode == "relay" else "e" + str(get_tree().get_network_unique_id() if peer else 0)
	var to = str(e.get("to", ""))
	var r = R.get(id)
	var t = str(e.get("t", ""))
	if t == "shot":
		var a = e.get("a")
		var b = e.get("b")
		if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == 3 and b.size() == 3:
			var va = Vector3(_num(a[0], -300, 300), _num(a[1], -5, 60), _num(a[2], -300, 300))
			var vb = Vector3(_num(b[0], -300, 300), _num(b[1], -5, 60), _num(b[2], -300, 300))
			if r == null or va.distance_to(r.pos) < 10:
				main.sfx.tracer(va, vb)
				main.sfx.shot(str(e.get("k", "k9")) if str(e.get("k", "")) in GUN.IDS else "k9", va, 0.8)
				main.sfx.flash(va)
		return
	if t == "chat":
		var m = clean_chat(e.get("m", ""))
		if m == "" or rejected.has(id): return
		var nm = r.name if r else "server"
		_chat_line(nm, m)
		return
	var from_host = server != null and (id == "r" + server.sid or (server.get("direct", false) and id == "e1"))
	if t == "turf" or t == "turfmap" or t == "turfhit":
		if rejected.has(id): return
		if main.turf: main.turf.net_event(t, r, from_host, e)
		return
	if t == "reject" and from_host:
		var w = str(e.get("who", ""))
		var who = w if w.begins_with("e") else "r" + w
		if who != "r" + uid:
			rejected[who] = true; _remove(who)
		return
	if t == "closing" and from_host and not hosting:
		var nm2 = server.name
		leave(true)
		main.hud.banner("Server closed", nm2)
		return
	if to != me: return
	if t == "welcome" and from_host:
		welcomed = true
		server.name = clean_text(e.get("name", server.name), 32)
		server.motd = clean_text(e.get("motd", ""), 120)
		server.pvp = e.get("pvp", true) == true
		server.max = int(_num(e.get("max", 16), 2, 64))
		if main.turf: main.turf.load_map(e.get("tf"))
		main.hud.banner(server.name, server.motd if server.motd != "" else "Welcome")
		main.sfx.play("notif", 0.5)
		return
	if t == "kick" and from_host:
		var why = clean_text(e.get("why", "Kicked"), 60)
		leave(true)
		main.hud.banner("Can't stay on this server", why)
		return
	if t == "hurt" and r:
		if server != null and not server.pvp: return
		if _same_gang(r): return
		# the most anyone can take off you per second, whatever they send
		if G.REAL_T - r.dmg_t > 1.0:
			r.dmg_t = G.REAL_T; r.dmg_acc = 0.0
		var dmg = min(_num(e.get("dmg"), 0, 60), max(0.0, 45.0 - r.dmg_acc))
		r.dmg_acc += dmg
		if dmg <= 0: return
		var P = main.player
		var was = G.S["health"]
		if e.get("melee", false): P.take_punch(dmg, r.pos)
		else: P.hurt(dmg, r.pos)
		if was > 0 and G.S["health"] <= 0:
			_send("ev", { "t": "dropped", "who": str(G.S["name"]) }, id_for_send(r))
			main.hud.toast("@%s dropped you" % r.name)
	elif t == "dropped":
		G.S["stats"]["pvpDowns"] = int(G.S["stats"].get("pvpDowns", 0)) + 1
		main.hud.banner("You dropped @" + (r.name if r else "someone"), "")
	elif t == "inv":
		var g = e.get("g")
		if typeof(g) != TYPE_ARRAY or g.size() < 4: return
		invites.append({ "from": id, "g": g })
		main.hud.toast("@%s invited you to [%s] %s. Phone → Online to accept." % [r.name if r else "someone", str(g[2]).substr(0, 4), str(g[1]).substr(0, 18)])
	elif t == "joined":
		main.hud.toast("@%s joined the gang" % (r.name if r else "someone"))
		main.gang.rep(2)

# turf (Turf.gd): who holds which block on this server
func send_turf(b, o):
	if online(): _send("ev", { "t": "turf", "b": b, "o": o })
func send_turfmap(m):
	if online(): _send("ev", { "t": "turfmap", "m": m })
func send_turfhit(b, o):
	if online(): _send("ev", { "t": "turfhit", "b": b, "o": o, "g": main.turf.my_gang() })

func id_for_send(r):
	return r.id.substr(1)  if mode == "relay" else r.id

func invite(id):
	var g = G.S.get("gang")
	var r = R.get(id)
	if typeof(g) != TYPE_DICTIONARY or r == null or not online(): return
	_send("ev", { "t": "inv", "g": [str(g.id), g.name, g.tag, int(g.color)] }, id_for_send(r))
	main.hud.toast("Invite sent to @" + r.name)

func accept_invite(i):
	if i < 0 or i >= invites.size(): return
	var inv = invites[i]
	invites.remove(i)
	var g = inv.g
	if not main.gang.text_ok(str(g[1])) or not main.gang.text_ok(str(g[2])): return
	var from = R.get(inv.from)
	G.S["gang"] = { "id": str(g[0]).substr(0, 12), "name": str(g[1]).substr(0, 18), "tag": str(g[2]).substr(0, 4), "color": int(g[3]) % G.D["GANG_COLORS"].size(), "role": "member",
		"leader": from.name if from else "", "rep": 0, "created": OS.get_unix_time() * 1000 }
	main.hud.banner("[%s] %s" % [G.S["gang"].tag, G.S["gang"].name], "You joined the gang")
	if online():
		_send("hi", _profile())
		if from: _send("ev", { "t": "joined" }, id_for_send(from))

func _same_gang(r):
	var g = G.S.get("gang")
	return typeof(g) == TYPE_DICTIONARY and typeof(r.gang) == TYPE_ARRAY and str(r.gang[0]) == str(g.id)

func hit_remote(r, dmg, _head, melee):
	if _same_gang(r):
		main.hud.toast("Same gang. No friendly fire."); return
	if server != null and not server.pvp:
		main.hud.toast("PvP is off on this server"); return
	main.sfx.blood(r.pos + Vector3(0, 1.3, 0), Vector3())
	_send("ev", { "t": "hurt", "dmg": dmg, "melee": melee }, id_for_send(r))

func send_shot(a, b):
	if online():
		_send("ev", { "t": "shot", "a": [stepify(a.x, 0.01), stepify(a.y, 0.01), stepify(a.z, 0.01)], "b": [stepify(b.x, 0.01), stepify(b.y, 0.01), stepify(b.z, 0.01)], "k": G.S["cur"] })

func profile_changed():
	if online(): _send("hi", _profile())

func targets():
	var out = []
	for r in R.values():
		if r.h and not r.st.get("car", false): out.append(r)
	return out

# ---------- every frame ----------
func update(dt):
	_lan(dt)
	if mode == "relay" or mode == "browse" or (hosting and links.size() > 0): _relay_poll(dt)
	for k in seen_ev.keys():
		if G.REAL_T - seen_ev[k] > 30: seen_ev.erase(k)
	for sid in servers.keys():
		if G.REAL_T - servers[sid].seen > 45: servers.erase(sid)
	chat_t = max(0.0, chat_t - dt)
	if not online() or mode == "browse": return
	if hosting:
		announce_t -= dt
		if announce_t <= 0:
			announce_t = 10.0
			_announce()
	elif server != null and not welcomed:
		welcome_t -= dt
		if welcome_t <= 0:
			var nm = server.name
			leave(true)
			main.hud.banner("The server didn't answer", nm)
			return
	if G.MODE != "title":
		send_t -= dt
		if send_t <= 0:
			send_t = 0.125 if mode == "relay" else 0.08
			_send("st", _my_state())
		hello_t -= dt
		if hello_t <= 0:
			hello_t = 8.0
			_send("hi", _profile())
	for r in R.values():
		_update_remote(r, dt)

func _my_state():
	var P = main.player
	var s = { "x": stepify(P.pos.x, 0.01), "y": stepify(P.pos.y, 0.01), "z": stepify(P.pos.z, 0.01), "vx": stepify(P.vel.x, 0.1), "vz": stepify(P.vel.z, 0.1),
		"yaw": stepify(P.body_yaw, 0.01), "sp": stepify(P.speed, 0.1), "cr": P.crouch, "aim": stepify(P.aim_t, 0.1), "pitch": stepify(P.cam_pitch, 0.01), "lk": stepify(G.ang_diff(P.body_yaw, P.cam_yaw + PI), 0.05), "air": not P.on_ground,
		"fists": G.S.get("fists", false), "punch": stepify(P.punch_t / P.punch_dur, 0.05) if P.punch_t > 0 else 0.0, "ps": P.punch_side, "flip": P.flipping(), "wave": P.wave_t > 0,
		"em": EMOTE_IDS.find(P.emote_name), "et": stepify(P.emote_t, 0.1), "down": P.is_ragdoll() or P.dead, "gun": G.S["cur"], "hands": P.hands_up > 0 }
	if P.car:
		s["car"] = true; s["cm"] = CAR_MODELS.find(P.car.model); s["cc"] = int(P.car.color)
		s["cx"] = stepify(P.car.pos.x, 0.01); s["cz"] = stepify(P.car.pos.z, 0.01); s["cy"] = stepify(P.car.yaw, 0.01); s["cs"] = stepify(P.car.speed, 0.1)
	return s

func _update_remote(r, dt):
	r.t += dt
	if r.h == null: return
	var s = r.st
	if r.t > 12:
		_remove(r.id); return
	var k = 1 - exp(-dt * 10)
	# aim a little ahead along their velocity to hide the relay's delay
	var ahead = r.tpos + r.tvel * min(r.t, 0.25)
	r.pos = r.pos.linear_interpolate(ahead, k)
	r.yaw += G.ang_diff(r.yaw, r.tyaw) * k
	if s.get("car", false):
		r.h.visible = false
		var cm = int(_num(s.get("cm"), 0, CAR_MODELS.size() - 1))
		var model = CAR_MODELS[cm]
		var key = model + str(s.get("cc", 0))
		if r.car == null or r.car.dead or r.car_key != key:
			if r.car: main.vehicles.remove(r.car)
			r.car = main.vehicles.spawn(model, _num(s.get("cx"), -300, 300), _num(s.get("cz"), -300, 300), _num(s.get("cy"), -100, 100), { "owned": false, "color": int(_num(s.get("cc", 0), 0, 0xffffff)), "locked": true })
			if r.car: r.car.driver = "remote"
			r.car_key = key
		if r.car:
			var cs = _num(s.get("cs"), -60, 60)
			var cy = _num(s.get("cy"), -100, 100)
			var tp = Vector3(_num(s.get("cx"), -300, 300), 0, _num(s.get("cz"), -300, 300)) + Vector3(sin(cy), 0, cos(cy)) * cs * min(r.t, 0.25)
			r.car.pos = r.car.pos.linear_interpolate(tp, k) if r.car.pos.distance_to(tp) < 15 else tp
			r.car.yaw += G.ang_diff(r.car.yaw, cy) * k
			r.car.speed = cs
			main.vehicles.place(r.car)
			var so = G.skin_opts(r.skin)
			main.vehicles.flip_arm(r.car, s.get("flip", false) == true, G.hex_color(so.skin), G.hex_color(so.jacket), dt)
			r.pos = r.car.pos
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
	var em = int(_num(s.get("em", 0), 0, EMOTE_IDS.size() - 1))
	r.crouched = s.get("cr", false) == true
	r.h.animate(dt, { "speed": _num(s.get("sp"), 0, 20), "crouch": 1.0 if r.crouched else 0.0, "aim": 0.0 if s.get("fists", false) else _num(s.get("aim"), 0, 1), "pitch": _num(s.get("pitch"), -1.5, 1.5),
		"look": _num(s.get("lk"), -3.2, 3.2), "air": s.get("air", false) == true,
		"fists": s.get("fists", false) == true, "guard": s.get("fists", false) == true and _num(s.get("aim"), 0, 1) > 0.5, "punch": _num(s.get("punch"), 0, 1), "punchSide": -1 if _num(s.get("ps"), -1, 1) < 0 else 1,
		"flip": s.get("flip", false) == true, "wave": s.get("wave", false) == true, "hands": s.get("hands", false) == true, "twoHand": str(s.get("gun", "k9")) != "k9",
		"emote": EMOTE_IDS[em], "et": _num(s.get("et"), 0, 999), "down": 1.0 if EMOTE_IDS[em] == "snowangel" else 0.0 })

func _remove(id):
	var r = R.get(id)
	if r == null: return
	if hosting: announce_t = min(announce_t, 1.0)
	if r.h: r.h.queue_free()
	if r.car: main.vehicles.remove(r.car)
	R.erase(id)
	main.hud.toast("@%s left" % r.name)

# ---------- games on the same network ----------
func lan_listen(on):
	if on and lan == null:
		lan = PacketPeerUDP.new()
		if lan.listen(LAN_PORT) != OK: lan = null
	elif not on and lan:
		lan.close(); lan = null

func _lan(dt):
	lan_t -= dt
	if mode == "lan_host" and bcast and lan_t <= 0:
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

# ---------- servers ----------
static func pw_hash(pw, sid):
	return (str(pw) + ":" + str(sid) + ":drillseason").sha256_text().substr(0, 20)

static func clean_text(v, n):
	var out = ""
	for ch in str(v):
		if ch.ord_at(0) >= 32 and ch != "\\": out += ch
	return out.strip_edges().substr(0, n)

func clean_chat(v):
	var m = clean_text(v, 120)
	return m

func region():
	var loc = OS.get_locale()
	var parts = loc.split("_")
	return (parts[1] if parts.size() > 1 else parts[0]).to_upper().substr(0, 3)

# the server list: start or stop listening for servers (and connect just for that if offline)
func browse(on):
	browsing = on
	if on:
		if mode == "off":
			mode = "browse"; status = "connecting"; broker_i = 0; relay_t = 0
			note = "Looking for servers…"
			_fill_links()
		else:
			for l in links: l.add_sub(PREFIX + "servers/+")
	elif mode == "browse":
		for l in links: l.close()
		links.clear()
		status = "offline"; mode = "off"

func _server_info(sid, payload):
	if not sid.is_valid_identifier() or sid.length() > 24: return
	if payload == "":
		servers.erase(sid); return
	if payload.length() > 2000: return
	var d = parse_json(payload)
	if typeof(d) != TYPE_DICTIONARY: return
	if OS.get_unix_time() - int(_num(d.get("t", 0), 0, 4.0e9)) > 120: return   # left behind by a crashed host
	var rm = clean_room(d.get("room", ""))
	if rm == "": return
	servers[sid] = { "sid": sid, "name": clean_text(d.get("n", "Server"), 32), "motd": clean_text(d.get("m", ""), 120), "p": int(_num(d.get("p", 1), 0, 64)),
		"x": int(_num(d.get("x", 16), 2, 64)), "k": d.get("k", false) == true, "r": clean_text(d.get("r", ""), 3), "d": d.get("d", false) == true,
		"pvp": d.get("pvp", true) == true, "h": clean_text(d.get("h", ""), 18), "room": rm, "v": clean_text(d.get("v", ""), 8), "seen": G.REAL_T,
		"a": clean_addr(d.get("a", "")), "l": clean_addr(d.get("l", "")) }

func server_list():
	var out = servers.values()
	out.sort_custom(self, "_by_players")
	return out

func _by_players(a, b):
	if a.d != b.d: return a.d
	return a.p > b.p

# create a server. Direct (the default on a computer): this game listens for players itself
# and opens its port on the router (UPnP); if the router won't, it moves to the relay. Relay:
# hosted through the public relay, like before. Keep it open; leaving closes the server.
func host_server(cfg):
	leave(true)
	hosting = true
	host_pw = str(cfg.get("pw", "")).substr(0, 32)
	server = { "sid": uid, "name": clean_text(cfg.get("name", "Server"), 32), "motd": clean_text(cfg.get("motd", ""), 120), "max": int(clamp(int(cfg.get("max", 16)), 2, 64)),
		"pw": host_pw != "", "pvp": cfg.get("pvp", true) == true, "ded": false, "direct": false }
	welcomed = true
	if main.turf: main.turf.new_server_map()
	if cfg.get("direct", false) and _listen(int(cfg.get("port", PORT)), server.max):
		server.direct = true
		room = "direct"
		var ips = my_ips()
		lan_addr = ("%s:%d" % [ips[0], upnp_port]) if ips.size() > 0 else ""
		note = "Opening port %d on your router…" % upnp_port
		_open_port(upnp_port)
		_fill_links()         # the relay only carries the listing
		main.hud.banner(server.name, "Your server is online")
		return
	_connect_room("s" + uid)

func _listen(port, mx):
	peer = NetworkedMultiplayerENet.new()
	if peer.create_server(port, mx + 2) != OK:
		peer = null
		note = "Port %d is busy, hosting through the relay instead." % port
		return false
	get_tree().network_peer = peer
	mode = "lan_host"; status = "online"
	upnp_port = port
	bcast = PacketPeerUDP.new(); bcast.set_broadcast_enabled(true)
	bcast.set_dest_address("255.255.255.255", LAN_PORT)
	return true

# the router: ask it to forward the port to us (in a thread: finding it takes a second or two)
func _open_port(port):
	port_state = "checking"
	if OS.get_environment("DS_FAKEUPNP") != "":          # tests: pretend the router said yes
		_upnp_done({ "ok": true, "ip": OS.get_environment("DS_FAKEUPNP") }, null, port); return
	if not ClassDB.class_exists("UPNP") or OS.get_environment("DS_NOUPNP") != "":
		_upnp_done({ "ok": false, "ip": "" }, null, port); return
	upnp_thread = Thread.new()
	upnp_thread.start(self, "_upnp_job", port)

func _upnp_job(port):
	var u = UPNP.new()
	var res = { "ok": false, "ip": "" }
	if u.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		if u.add_port_mapping(port, port, "Drill Season", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS:
			res.ok = true
			res.ip = u.query_external_address()
	call_deferred("_upnp_done", res, u, port)

func _upnp_done(res, u, port):
	if upnp_thread:
		upnp_thread.wait_to_finish(); upnp_thread = null
	if not hosting or server == null: return
	if res.ok and str(res.ip) != "":
		upnp = u
		pub_addr = "%s:%d" % [res.ip, port]
		port_state = "open"
		note = "Port %d is open: players anywhere connect straight to you (%s)." % [port, pub_addr]
		announce_t = 0.0
	else:
		port_state = "closed"
		# nobody outside this network could reach us: host on the relay instead
		var cfg = { "name": server.name, "motd": server.motd, "pw": host_pw, "max": server.max, "pvp": server.pvp, "direct": false }
		host_server(cfg)
		note = "Your router didn't open port %d, so the server runs through the relay (works anywhere, a bit slower)." % port

func _close_port():
	if upnp != null and upnp_port > 0:
		upnp.delete_port_mapping(upnp_port, "UDP")
	upnp = null
	pub_addr = ""; lan_addr = ""; port_state = ""

func join_server(sid, pw = ""):
	var info = servers.get(sid)
	if info == null: return false
	var srv = { "sid": sid, "name": info.name, "motd": info.motd, "max": info.x, "pw": info.k, "pvp": info.pvp, "ded": info.d }
	# a direct server: straight to it (its own network's address if we're on that network)
	var addr = info.get("a", "")
	var la = info.get("l", "")
	if la != "" and _same_net(la.split(":")[0]): addr = la
	if addr != "":
		return join_addr(addr, pw, srv)
	leave(true)
	server = srv
	join_pw = str(pw)
	welcomed = false; welcome_t = 12.0
	_connect_room(info.room)
	return true

# join any server by its address (ip or ip:port), listed or not
func join_addr(addr, pw = "", srv = null):
	addr = clean_addr(str(addr).strip_edges())
	if addr == "":
		note = "Type the server's address, like 203.0.113.5:24680"; return false
	var parts = addr.split(":")
	var ip = parts[0]
	var port = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_integer() else PORT
	leave(true)
	peer = NetworkedMultiplayerENet.new()
	if peer.create_client(ip, port) != OK:
		note = "Could not reach %s" % addr; peer = null; return false
	get_tree().network_peer = peer
	mode = "lan_client"; status = "connecting"; room = "direct"
	if srv == null: srv = { "sid": "", "name": addr, "motd": "", "max": 16, "pw": pw != "", "pvp": true, "ded": false }
	srv["direct"] = true
	server = srv
	join_pw = str(pw)
	welcomed = false; welcome_t = 12.0
	note = "Connecting to %s …" % addr
	return true

func _same_net(ip):
	var a = ip.split(".")
	if a.size() != 4: return false
	for m in my_ips():
		var b = m.split(".")
		if b.size() == 4 and a[0] == b[0] and a[1] == b[1] and a[2] == b[2]: return true
	return false

static func clean_addr(v):
	var out = ""
	for ch in str(v).substr(0, 60):
		if ch in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:": out += ch
	return out

# a dedicated server passes on what players on the relay say (the sender's id kept)
remote func fwd(from_id, kind, d):
	if get_tree().get_rpc_sender_id() != 1: return
	if typeof(d) != TYPE_DICTIONARY or typeof(kind) != TYPE_STRING or typeof(from_id) != TYPE_STRING: return
	if not from_id.begins_with("r") or from_id.length() > 26 or not from_id.is_valid_identifier(): return
	if kind == "bye":
		_remove(from_id); return
	if kind == "ev" and d.has("to") and str(d.to) != "e" + str(get_tree().get_network_unique_id()): return
	if rejected.has(from_id) and kind != "ev": return
	_on_msg(from_id, kind, d)

func _announce():
	var d = { "n": server.name, "m": server.motd, "p": R.size() + 1, "x": server.max, "k": server.pw, "r": region(), "d": false, "pvp": server.pvp,
		"h": str(G.S["name"]).substr(0, 18), "room": room, "v": VERSION, "t": OS.get_unix_time(), "a": pub_addr, "l": lan_addr }
	var payload = JSON.print(d)
	for l in links: l.publish(PREFIX + "servers/" + server.sid, payload, true)

# the host decides who gets in
func _to(id):
	return id if id.begins_with("e") else id.substr(1)

func _admit(id, p):
	var rid = _to(id)
	var why = ""
	if kicked.has(id) and kicked[id] > G.REAL_T: why = "You were kicked from this server"
	elif host_pw != "" and str(p.get("pw", "")) != pw_hash(host_pw, server.sid) and str(p.get("pw", "")) != pw_hash(host_pw, ""): why = "Wrong password"
	elif R.size() + 1 >= server.max: why = "Server full"
	if why != "":
		_send("ev", { "t": "kick", "why": why }, rid)
		_send("ev", { "t": "reject", "who": rid })
		rejected[id] = true
		return false
	rejected.erase(id)
	_send("ev", { "t": "welcome", "name": server.name, "motd": server.motd, "pvp": server.pvp, "max": server.max, "tf": main.turf.cur() if main.turf else null }, rid)
	announce_t = min(announce_t, 1.0)
	return true

func kick(id):
	if not hosting or not R.has(id): return
	var rid = _to(id)
	kicked[id] = G.REAL_T + 600.0
	_send("ev", { "t": "kick", "why": "Kicked by the host" }, rid)
	_send("ev", { "t": "reject", "who": rid })
	rejected[id] = true
	_remove(id)

func send_chat(text):
	var m = clean_chat(text)
	if m == "" or not online(): return false
	if chat_t > 0: return false
	chat_t = 1.2
	_send("ev", { "t": "chat", "m": m })
	_chat_line(str(G.S["name"]), m)
	return true

func _chat_line(nm, m):
	chat.append({ "n": nm, "m": m })
	while chat.size() > 40: chat.pop_front()
	main.hud.toast("@%s:  %s" % [nm, m])
