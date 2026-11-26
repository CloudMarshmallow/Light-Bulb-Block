extends Control
## 方块灯皮肤印花层：在格子亮起时叠加图案（点/斜线/棋盘/十字/网格）。
## soft=true 时（幽暗关）线条更粗、颜色更淡，呈现“模糊暗沉”的观感。

var pattern: String = "none"
var accent: Color = Color(1, 1, 1, 0.30)
var soft: bool = false


func setup(p_pattern: String, p_accent: Color, p_soft: bool = false) -> void:
	pattern = p_pattern
	accent = p_accent
	soft = p_soft
	queue_redraw()


func _draw() -> void:
	if pattern == "none":
		return
	var w: float = size.x
	var h: float = size.y
	var step: float = max(8.0, w / 6.0)
	var col: Color = accent
	var line_width: float = max(1.0, w / 28.0)
	if soft:
		col = Color(accent.r, accent.g, accent.b, accent.a * 0.40)
		line_width = max(2.0, w / 13.0)
		step = max(9.0, w / 5.0)
	match pattern:
		"dots":
			var r: float = max(1.0, w / 24.0) * (1.8 if soft else 1.0)
			var y: float = step * 0.5
			while y < h:
				var x: float = step * 0.5
				while x < w:
					draw_circle(Vector2(x, y), r, col)
					x += step
				y += step
		"diag":
			var d: float = -h
			while d < w:
				draw_line(Vector2(d, h), Vector2(d + h, 0.0), col, line_width)
				d += step
		"checker":
			var y2: float = 0.0
			var row: int = 0
			while y2 < h:
				var x2: float = 0.0 if row % 2 == 0 else step
				while x2 < w:
					draw_rect(Rect2(x2, y2, step * 0.5, step * 0.5), col)
					x2 += step
				y2 += step
				row += 1
		"cross":
			var y3: float = step * 0.5
			while y3 < h:
				var x3: float = step * 0.5
				while x3 < w:
					draw_line(Vector2(x3 - step * 0.2, y3), Vector2(x3 + step * 0.2, y3), col, line_width)
					draw_line(Vector2(x3, y3 - step * 0.2), Vector2(x3, y3 + step * 0.2), col, line_width)
					x3 += step
				y3 += step
		"grid":
			draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), col, line_width)
			draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), col, line_width)
