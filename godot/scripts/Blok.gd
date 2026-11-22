extends Node
# Blok, the block's social feed (from the web game's 90_ui.js): your posts gain likes,
# comments and followers over time, the city chatters about what you do, and the phone's
# camera posts photos. Photos taken here are saved as files next to the save.

var main
var social_t = 4.0
var _tex = {}
const PHOTO_DIR = "user://photos"

func setup(m):
	main = m

func followers():
	var s = G.S.get("social", {})
	return int(round(float(s.get("followers", 214)) + pow(float(G.S["buzz"]), 1.7) * 14))

func add_post(kind, caption, img):
	var eng = 0.09 if kind == "track" else (0.12 if kind == "video" else 0.06)
	var now = OS.get_unix_time() * 1000
	var post = { "id": str(now) + str(randi() % 999), "at": now, "kind": kind, "caption": str(caption).substr(0, 80), "img": img, "thumb": null, "likes": 0,
		"target": int(round(followers() * eng * G.rand(0.7, 1.4))) + 3 + randi() % 10, "comments": [] }
	var S = G.S["social"]
	S["posts"].push_front(post)
	while S["posts"].size() > 12: S["posts"].pop_back()
	if kind == "photo": G.S["stats"]["photos"] = int(G.S["stats"].get("photos", 0)) + 1
	return post

func update(dt):
	social_t -= dt
	if social_t > 0: return
	social_t = 4.0
	var now = OS.get_unix_time() * 1000
	for p in G.S["social"]["posts"]:
		if now - float(p.at) > 40 * 60000 or p.likes >= p.target: continue
		var add = max(1, int(ceil((p.target - p.likes) * G.rand(0.06, 0.2))))
		p.likes += add
		if randf() < 0.4: G.S["social"]["followers"] = int(G.S["social"]["followers"]) + int(ceil(add / 8.0))
		if randf() < 0.18 and p.comments.size() < 6:
			var pool = G.D["COMMENTS"].get(p.kind, G.D["COMMENTS"]["photo"])
			var c = { "h": G.pick(G.D["FEED_HANDLES"]), "t": G.pick(pool) }
			p.comments.append(c)
			if randf() < 0.5 and G.MODE == "play": main.hud.toast("Blok · %s commented: %s" % [c.h, c.t])

# a photo of what the camera sees right now (the phone is hidden for the shot)
func take_photo(caption):
	var was = main.phone.panel.visible
	main.phone.panel.visible = false
	main.hud.layer.visible = false
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	main.hud.layer.visible = true
	main.phone.panel.visible = was
	img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	Directory.new().make_dir_recursive(PHOTO_DIR)
	var path = PHOTO_DIR + "/%d.png" % OS.get_unix_time()
	img.save_png(path)
	main.sfx.play("shutter", 0.6)
	add_post("photo", caption, path)
	G.save_game()

# a texture for a post's picture: a photo file from here, or a data URL from the web game
func texture_for(img):
	if img == null or typeof(img) != TYPE_STRING or img == "": return null
	if _tex.has(img): return _tex[img]
	var im = Image.new()
	var err = ERR_FILE_UNRECOGNIZED
	if img.begins_with("user://"):
		err = im.load(img)
	elif img.begins_with("data:image/"):
		var comma = img.find(",")
		var raw = Marshalls.base64_to_raw(img.substr(comma + 1))
		if img.begins_with("data:image/png"): err = im.load_png_from_buffer(raw)
		elif img.begins_with("data:image/jpeg") or img.begins_with("data:image/jpg"): err = im.load_jpg_from_buffer(raw)
		elif img.begins_with("data:image/webp"): err = im.load_webp_from_buffer(raw)
	if err != OK: return null
	var t = ImageTexture.new(); t.create_from_image(im)
	_tex[img] = t
	return t
