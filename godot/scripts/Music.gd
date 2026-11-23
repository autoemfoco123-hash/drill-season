extends Node
# The phone's Music app: a player that keeps going wherever you are, on foot, in a car, in the
# menus, like a streaming app on your phone. It plays the game's own music (the radio stations'
# sets and the Basement 808 beats) and songs you own: put MP3, OGG or WAV files in the
# "Drill Season" folder inside your Music folder (the app shows the exact place) and they show
# up under My music, "Artist - Title.mp3" read as artist and title. No songs by real artists
# ship with the game. There is also a button that opens Spotify, so you can play your own
# playlists there over the game (switch Game music off in the app to hear only Spotify).

signal changed                 # a track started, stopped, paused or the library changed

var main
var player
var lib = []                   # { "title", "artist", "album", "src", "own" }
var queue = []                 # indices into lib, in play order
var qi = -1
var cur = null                 # the track loaded (playing or paused)
var length = 0.0
var skipped = []               # own files that couldn't be played, and why
const EXTS = ["mp3", "ogg", "wav"]
const STATIONS = ["", "wcld", "hawk", "northline", "lowend"]
const STYLE = { "chi": "Chicago", "ny": "New York", "uk": "UK" }

func setup(m):
	main = m
	player = AudioStreamPlayer.new(); player.bus = "Radio"
	add_child(player)
	player.connect("finished", self, "_finished")
	scan()

# ---------------------------------------------------------------- the library
# where your own songs go: Music/Drill Season (or the game's own data folder when a system has
# no Music folder); both are read
func folders():
	var out = []
	var sysd = OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
	if sysd != "": out.append(sysd.plus_file("Drill Season"))
	if OS.get_name() == "Android":
		# on a phone, songs usually sit straight in Music or in Download
		if sysd != "": out.append(sysd)
		var dl = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if dl != "": out.append(dl)
	out.append(OS.get_user_data_dir().plus_file("music"))
	return out

func folder():
	return folders()[0]

func scan():
	if OS.get_name() == "Android": OS.request_permissions()
	var keep = cur
	lib = []
	skipped = []
	# your songs first
	var own = []
	var seen = {}
	for d in folders():
		Directory.new().make_dir_recursive(d)
		var dir = Directory.new()
		if dir.open(d) != OK: continue
		dir.list_dir_begin(true, true)
		var fn = dir.get_next()
		while fn != "":
			if not dir.current_is_dir():
				var ext = fn.get_extension().to_lower()
				if ext in EXTS and not seen.has(fn):
					seen[fn] = true; own.append(d.plus_file(fn))
				elif ext in ["m4a", "aac", "flac", "wma", "opus", "alac"]: skipped.append([fn, "use MP3, OGG or WAV"])
			fn = dir.get_next()
		dir.list_dir_end()
	own.sort()
	for p in own:
		var base = p.get_file().get_basename()
		var artist = ""
		var title = base
		var cut = base.find(" - ")
		if cut > 0:
			artist = base.substr(0, cut).strip_edges(); title = base.substr(cut + 3).strip_edges()
		lib.append({ "title": title, "artist": artist, "album": "My music", "src": p, "own": true })
	# the radio stations' sets
	for i in range(1, STATIONS.size()):
		var nm = str(G.D["STATIONS"][i].name).split(" · ")
		lib.append({ "title": (nm[1] if nm.size() > 1 else nm[0]) + " set", "artist": nm[0], "album": "Radio", "src": "res://assets/music/%s.ogg" % STATIONS[i], "own": false })
	# the studio's beats
	var beats = []
	var f = File.new()
	if f.open("res://assets/studio/beats.json", File.READ) == OK:
		var r = JSON.parse(f.get_as_text()); f.close()
		if r.error == OK: beats = r.result
	var count = {}
	for b in beats:
		var st = str(b.get("style", ""))
		count[st] = int(count.get(st, 0)) + 1
		lib.append({ "title": "%s beat %d" % [STYLE.get(st, st), count[st]], "artist": "Basement 808 · %d BPM" % int(b.get("bpm", 140)), "album": "Beats",
			"src": "res://assets/studio/%s.ogg" % b.file, "own": false })
	# keep the song that's on, wherever it moved to
	if keep:
		for i in range(lib.size()):
			if lib[i].src == keep.src: cur = lib[i]
	emit_signal("changed")

func album(name):
	var out = []
	for i in range(lib.size()):
		if lib[i].album == name: out.append(i)
	return out

# ---------------------------------------------------------------- playing
func play_from(ids, at):
	queue = ids.duplicate()
	if shuffle_on():
		var first = queue[at]
		queue.erase(first)
		queue.shuffle()
		queue.push_front(first)
		qi = 0
	else:
		qi = at
	_start()

func playing():
	return cur != null and player.playing and not player.stream_paused

func active():
	return cur != null

func toggle():
	if cur == null:
		if lib.size() > 0: play_from(range(lib.size()), 0)
		return
	player.stream_paused = not player.stream_paused
	emit_signal("changed")

func next():
	if queue.empty(): return
	if qi + 1 >= queue.size():
		if repeat_mode() == "off":
			stop(); return
		qi = 0
	else:
		qi += 1
	_start()

func prev():
	if queue.empty(): return
	if position() > 3.0:
		player.seek(0.0); return
	qi = (qi - 1 + queue.size()) % queue.size()
	_start()

func stop():
	player.stop(); player.stream = null
	cur = null; queue = []; qi = -1; length = 0.0
	main.sfx.radio_st = -1        # the car radio may come back
	emit_signal("changed")

func seek(t):
	if cur: player.seek(clamp(t, 0.0, max(0.0, length - 0.2)))

func position():
	if cur == null: return 0.0
	return player.get_playback_position()

func shuffle_on():
	return bool(G.S.get("settings", {}).get("shuffle", false))

func repeat_mode():
	return str(G.S.get("settings", {}).get("repeat", "all"))

func set_shuffle(v):
	G.S["settings"]["shuffle"] = v
	if v and cur and queue.size() > 1:
		var here = queue[qi]
		queue.erase(here); queue.shuffle(); queue.push_front(here); qi = 0
	emit_signal("changed")

func cycle_repeat():
	var order = ["all", "one", "off"]
	G.S["settings"]["repeat"] = order[(order.find(repeat_mode()) + 1) % order.size()]
	emit_signal("changed")

func _start():
	var t = lib[queue[qi]]
	var st = _stream(t)
	if st == null:
		skipped.append([t.src.get_file(), "couldn't be read"])
		queue.remove(qi)
		if queue.empty() or qi >= queue.size():
			stop(); return
		_start(); return
	cur = t
	player.stream = st
	player.stream_paused = false
	player.play()
	length = st.get_length()
	main.sfx.radio_st = -1; main.sfx.radio.stop()     # the music app takes over from the car radio
	main.hud.toast("♪ " + t.title + ((" · " + t.artist) if t.artist != "" else ""))
	emit_signal("changed")

func _finished():
	if cur == null: return
	if repeat_mode() == "one":
		player.play(); return
	next()

# a stream from the game or from a file of yours
func _stream(t):
	var st = null
	if t.src.begins_with("res://"):
		st = load(t.src)
		if st: st = st.duplicate()
	else:
		var f = File.new()
		if f.open(t.src, File.READ) != OK: return null
		var data = f.get_buffer(f.get_len())
		f.close()
		var ext = t.src.get_extension().to_lower()
		if ext == "mp3":
			st = AudioStreamMP3.new(); st.data = data
		elif ext == "ogg":
			st = AudioStreamOGGVorbis.new(); st.data = data
		elif ext == "wav":
			st = _wav(data)
	if st == null: return null
	if st is AudioStreamSample: st.loop_mode = AudioStreamSample.LOOP_DISABLED
	elif "loop" in st: st.loop = false
	if st.get_length() <= 0.0: return null
	return st

# 8 or 16 bit PCM WAV files
func _wav(d):
	if d.size() < 44 or d.subarray(0, 3).get_string_from_ascii() != "RIFF": return null
	var i = 12
	var fmt = null
	while i + 8 <= d.size():
		var id = d.subarray(i, i + 3).get_string_from_ascii()
		var n = d[i + 4] | (d[i + 5] << 8) | (d[i + 6] << 16) | (d[i + 7] << 24)
		if id == "fmt ":
			fmt = { "pcm": d[i + 8] | (d[i + 9] << 8), "ch": d[i + 10] | (d[i + 11] << 8),
				"rate": d[i + 12] | (d[i + 13] << 8) | (d[i + 14] << 16) | (d[i + 15] << 24), "bits": d[i + 22] | (d[i + 23] << 8) }
		elif id == "data" and fmt:
			if fmt.pcm != 1 or not (fmt.bits in [8, 16]) or not (fmt.ch in [1, 2]): return null
			var s = AudioStreamSample.new()
			s.format = AudioStreamSample.FORMAT_16_BITS if fmt.bits == 16 else AudioStreamSample.FORMAT_8_BITS
			s.stereo = fmt.ch == 2
			s.mix_rate = fmt.rate
			var raw = d.subarray(i + 8, min(d.size(), i + 8 + n) - 1)
			if fmt.bits == 8:
				# WAV stores 8-bit audio unsigned, Godot wants it signed
				for k in range(raw.size()): raw[k] = (raw[k] + 128) % 256
			s.data = raw
			return s
		i += 8 + n + (n % 2)
	return null

# ---------------------------------------------------------------- the outside world
func open_spotify(q = "King Von"):
	OS.shell_open("https://open.spotify.com/search/" + q.http_escape())

func open_folder():
	Directory.new().make_dir_recursive(folder())
	OS.shell_open(folder())

func _process(_dt):
	if cur == null: return
	var on = G.S.get("settings", {}).get("gameMusic", true)
	var v = 0.6 * float(G.S["settings"].get("music", 0.85)) * float(G.S["settings"].get("vol", 0.8)) if on else 0.0
	player.volume_db = linear2db(max(0.0001, v))

# media keys on a keyboard work too
func _input(e):
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	match e.scancode:
		KEY_MEDIAPLAY: toggle()
		KEY_MEDIASTOP: stop()
		KEY_MEDIANEXT: next()
		KEY_MEDIAPREVIOUS: prev()
