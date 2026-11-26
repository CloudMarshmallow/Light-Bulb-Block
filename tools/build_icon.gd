extends SceneTree
## 生成游戏图标 icon.png（512×512）：
##   Godot.exe --headless --path game --script res://tools/build_icon.gd
## 灯泡素材：game-icons.net "light-bulb"（CC BY 3.0），背景与方块网格为程序绘制。

const SIZE: int = 512
const BG: Color = Color(0.055, 0.102, 0.071)       # 深绿底
const BG_EDGE: Color = Color(0.62, 0.78, 0.40)     # 边框绿
const AMBER: Color = Color(1.0, 0.82, 0.40)        # 灯泡琥珀
const BLOCK: Color = Color(0.85, 0.62, 0.24)       # 方块


func _initialize() -> void:
	var src_path: String = "res://art/icon_src/svgicons_light_bulb.svg"
	var raw: String = FileAccess.get_file_as_string(src_path)
	if raw.is_empty():
		push_error("无法读取 SVG: " + src_path)
		quit(1)
		return
	var re: RegEx = RegEx.new()
	re.compile("d=\"([^\"]+)\"")
	var m: RegExMatch = re.search(raw)
	if m == null:
		push_error("SVG 中未找到 path")
		quit(1)
		return
	var path_data: String = m.get_string(1)
	var mini_svg: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><path fill=\"#ffffff\" d=\"%s\"/></svg>" % path_data
	var bulb: Image = Image.new()
	var svg_err: Error = bulb.load_svg_from_string(mini_svg, 1.0)
	if svg_err != OK or bulb.is_empty():
		push_error("SVG 渲染失败: %s" % str(svg_err))
		quit(1)
		return

	var canvas: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	_draw_rounded_rect(canvas, 8, 8, SIZE - 16, SIZE - 16, 108, BG)
	_draw_rounded_rect_outline(canvas, 8, 8, SIZE - 16, SIZE - 16, 108, BG_EDGE, 7)

	# 背景方块网格（很淡）
	var grid_col: Color = Color(0.35, 0.48, 0.26, 0.16)
	for i in range(1, 4):
		var p: int = int(float(SIZE) * float(i) / 4.0)
		_fill_rect(canvas, p - 1, 40, 2, SIZE - 80, grid_col)
		_fill_rect(canvas, 40, p - 1, SIZE - 80, 2, grid_col)

	# 灯泡（缩放到 340 并染成琥珀）
	var glyph: Image = bulb.duplicate()
	glyph.resize(348, 348, Image.INTERPOLATE_LANCZOS)
	_tint(glyph, AMBER)
	_blit(canvas, glyph, (SIZE - 348) / 2, (SIZE - 348) / 2 - 26)

	# 底部三个方块（“方块”元素）
	var bw: int = 52
	var gap: int = 16
	var total: int = bw * 3 + gap * 2
	var bx: int = (SIZE - total) / 2
	for i in range(3):
		var x: int = bx + i * (bw + gap)
		_fill_rect(canvas, x, 404, bw, bw, BLOCK)
		_fill_rect(canvas, x + 4, 408, bw - 8, bw - 8, Color(0.45, 0.32, 0.12, 1.0))

	var err: int = canvas.save_png("res://icon.png")
	print("ICON_DONE err=", err, " size=", canvas.get_size())
	quit(0 if err == OK else 1)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < SIZE and yy < SIZE:
				var dst: Color = img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, dst.blend(color))


func _draw_rounded_rect(img: Image, x: int, y: int, w: int, h: int, r: int, color: Color) -> void:
	var x2: int = x + w
	var y2: int = y + h
	for yy in range(y, y2):
		for xx in range(x, x2):
			if _in_rounded(xx, yy, x, y, x2, y2, r):
				img.set_pixel(xx, yy, color)


func _draw_rounded_rect_outline(img: Image, x: int, y: int, w: int, h: int, r: int, color: Color, thickness: int) -> void:
	var x2: int = x + w
	var y2: int = y + h
	for yy in range(y, y2):
		for xx in range(x, x2):
			var outer: bool = _in_rounded(xx, yy, x, y, x2, y2, r)
			if not outer:
				continue
			var inner: bool = _in_rounded(xx, yy, x + thickness, y + thickness, x2 - thickness, y2 - thickness, max(r - thickness, 0))
			if not inner:
				img.set_pixel(xx, yy, color)


func _in_rounded(px: int, py: int, x1: int, y1: int, x2: int, y2: int, r: int) -> bool:
	if px < x1 or px >= x2 or py < y1 or py >= y2:
		return false
	var cx: int = clampi(px, x1 + r, x2 - r - 1)
	var cy: int = clampi(py, y1 + r, y2 - r - 1)
	var dx: int = px - cx
	var dy: int = py - cy
	return dx * dx + dy * dy <= r * r


func _tint(img: Image, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.02:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, c.a))


func _blit(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var dx: int = ox + x
			var dy: int = oy + y
			if dx >= 0 and dy >= 0 and dx < SIZE and dy < SIZE:
				var base: Color = dst.get_pixel(dx, dy)
				dst.set_pixel(dx, dy, base.blend(c))
