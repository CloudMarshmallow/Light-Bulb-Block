extends SceneTree
## 生成商店购物车图标（开源素材 → 32×32 像素白图）：
##   Godot.exe --headless --path game --script res://tools/build_shop_icon.gd
## 素材：Material Symbols "shopping-cart"（Apache-2.0），经 iconify 获取。

const SOURCE: String = "res://art/icon_src/shop_cart_ms.svg"
const SIZE: int = 32


func _initialize() -> void:
	var raw: String = FileAccess.get_file_as_string(SOURCE)
	if raw.is_empty():
		push_error("无法读取购物车 SVG: " + SOURCE)
		quit(1)
		return
	# iconify 输出 width/height="1em"，改成 viewBox 尺寸后按比例渲染
	var re: RegEx = RegEx.new()
	re.compile("width=\"[^\"]*\" height=\"[^\"]*\"")
	var svg: String = re.sub(raw, "width=\"24\" height=\"24\"", true)
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_string(svg, float(SIZE) / 24.0)
	if err != OK or img.is_empty():
		push_error("SVG 渲染失败: %s" % str(err))
		quit(1)
		return
	if img.get_width() != SIZE or img.get_height() != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	# 阈值化：保留像素风硬边（与其它程序图标一致）
	var out: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in range(SIZE):
		for x in range(SIZE):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				out.set_pixel(x, y, Color(1, 1, 1, 1))
	var save_err: int = out.save_png("res://art/icons/shop.png")
	print("SHOP_ICON_DONE err=", save_err, " size=", out.get_size())
	quit(0 if save_err == OK else 1)
