class_name Styles
extends RefCounted
## 方块皮肤：5 种可购买风格 + 默认免费风格（颜色 + 印花）。

const PATTERNS: Array = ["none", "dots", "diag", "checker", "cross", "grid"]


static func all() -> Array:
	return [
		{
			"id": "default", "name": "暖黄", "price": 0,
			"on": Color("ffd166"), "on_hover": Color("ffe08a"), "on_border": Color("ffefa8"),
			"off": Color("2c3d27"), "off_hover": Color("3a5032"), "off_border": Color("5a7048"),
			"pattern": "none", "accent": Color("ffefa8"),
		},
		{
			"id": "sakura", "name": "樱花", "price": 100,
			"on": Color("ff9ec7"), "on_hover": Color("ffb8d6"), "on_border": Color("ffd6e7"),
			"off": Color("3a2430"), "off_hover": Color("4c2f3f"), "off_border": Color("6e4659"),
			"pattern": "dots", "accent": Color("fff0f6"),
		},
		{
			"id": "ocean", "name": "海洋", "price": 150,
			"on": Color("6fd3ff"), "on_hover": Color("93e0ff"), "on_border": Color("c4f0ff"),
			"off": Color("122a3a"), "off_hover": Color("1a3a4f"), "off_border": Color("2d5a76"),
			"pattern": "diag", "accent": Color("e6faff"),
		},
		{
			"id": "neon", "name": "霓虹", "price": 200,
			"on": Color("b388ff"), "on_hover": Color("c9a8ff"), "on_border": Color("e3d3ff"),
			"off": Color("1b1430"), "off_hover": Color("271d44"), "off_border": Color("463366"),
			"pattern": "checker", "accent": Color("f3eaff"),
		},
		{
			"id": "forest", "name": "森野", "price": 250,
			"on": Color("8fe07a"), "on_hover": Color("a8ea96"), "on_border": Color("d2f5c4"),
			"off": Color("1c2f1a"), "off_hover": Color("274226"), "off_border": Color("3f6639"),
			"pattern": "cross", "accent": Color("e8ffe0"),
		},
		{
			"id": "gold", "name": "金砖", "price": 300,
			"on": Color("ffd700"), "on_hover": Color("ffe14d"), "on_border": Color("fff2a8"),
			"off": Color("3a2c10"), "off_hover": Color("523d15"), "off_border": Color("7a5c22"),
			"pattern": "grid", "accent": Color("fffbe0"),
		},
	]


static func get_style(id: String) -> Dictionary:
	for s in all():
		if (s["id"] as String) == id:
			return s
	return all()[0] as Dictionary


static func default_id() -> String:
	return "default"
