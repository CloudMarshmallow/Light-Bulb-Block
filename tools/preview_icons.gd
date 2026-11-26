extends SceneTree
## 生成图标预览图（深色底，方便检查图标是否清晰）：
##   Godot.exe --headless --path game --script res://tools/preview_icons.gd

func _initialize() -> void:
	var names: Array = [
		"undo", "reset", "hint", "pause", "play", "gear", "clock", "help", "hand",
		"bulb", "target", "steps", "trophy", "music", "volume", "shop", "coin", "infinity", "calendar",
	]
	var tile: int = 112
	var cols: int = 5
	var rows: int = int(ceil(float(names.size()) / float(cols)))
	var img: Image = Image.create(cols * tile, rows * tile, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.08, 0.05, 1))
	for i in range(names.size()):
		var icon_name: String = names[i] as String
		var src: Image = Image.load_from_file("res://art/icons/%s.png" % icon_name)
		if src == null:
			continue
		src.resize(tile - 36, tile - 36, Image.INTERPOLATE_NEAREST)
		var ox: int = (i % cols) * tile + 18
		var oy: int = int(float(i / cols)) * tile + 18
		for y in range(src.get_height()):
			for x in range(src.get_width()):
				var c: Color = src.get_pixel(x, y)
				if c.a <= 0.01:
					continue
				var base: Color = img.get_pixel(ox + x, oy + y)
				img.set_pixel(ox + x, oy + y, base.blend(c))
	var err: int = img.save_png("res://art/icons_preview.png")
	print("PREVIEW_DONE err=", err, " size=", img.get_size())
	quit(0 if err == OK else 1)
