extends Control
## 变异印花层：画在方块灯最上层，用来标识变异（冰封锁格 / 幽暗遮蔽）。

var kind: String = ""
var accent: Color = Color(1, 1, 1, 0.7)


func setup(p_kind: String, p_accent: Color) -> void:
	kind = p_kind
	accent = p_accent
	queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	var w: float = size.x
	var h: float = size.y
	var line_w: float = max(1.0, w / 26.0)
	match kind:
		"frozen":
			# 雪花：3 条对角线 + 6 条小枝 + 冰面浅色覆盖
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.86, 1.0, 0.14))
			var c: Vector2 = Vector2(w, h) * 0.5
			var r: float = minf(w, h) * 0.30
			for i in range(3):
				var a: float = PI / 6.0 + float(i) * PI / 3.0
				var dir: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c - dir * r, c + dir * r, accent, line_w)
				for s in [-1.0, 1.0]:
					var tip: Vector2 = c + dir * r * s
					var back: Vector2 = tip - dir * r * 0.32 * s
					var side: Vector2 = Vector2(-dir.y, dir.x) * r * 0.22
					draw_line(tip, back + side, accent, line_w)
					draw_line(tip, back - side, accent, line_w)
			draw_circle(c, max(1.5, w / 22.0), accent)
		"blind":
			# 斜纹遮罩：表示视线被遮蔽（已减淡，避免盖住 22% 亮度差）
			var step: float = max(6.0, w / 5.0)
			var d: float = -h
			while d < w:
				draw_line(Vector2(d, h), Vector2(d + h, 0.0), Color(0.02, 0.05, 0.02, 0.12), max(1.0, w / 34.0))
				d += step
