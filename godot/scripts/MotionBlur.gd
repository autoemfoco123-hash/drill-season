extends Node
# A little motion blur (Settings → Motion blur): the picture smears along the way the camera
# turns, the faster the turn the more, and at speed in a car it pulls out from the middle a
# touch. It reads the camera itself, so it works on foot, in a car, in first and third person.
# Off on the lowest quality, and only drawn when there is something to blur.

var main
var layer
var rect
var mat
var last_basis = null
var shift = Vector2()
var zoom = 0.0

func setup(m):
	main = m
	layer = CanvasLayer.new()
	layer.layer = 0                   # over the 3D world and the sky (-1), under the HUD (1 and up)
	add_child(layer)
	rect = ColorRect.new()
	rect.anchor_right = 1.0; rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/motionblur.shader")
	rect.material = mat
	rect.visible = false
	layer.add_child(rect)

func enabled():
	var st = G.S.get("settings", {}) if typeof(G.S) == TYPE_DICTIONARY else {}
	return bool(st.get("motionblur", true)) and str(st.get("quality", "high")) != "low"

func update(dt):
	var cam = main.camera
	if cam == null or dt <= 0.0: return
	var b = cam.global_transform.basis
	var on = enabled() and G.MODE in ["play", "phone"] and not main.cutscene.on
	var want = Vector2()
	var wz = 0.0
	if on and last_basis != null:
		# how far the view turned this frame, as a fraction of the screen
		var f0 = -last_basis.z
		var f1 = -b.z
		var right = b.x
		var up = b.y
		var d = f1 - f0
		var fov = deg2rad(max(30.0, cam.fov))
		var aspect = max(0.5, get_viewport().size.x / max(1.0, get_viewport().size.y))
		want = Vector2(d.dot(right) / (fov * aspect), -d.dot(up) / fov) * 0.38
		var P = main.player
		if P.car:
			wz = clamp((abs(P.car.speed) - 16.0) / 50.0, 0.0, 1.0) * 0.045
	last_basis = b
	var k = min(1.0, dt * 18.0)
	shift = shift.linear_interpolate(want.clamped(0.022), k)
	zoom = lerp(zoom, wz, min(1.0, dt * 4.0))
	var vis = on and (shift.length() > 0.0012 or zoom > 0.002)
	rect.visible = vis
	if vis:
		mat.set_shader_param("shift", shift)
		mat.set_shader_param("zoom", zoom)
