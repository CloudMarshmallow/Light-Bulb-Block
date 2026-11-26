extends SceneTree
## 生成金币图标（白色 + alpha，UI 里染成金色）：
##   Godot.exe --headless --path game --script res://tools/build_coin.gd
## 素材：game-icons.net "two-coins"（CC BY 3.0），经 iconify 获取。

func _initialize() -> void:
	var raw: String = FileAccess.get_file_as_string("res://art/icon_src/coin_two_coins.svg")
	if raw.is_empty():
		push_error("无法读取金币 SVG")
		quit(1)
		return
	var re: RegEx = RegEx.new()
	re.compile("d=\"([^\"]+)\"")
	var paths: Array = []
	for m in re.search_all(raw):
		paths.append(m.get_string(1))
	if paths.is_empty():
		push_error("SVG 中没有 path")
		quit(1)
		return
	var body: String = ""
	for d in paths:
		body += "<path fill=\"#ffffff\" d=\"%s\"/>" % (d as String)
	var svg: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\">%s</svg>" % body
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_string(svg, 1.0)
	if err != OK or img.is_empty():
		push_error("SVG 渲染失败: %s" % str(err))
		quit(1)
		return
	img.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	var save_err: int = img.save_png("res://art/icons/coin.png")
	print("COIN_DONE err=", save_err, " size=", img.get_size())
	quit(0 if save_err == OK else 1)
