extends SceneTree
## 程序化生成像素图标（32×32，白色 + alpha，UI 里 modulate 染色）：
##   Godot.exe --headless --path game --script res://tools/gen_icons.gd

const S: int = 32

var _img: Image


func _initialize() -> void:
	var dir: String = ProjectSettings.globalize_path("res://art/icons")
	DirAccess.make_dir_recursive_absolute(dir)
	var icons: Array = [
		"undo", "reset", "hint", "bulb", "pause", "play", "gear", "clock", "star",
		"steps", "target", "trophy", "home", "back", "check", "close", "lock",
		"snow", "eye", "flag", "music", "monitor", "expand", "help", "hand", "volume", "infinity", "calendar", "cloud", "cloud_off", "user", "upload", "download",
	]
	var failures: int = 0
	for icon_name in icons:
		_img = Image.create(S, S, false, Image.FORMAT_RGBA8)
		_img.fill(Color(0, 0, 0, 0))
		match icon_name:
			"undo":
				_undo()
			"reset":
				_reset()
			"hint":
				_hint()
			"bulb":
				_bulb()
			"pause":
				_pause()
			"play":
				_play()
			"gear":
				_gear()
			"clock":
				_clock()
			"star":
				_star()
			"steps":
				_steps()
			"target":
				_target()
			"trophy":
				_trophy()
			"home":
				_home()
			"back":
				_back()
			"check":
				_check()
			"close":
				_close()
			"lock":
				_lock()
			"snow":
				_snow()
			"eye":
				_eye()
			"flag":
				_flag()
			"music":
				_music()
			"monitor":
				_monitor()
			"expand":
				_expand()
			"help":
				_help()
			"hand":
				_hand()
			"volume":
				_volume()
			"infinity":
				_infinity()
			"calendar":
				_calendar()
			"cloud":
				_cloud()
			"cloud_off":
				_cloud_off()
			"user":
				_user()
			"upload":
				_upload()
			"download":
				_download()
		var path: String = "res://art/icons/%s.png" % icon_name
		var err: int = _img.save_png(path)
		if err != OK:
			failures += 1
		print("ICON ", icon_name, " err=", err)
	print("ICONS_DONE failures=", failures)
	quit(1 if failures > 0 else 0)


# ---------- 绘制基础 ----------

func _px(x: int, y: int, on: bool = true) -> void:
	if x >= 0 and y >= 0 and x < S and y < S:
		_img.set_pixel(x, y, Color(1, 1, 1, 1) if on else Color(0, 0, 0, 0))


func _rect(x: int, y: int, w: int, h: int, on: bool = true) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(xx, yy, on)


func _line(x0: int, y0: int, x1: int, y1: int, thickness: int = 1) -> void:
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		_brush(x, y, thickness)
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


func _brush(cx: int, cy: int, t: int) -> void:
	var half: int = t / 2
	for oy in range(-half, half + t % 2):
		for ox in range(-half, half + t % 2):
			_px(cx + ox, cy + oy)


func _disc(cx: int, cy: int, r: int) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				_px(x, y)


func _ring(cx: int, cy: int, r: int, thickness: int = 2) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d2: int = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 <= r * r and d2 >= (r - thickness) * (r - thickness):
				_px(x, y)


func _erase_rect(x: int, y: int, w: int, h: int) -> void:
	_rect(x, y, w, h, false)


func _erase_disc(cx: int, cy: int, r: int) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				_px(x, y, false)


func _poly(points: Array, on: bool = true) -> void:
	var min_x: int = S
	var max_x: int = 0
	var min_y: int = S
	var max_y: int = 0
	for p in points:
		min_x = min(min_x, int(p.x))
		max_x = max(max_x, int(p.x))
		min_y = min(min_y, int(p.y))
		max_y = max(max_y, int(p.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_poly(float(x) + 0.5, float(y) + 0.5, points):
				_px(x, y, on)


func _point_in_poly(px: float, py: float, points: Array) -> bool:
	var inside: bool = false
	var n: int = points.size()
	var j: int = n - 1
	for i in range(n):
		var xi: float = points[i].x
		var yi: float = points[i].y
		var xj: float = points[j].x
		var yj: float = points[j].y
		if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi):
			inside = not inside
		j = i
	return inside


func _arc(cx: int, cy: int, r: int, from_deg: float, to_deg: float, thickness: int = 2) -> void:
	var steps: int = max(8, int(absf(to_deg - from_deg)))
	for i in range(steps + 1):
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(steps)))
		_brush(cx + int(round(cos(a) * float(r))), cy + int(round(sin(a) * float(r))), thickness)


# ---------- 图标 ----------

func _undo() -> void:
	_line(26, 16, 10, 16, 3)
	_line(16, 9, 8, 16, 3)
	_line(16, 23, 8, 16, 3)


func _reset() -> void:
	# 圆形箭头：细弧 + 切线方向的三角箭头（避免糊成一团）
	_arc(16, 16, 10, 60.0, 330.0, 2)
	var theta: float = deg_to_rad(330.0)
	var px: float = 16.0 + cos(theta) * 10.0
	var py: float = 16.0 + sin(theta) * 10.0
	var tangent: Vector2 = Vector2(-sin(theta), cos(theta))
	var perp: Vector2 = Vector2(cos(theta), sin(theta))
	var tip: Vector2 = Vector2(px, py) + tangent * 6.5
	var b1: Vector2 = Vector2(px, py) + perp * 4.5
	var b2: Vector2 = Vector2(px, py) - perp * 4.5
	_poly([tip, b1, b2])


func _bulb() -> void:
	_disc(16, 13, 7)
	_rect(12, 20, 8, 3)
	_rect(13, 24, 6, 3)
	_rect(13, 28, 6, 1)


func _hint() -> void:
	_bulb()
	_line(3, 8, 8, 11, 2)
	_line(29, 8, 24, 11, 2)
	_line(2, 16, 7, 15, 2)
	_line(30, 16, 25, 15, 2)


func _pause() -> void:
	_rect(10, 8, 5, 17)
	_rect(18, 8, 5, 17)


func _play() -> void:
	_poly([Vector2(11, 6), Vector2(26, 16), Vector2(11, 26)])


func _gear() -> void:
	# 设置 = 三条滑杆 + 圆点
	_line(5, 9, 27, 9, 3)
	_line(5, 16, 27, 16, 3)
	_line(5, 23, 27, 23, 3)
	_disc(11, 9, 4)
	_disc(22, 16, 4)
	_disc(15, 23, 4)


func _clock() -> void:
	_ring(16, 16, 12, 3)
	_line(16, 16, 16, 7, 3)
	_line(16, 16, 23, 19, 3)


func _star() -> void:
	_poly(_star_points(16.0, 17.0, 13.0, 5.5, 5))


func _star_points(cx: float, cy: float, outer: float, inner: float, count: int) -> Array:
	var pts: Array = []
	for i in range(count * 2):
		var r: float = outer if i % 2 == 0 else inner
		var a: float = -PI / 2.0 + PI * float(i) / float(count)
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts


func _steps() -> void:
	_disc(10, 10, 5)
	_rect(7, 10, 7, 6)
	_disc(8, 4, 2)
	_disc(12, 3, 2)
	_disc(16, 4, 2)
	_disc(22, 20, 5)
	_rect(19, 20, 7, 6)
	_disc(20, 14, 2)
	_disc(24, 13, 2)
	_disc(28, 14, 2)


func _target() -> void:
	_ring(16, 16, 13, 3)
	_ring(16, 16, 8, 3)
	_disc(16, 16, 3)


func _trophy() -> void:
	_poly([Vector2(9, 5), Vector2(23, 5), Vector2(21, 15), Vector2(16, 19), Vector2(11, 15)])
	_rect(13, 20, 6, 3)
	_rect(10, 24, 12, 3)
	_ring(7, 9, 3, 2)
	_ring(25, 9, 3, 2)


func _home() -> void:
	_poly([Vector2(16, 3), Vector2(30, 15), Vector2(2, 15)])
	_rect(6, 15, 20, 13)
	_erase_rect(13, 20, 6, 8)


func _back() -> void:
	_line(21, 6, 10, 16, 4)
	_line(10, 16, 21, 26, 4)


func _check() -> void:
	_line(5, 17, 12, 24, 4)
	_line(12, 24, 27, 7, 4)


func _close() -> void:
	_line(7, 7, 25, 25, 4)
	_line(25, 7, 7, 25, 4)


func _lock() -> void:
	_ring(16, 12, 7, 3)
	_erase_rect(8, 13, 16, 2)
	_rect(7, 14, 18, 14)
	_erase_disc(16, 20, 3)
	_rect(15, 20, 3, 5)


func _snow() -> void:
	_line(16, 2, 16, 30, 2)
	_line(3, 9, 29, 23, 2)
	_line(3, 23, 29, 9, 2)
	_line(11, 5, 16, 10, 2)
	_line(21, 5, 16, 10, 2)
	_line(11, 27, 16, 22, 2)
	_line(21, 27, 16, 22, 2)


func _eye() -> void:
	_ring(16, 16, 12, 3)
	_disc(16, 16, 4)


func _flag() -> void:
	_rect(8, 3, 3, 26)
	_poly([Vector2(11, 4), Vector2(27, 10), Vector2(11, 16)])


func _music() -> void:
	_rect(19, 6, 3, 17)
	_disc(15, 25, 5)
	_poly([Vector2(22, 6), Vector2(29, 11), Vector2(22, 13)])


func _monitor() -> void:
	_ring(16, 14, 10, 2)
	_erase_rect(10, 8, 12, 10)
	_rect(14, 24, 4, 3)
	_rect(10, 27, 12, 2)


func _expand() -> void:
	_line(6, 12, 6, 6, 3)
	_line(6, 6, 12, 6, 3)
	_line(20, 6, 26, 6, 3)
	_line(26, 6, 26, 12, 3)
	_line(6, 20, 6, 26, 3)
	_line(6, 26, 12, 26, 3)
	_line(26, 20, 26, 26, 3)
	_line(20, 26, 26, 26, 3)


func _help() -> void:
	_ring(16, 16, 13, 3)
	_line(11, 11, 14, 7, 3)
	_line(14, 7, 19, 8, 3)
	_line(19, 8, 21, 12, 3)
	_line(21, 12, 17, 16, 3)
	_line(17, 16, 16, 20, 3)
	_rect(15, 23, 3, 3)


func _hand() -> void:
	_rect(15, 3, 5, 16)
	_disc(17, 4, 3)
	_rect(8, 15, 18, 12)
	_disc(10, 16, 3)
	_disc(26, 16, 3)
	_erase_rect(8, 27, 18, 2)


func _volume() -> void:
	_poly([Vector2(5, 12), Vector2(11, 12), Vector2(19, 5), Vector2(19, 27), Vector2(11, 20), Vector2(5, 20)])
	_arc(20, 16, 7, -60.0, 60.0, 2)
	_arc(20, 16, 12, -55.0, 55.0, 2)


func _infinity() -> void:
	_ring(10, 16, 6, 3)
	_ring(22, 16, 6, 3)


func _calendar() -> void:
	_ring(16, 18, 11, 2)
	_erase_rect(9, 15, 14, 16)
	_rect(8, 8, 16, 4)
	_rect(11, 4, 3, 6)
	_rect(18, 4, 3, 6)
	_disc(12, 17, 1)
	_disc(16, 17, 1)
	_disc(20, 17, 1)
	_disc(12, 21, 1)
	_disc(16, 21, 1)
	_disc(20, 21, 1)




func _cloud() -> void:
	_disc(11, 20, 6)
	_disc(20, 17, 8)
	_disc(27, 21, 5)
	_rect(7, 20, 22, 7)


func _cloud_off() -> void:
	_cloud()
	_erase_line(6, 6, 27, 27, 3)


func _user() -> void:
	_disc(16, 11, 6)
	_rect(8, 19, 16, 10)
	_erase_rect(10, 29, 12, 3)


func _erase_line(x0: int, y0: int, x1: int, y1: int, thickness: int = 3) -> void:
	var steps: int = max(abs(x1 - x0), abs(y1 - y0))
	for i in range(steps + 1):
		var t: float = float(i) / float(max(steps, 1))
		var x: int = int(round(lerpf(float(x0), float(x1), t)))
		var y: int = int(round(lerpf(float(y0), float(y1), t)))
		var half: int = thickness / 2
		for oy in range(-half, half + 1):
			for ox in range(-half, half + 1):
				_px(x + ox, y + oy, false)

func _upload() -> void:
	_rect(6, 22, 20, 4)
	_rect(15, 9, 3, 10)
	_poly([Vector2(9, 12), Vector2(16, 4), Vector2(23, 12)])


func _download() -> void:
	_rect(6, 22, 20, 4)
	_rect(15, 5, 3, 10)
	_poly([Vector2(9, 12), Vector2(16, 20), Vector2(23, 12)])