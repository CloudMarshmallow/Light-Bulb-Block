extends SceneTree
## 生成像素化背景：
##   Godot.exe --headless --path game --script res://tools/pixelate_bg.gd

func _initialize() -> void:
	var src := Image.load_from_file("res://art/bg_original.jpg")
	if src == null:
		push_error("无法加载 art/bg_original.jpg")
		quit(1)
		return
	# 先缩小丢细节，再用最近邻放大得到像素块
	var small := src.duplicate()
	small.resize(288, 162, Image.INTERPOLATE_BILINEAR)
	small.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	var err: int = small.save_png("res://art/bg_pixel.png")
	print("PIXEL_BG_OK err=", err, " size=", small.get_size())

	# 游戏内用：压暗版
	var dark := small.duplicate()
	for y in range(dark.get_height()):
		for x in range(dark.get_width()):
			var c: Color = dark.get_pixel(x, y)
			dark.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, 1.0))
	var err2: int = dark.save_png("res://art/bg_pixel_dark.png")
	print("PIXEL_BG_DARK_OK err=", err2)
	quit(0 if err == OK and err2 == OK else 1)


func small_w() -> int:
	return 288


func small_h() -> int:
	return 162
