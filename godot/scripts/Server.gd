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

const Net = preload("res://scripts/Net.gd")

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

func _ready():
	Engine.target_fps = 20
	OS.low_processor_usage_mode = true
	cfg = _args()
	_open_log()
	sid = cfg.id
	room = ("d" + sid).substr(0, 20)
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

func _args():
	var c = { "name": "Drill Season server", "max": 24, "pw": "", "motd": "", "pvp": true, "region": "", "id": "", "brokers": "" }
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
	for id in players.keys():
		if G.REAL_T - players[id].seen > 15.0:
			_log("@%s left" % players[id].name)
			players.erase(id); announce_t = min(announce_t, 1.0)
	for k in seen.keys():
		if G.REAL_T - seen[k] > 30: seen.erase(k)
	status_t -= dt
	if status_t <= 0:
		status_t = 60.0
		print("[server] %d/%d players" % [players.size(), cfg.max])
	if label:
		label.text = "%s\n%d / %d players · %s\n\n%s" % [cfg.name, players.size(), cfg.max, "online" if online else "connecting…", PoolStringArray(log_lines).join("\n")]

func _announce():
	var d = { "n": cfg.name, "m": cfg.motd, "p": players.size(), "x": cfg.max, "k": cfg.pw != "", "r": cfg.region, "d": true, "pvp": cfg.pvp,
		"h": "dedicated", "room": room, "v": Net.VERSION, "t": OS.get_unix_time() }
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
		return
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
	_send("ev", { "t": "welcome", "name": cfg.name, "motd": cfg.motd, "pvp": cfg.pvp, "max": cfg.max }, from)
	announce_t = min(announce_t, 1.0)

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
		if log_file:
			log_file.close(); log_file = null
