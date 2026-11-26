extends Control
## 灯泡方块 · 像素风 10 关闯关版
## 玩法：点方格翻转自身+上下左右四邻，全亮过关；10 关通关后显示总时长。
## 命令行：--auto-demo / --ui-test / --shot-menu|--shot-game|--shot-pause|--shot-victory

const PuzzleEngineRef := preload("res://scripts/puzzle_engine.gd")
const LevelPlanRef := preload("res://scripts/level_plan.gd")
const UIKitRef := preload("res://scripts/ui_kit.gd")
const SunSystemRef := preload("res://scripts/sun_system.gd")
const LeavesFxRef := preload("res://scripts/leaves_fx.gd")
const SunRaysRef := preload("res://scripts/sun_rays.gd")
const StylesRef := preload("res://scripts/styles.gd")
const PatternRef := preload("res://scripts/pattern_overlay.gd")
const DecalRef := preload("res://scripts/mutation_decal.gd")

const WINDOW_SIZES: Array = [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const WINDOW_LABELS: Array = ["1024 × 576", "1280 × 720", "1600 × 900", "1920 × 1080"]

const COL_ON: Color = Color("ffd166")
const COL_ON_HOVER: Color = Color("ffe08a")
const COL_ON_BORDER: Color = Color("ffefa8")
const COL_OFF: Color = Color("2c3d27")
const COL_OFF_HOVER: Color = Color("3a5032")
const COL_OFF_BORDER: Color = Color("5a7048")

var screen_mode: String = "menu"
var level: int = 1
var room: Dictionary = {}
var state: int = 0
var initial_state: int = 0
var net: int = 0
var undo_used: bool = false
var hint_used: bool = false
var run_seed: int = 0
var solved: bool = false
var failed: bool = false
var step_limit: int = 0
var paused: bool = false
var run_time: float = 0.0
var level_start_time: float = 0.0
var timing: bool = false
var history_cells: Array = []
var mutation_icon: String = ""
var alert_open: bool = false
var _suppress_alerts: bool = false
var mode: String = "infinite"
var mutation: String = ""
var style_def: Dictionary = {}
var dots_box: HBoxContainer
var coin_label: Label
var _history_mode: String = "daily"
var auth_btn: Button
var _merge_pending_on_menu: bool = false
var _auth_panel_open: bool = false
var _was_signed_in: bool = false
var _cloud_sync_done: bool = false
var _auth_phone_edit: LineEdit
var _auth_password_edit: LineEdit
var _auth_error_label: Label

var menu_root: Control
var game_root: Control
var overlay_root: Control
var grid: GridContainer
var cells: Array = []
var hud: Dictionary = {}
var level_label: Label
var dots: Array = []
var mutation_rect: TextureRect
var board_panel: PanelContainer
var physics_root: Node2D
var floor_body: StaticBody2D
var cell_px: int = 72
var sfx_click: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var sfx_deny: AudioStreamPlayer
var sfx_frozen: AudioStreamPlayer
var sfx_blind: AudioStreamPlayer
var sfx_coin: AudioStreamPlayer
var _daily_key: String = ""
var _last_toast: String = ""
var _toast_node: Control
var undo_btn: Button
var reset_btn: Button
var hint_btn: Button
var pause_btn: Button
var sun
var leaves_fx
var rays: ColorRect
var bgm: AudioStreamPlayer

var _sb_on: StyleBoxFlat
var _sb_on_hover: StyleBoxFlat
var _sb_off: StyleBoxFlat
var _sb_off_hover: StyleBoxFlat
var _sb_frozen: StyleBoxFlat
var _sb_frozen_on: StyleBoxFlat
var _sb_blind_on: StyleBoxFlat
var _sb_blind_off: StyleBoxFlat
var _dot_done: StyleBoxFlat
var _dot_current: StyleBoxFlat
var _dot_todo: StyleBoxFlat


func _ready() -> void:
	style_def = StylesRef.get_style(UserData.selected_style)
	_build_styleboxes()
	_build_backdrop()
	_build_weather_fx()
	_build_menu()
	_build_game()
	_build_audio()
	overlay_root = Control.new()
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_root)
	var auth: Node = get_node_or_null("/root/Auth")
	if auth != null:
		auth.state_changed.connect(_on_auth_changed)
		_was_signed_in = bool(auth.call("is_signed_in"))
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud != null:
		cloud.upload_finished.connect(_on_cloud_uploaded)
		cloud.download_finished.connect(_on_cloud_downloaded)
		cloud.sync_finished.connect(_on_cloud_sync_finished)
	UserData.saved.connect(_on_user_saved)
	if _was_signed_in:
		call_deferred("_sync_cloud_on_start")
	_refresh_auth_icon()
	_fx_ensure()
	_fx_write_diag()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var is_test_run: bool = false
	for arg in args:
		if arg == "--ui-test" or arg == "--auto-demo" or arg.begins_with("--shot-"):
			is_test_run = true
	if is_test_run:
		UserData.test_mode = true
	for arg in args:
		if arg.begins_with("--hour="):
			sun.force_hour = float(arg.substr(7))
			sun.refresh()
	if args.has("--auto-demo"):
		_auto_demo()
		return
	if args.has("--ui-test"):
		_ui_test()
		return
	if args.has("--shot-menu"):
		_shot("menu")
		return
	if args.has("--shot-game"):
		_shot("game")
		return
	if args.has("--shot-pause"):
		_shot("pause")
		return
	if args.has("--shot-victory"):
		_shot("victory")
		return
	if args.has("--shot-help"):
		_shot("tutorial")
		return
	if args.has("--shot-tutorial"):
		_shot("tutorial")
		return
	if args.has("--shot-mode"):
		_shot("mode")
		return
	if args.has("--shot-shop"):
		_shot("shop")
		return
	if args.has("--shot-daily"):
		_shot("daily")
		return
	if args.has("--shot-mutation"):
		_shot("mutation")
		return
	if args.has("--shot-decal"):
		_shot("decal")
		return
	if args.has("--shot-blind"):
		_shot("blind")
		return
	if args.has("--shot-fail"):
		_shot("fail")
		return
	if args.has("--shot-history"):
		_shot("history")
		return
	if args.has("--shot-notice"):
		_shot("notice")
		return
	if args.has("--shot-auth"):
		_shot("auth")
		return
	show_menu()


func _process(delta: float) -> void:
	if timing and not paused and screen_mode == "game":
		run_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if alert_open:
		return
	if event.is_action_pressed("ui_cancel") and screen_mode == "game" and not solved:
		_toggle_pause()


# ---------------- 样式 ----------------

func _build_styleboxes() -> void:
	if style_def.is_empty():
		style_def = StylesRef.get_style(UserData.selected_style)
	var on_col: Color = style_def["on"] as Color
	var on_hover: Color = style_def["on_hover"] as Color
	var on_border: Color = style_def["on_border"] as Color
	var off_col: Color = style_def["off"] as Color
	var off_hover: Color = style_def["off_hover"] as Color
	var off_border: Color = style_def["off_border"] as Color
	_sb_on = UIKitRef.make_sb(on_col, on_border, 4, 2)
	_sb_on_hover = UIKitRef.make_sb(on_hover, on_border, 4, 2)
	_sb_off = UIKitRef.make_sb(off_col, off_border, 4, 2)
	_sb_off_hover = UIKitRef.make_sb(off_hover, off_border, 4, 2)
	_sb_frozen = UIKitRef.make_sb(Color("111a10"), Color("2c3a28"), 4, 2)
	_sb_frozen_on = UIKitRef.make_sb(on_col.darkened(0.45), on_border.darkened(0.3), 4, 2)
	# 幽暗：所有格子同一暗沉色系，但亮格保留约 22% 亮度差
	var blind_bg: Color = Color("141b14")
	var blind_bg_on: Color = Color("142314")
	var blind_border: Color = Color("263126")
	_sb_blind_on = UIKitRef.make_sb(blind_bg_on, blind_border, 4, 2)
	_sb_blind_off = UIKitRef.make_sb(blind_bg, blind_border, 4, 2)
	_dot_done = UIKitRef.make_sb(Color("7fbf5f"), Color("7fbf5f"), 7, 0)
	_dot_current = UIKitRef.make_sb(on_col, on_border, 7, 0)
	_dot_todo = UIKitRef.make_sb(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.25), 7, 0)


func _build_backdrop() -> void:
	var bg: TextureRect = TextureRect.new()
	bg.texture = load("res://art/bg_pixel.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_weather_fx() -> void:
	sun = SunSystemRef.new()
	add_child(sun)
	leaves_fx = LeavesFxRef.new() as Node2D
	add_child(leaves_fx)
	leaves_fx.sun = sun
	rays = SunRaysRef.new() as ColorRect
	add_child(rays)
	rays.sun = sun


func _fx_ensure() -> void:
	## 保险：回到菜单 / 登录状态变化后，确保天气层仍然存在且可见
	if sun != null:
		sun.refresh()
	if leaves_fx != null:
		leaves_fx.visible = true
		leaves_fx.queue_redraw()
	if rays != null:
		rays.visible = true


func _fx_write_diag() -> void:
	var path: String = "user://fx_diag.log"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var info: Dictionary = {
		"time": Time.get_datetime_string_from_system(),
		"viewport": str(get_viewport_rect().size),
		"window": str(DisplayServer.window_get_size()),
		"sun_hour": sun.hour if sun != null else -1.0,
		"sun_intensity": sun.intensity if sun != null else -1.0,
		"leaves": leaves_fx.get_child_count() if leaves_fx != null else -1,
		"leaves_visible": leaves_fx.visible if leaves_fx != null else false,
		"rays_visible": rays.visible if rays != null else false,
	}
	f.store_string(JSON.stringify(info, "\t"))
	f.close()


func _small_icon(icon_name: String) -> TextureRect:
	var tex: TextureRect = TextureRect.new()
	tex.texture = UIKitRef.icon(icon_name)
	tex.custom_minimum_size = Vector2(30, 30)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = UIKitRef.COL_DIM
	return tex


# ---------------- 主菜单 ----------------

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)

	menu_root.add_child(UIKitRef.dim_layer(0.32))

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	vbox.add_child(buttons)
	var start_btn: Button = UIKitRef.menu_icon_button("play", "开始游戏")
	start_btn.pressed.connect(_on_start_pressed)
	buttons.add_child(start_btn)
	var shop_btn: Button = UIKitRef.menu_icon_button("shop", "商店")
	shop_btn.pressed.connect(_open_shop)
	buttons.add_child(shop_btn)
	var settings_btn: Button = UIKitRef.menu_icon_button("gear", "设置")
	settings_btn.pressed.connect(_open_settings)
	buttons.add_child(settings_btn)
	var history_btn: Button = UIKitRef.menu_icon_button("clock", "通关记录")
	history_btn.pressed.connect(_open_history)
	buttons.add_child(history_btn)
	var help_btn: Button = UIKitRef.menu_icon_button("help", "新手引导", 84)
	help_btn.pressed.connect(_open_help)
	buttons.add_child(help_btn)

	# 金币显示（右上角）
	var coin_panel: PanelContainer = UIKitRef.overlay_panel(Vector2(0, 0))
	coin_panel.add_theme_stylebox_override("panel", UIKitRef.make_sb(Color("08110a", 0.78), Color("2c3a28"), 16, 1))
	coin_panel.anchor_left = 1.0
	coin_panel.anchor_right = 1.0
	coin_panel.offset_left = -196
	coin_panel.offset_right = -24
	coin_panel.offset_top = 22
	coin_panel.offset_bottom = 78
	menu_root.add_child(coin_panel)
	var coin_row: HBoxContainer = HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 10)
	coin_panel.add_child(coin_row)
	var coin_icon: TextureRect = TextureRect.new()
	coin_icon.texture = UIKitRef.icon("coin")
	coin_icon.custom_minimum_size = Vector2(30, 30)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color("ffd166")
	coin_row.add_child(coin_icon)
	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 26)
	coin_label.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	coin_row.add_child(coin_label)
	_update_coin_label()

	# 登录状态（左上角）：云 = 已登录，云叉 = 本地模式
	auth_btn = UIKitRef.icon_button("cloud_off", 52)
	auth_btn.tooltip_text = "登录状态：本地模式"
	auth_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	auth_btn.position = Vector2(24, 22)
	auth_btn.pressed.connect(_open_auth_panel)
	menu_root.add_child(auth_btn)


# ---------------- 游戏界面 ----------------

func _build_game() -> void:
	game_root = Control.new()
	game_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_root.visible = false
	add_child(game_root)
	game_root.add_child(UIKitRef.dim_layer(0.18))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	game_root.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# 顶栏：旗帜 + 关卡号 + 10 个进度点 + 暂停
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	var flag: TextureRect = TextureRect.new()
	flag.texture = UIKitRef.icon("flag")
	flag.custom_minimum_size = Vector2(26, 26)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(flag)
	level_label = Label.new()
	level_label.text = "1-1"
	level_label.add_theme_font_size_override("font_size", 26)
	level_label.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	top.add_child(level_label)
	dots_box = HBoxContainer.new()
	dots_box.add_theme_constant_override("separation", 6)
	top.add_child(dots_box)
	for _i in range(LevelPlanRef.DAILY_LEVELS):
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.add_theme_stylebox_override("panel", _dot_todo)
		dots_box.add_child(dot)
		dots.append(dot)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	pause_btn = UIKitRef.icon_button("pause", 52)
	pause_btn.pressed.connect(_toggle_pause)
	top.add_child(pause_btn)

	# 状态：步数 / 最优 / 剩余灯 / 变异（图标 + 数字，外加半透明底条提升可读性）
	var stats_panel: PanelContainer = UIKitRef.overlay_panel(Vector2(0, 0))
	stats_panel.add_theme_stylebox_override("panel", UIKitRef.make_sb(Color("08110a", 0.78), Color("2c3a28"), 14, 1))
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(stats_panel)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 34)
	stats_panel.add_child(stats)
	var steps_row: HBoxContainer = UIKitRef.stat("steps", "0")
	hud["steps"] = steps_row
	stats.add_child(steps_row)
	var opt_row: HBoxContainer = UIKitRef.stat("target", "0")
	hud["optimal"] = opt_row
	stats.add_child(opt_row)
	var rem_row: HBoxContainer = UIKitRef.stat("bulb", "0")
	hud["remaining"] = rem_row
	stats.add_child(rem_row)
	mutation_rect = TextureRect.new()
	mutation_rect.texture = UIKitRef.icon("snow")
	mutation_rect.custom_minimum_size = Vector2(30, 30)
	mutation_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mutation_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mutation_rect.modulate = Color("c9e4ff")
	mutation_rect.visible = false
	stats.add_child(mutation_rect)

	# 棋盘
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	board_panel = UIKitRef.overlay_panel(Vector2(0, 0))
	board_panel.add_theme_stylebox_override("panel", UIKitRef.make_sb(Color("0b140dcc"), Color("3f5a3a"), 8, 2))
	center.add_child(board_panel)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	board_panel.add_child(grid)

	# 底部操作：撤销 / 重置 / 提示
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	vbox.add_child(bottom)
	undo_btn = UIKitRef.icon_button("undo", 58)
	undo_btn.pressed.connect(_on_undo)
	bottom.add_child(undo_btn)
	reset_btn = UIKitRef.icon_button("reset", 58)
	reset_btn.pressed.connect(_on_reset)
	bottom.add_child(reset_btn)
	hint_btn = UIKitRef.icon_button("hint", 58)
	hint_btn.pressed.connect(_on_hint)
	bottom.add_child(hint_btn)

	physics_root = Node2D.new()
	game_root.add_child(physics_root)
	_place_floor()


func _build_audio() -> void:
	sfx_click = AudioStreamPlayer.new()
	sfx_click.stream = load("res://audio/press.wav") as AudioStream
	sfx_click.volume_db = -8.0
	add_child(sfx_click)
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://audio/win.wav") as AudioStream
	sfx_win.volume_db = -4.0
	add_child(sfx_win)
	sfx_deny = AudioStreamPlayer.new()
	sfx_deny.stream = load("res://audio/deny.wav") as AudioStream
	sfx_deny.volume_db = -8.0
	add_child(sfx_deny)
	sfx_frozen = AudioStreamPlayer.new()
	sfx_frozen.stream = load("res://audio/sfx_mutation_frozen.wav") as AudioStream
	sfx_frozen.volume_db = -6.0
	add_child(sfx_frozen)
	sfx_blind = AudioStreamPlayer.new()
	sfx_blind.stream = load("res://audio/sfx_mutation_blind.wav") as AudioStream
	sfx_blind.volume_db = -8.0
	add_child(sfx_blind)
	sfx_coin = AudioStreamPlayer.new()
	sfx_coin.stream = load("res://audio/sfx_coin.wav") as AudioStream
	sfx_coin.volume_db = -6.0
	add_child(sfx_coin)
	bgm = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://audio/bgm.wav") as AudioStreamWAV
	if stream != null:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
	bgm.stream = stream
	bgm.volume_db = -16.0 if UserData.music_on else -80.0
	add_child(bgm)
	if UserData.music_on and bgm.stream != null:
		bgm.play()


func _place_floor() -> void:
	if floor_body != null and is_instance_valid(floor_body):
		floor_body.queue_free()
	if not game_root.visible or board_panel == null:
		return
	# 先等布局稳定
	await get_tree().process_frame
	var rect: Rect2 = board_panel.get_global_rect()
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(rect.get_center().x, rect.end.y + 26.0)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(rect.size.x + 140.0, 10.0)
	shape.shape = box
	floor_body.add_child(shape)
	physics_root.add_child(floor_body)


# ---------------- 关卡流程 ----------------

func show_menu() -> void:
	screen_mode = "menu"
	timing = false
	paused = false
	clear_overlays()
	menu_root.visible = true
	game_root.visible = false
	_fx_ensure()
	if _merge_pending_on_menu:
		var auth: Node = get_node_or_null("/root/Auth")
		if auth != null and bool(auth.get("merge_pending")):
			_merge_pending_on_menu = false
			_show_merge_dialog()


func _update_coin_label() -> void:
	if coin_label != null:
		coin_label.text = str(UserData.coins)


func _refresh_auth_icon() -> void:
	if auth_btn == null:
		return
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null:
		return
	var signed: bool = str(auth.get("state")) == "signed_in"
	auth_btn.icon = UIKitRef.icon("cloud" if signed else "cloud_off")
	auth_btn.modulate = Color(0.80, 1.0, 0.80) if signed else Color(0.86, 0.90, 0.86)
	auth_btn.tooltip_text = "登录状态：" + str(auth.call("status_label"))


func _sync_cloud_on_start() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null or not bool(auth.call("is_signed_in")) or bool(auth.get("merge_pending")):
		return
	if _cloud_sync_done:
		return
	_cloud_sync_done = true
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud != null:
		cloud.call("sync_on_login")


func _on_auth_changed() -> void:
	_refresh_auth_icon()
	_fx_ensure()
	_fx_write_diag()
	var auth: Node = get_node_or_null("/root/Auth")
	var signed: bool = auth != null and bool(auth.call("is_signed_in"))
	if _auth_panel_open:
		_open_auth_panel()
	if signed and not _was_signed_in:
		_show_toast("check", "登录成功")
	_was_signed_in = signed
	if not signed:
		_cloud_sync_done = false
		return
	if auth != null and bool(auth.get("merge_pending")):
		if screen_mode == "menu":
			_show_merge_dialog()
		else:
			_merge_pending_on_menu = true
		return
	# 登录完成（合并也处理完）→ 云端同步一次：比较本地/云端时间，较新的覆盖
	if not _cloud_sync_done:
		_cloud_sync_done = true
		var cloud: Node = get_node_or_null("/root/CloudSave")
		if cloud != null:
			cloud.call("sync_on_login")


func _on_user_saved() -> void:
	## 进度变化后自动上传云端（测试/截图模式不联网）
	if UserData.test_mode or _suppress_alerts or not _was_signed_in:
		return
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud == null or not bool(cloud.call("can_sync")):
		return
	cloud.call("queue_upload", UserData.export_dict())


func _on_cloud_sync_finished(ok: bool, data: Variant, _updated_at: String, _message: String) -> void:
	if not ok:
		return
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud == null:
		return
	if data == null:
		# 云端还没有存档 → 把本地记录先传上去
		cloud.call("upload", UserData.export_dict(), true)
		return
	# 合并云端记录（金币取大、进度取大、记录合并），绝不回退本地进度
	UserData.merge_from_dict(data as Dictionary)
	style_def = StylesRef.get_style(UserData.selected_style)
	_build_styleboxes()
	if cells.size() > 0:
		_refresh()
	_update_coin_label()
	cloud.call("upload", UserData.export_dict(), true)
	_show_toast("check", "已同步云端记录")


func _open_auth_panel() -> void:
	clear_overlays()
	var auth: Node = get_node_or_null("/root/Auth")
	var signed: bool = auth != null and bool(auth.call("is_signed_in"))
	var configured: bool = auth != null and bool(auth.get("configured"))
	var vbox: VBoxContainer = _overlay_base(Vector2(660, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon("cloud" if signed else "cloud_off")
	icon_rect.custom_minimum_size = Vector2(88, 88)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = Color(0.80, 1.0, 0.80) if signed else UIKitRef.COL_DIM
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = str(auth.call("status_label")) if auth != null else "本地模式"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	if signed:
		var email_text: String = str(auth.get("phone"))
		if email_text != "":
			var phone_lbl: Label = Label.new()
			phone_lbl.text = email_text
			phone_lbl.add_theme_font_size_override("font_size", 20)
			phone_lbl.add_theme_color_override("font_color", UIKitRef.COL_DIM)
			phone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(phone_lbl)
		vbox.add_child(row)
		var upload_btn: Button = UIKitRef.icon_button("upload", 68)
		upload_btn.tooltip_text = "上传存档到云端"
		upload_btn.pressed.connect(_cloud_upload_pressed)
		row.add_child(upload_btn)
		var download_btn: Button = UIKitRef.icon_button("download", 68)
		download_btn.tooltip_text = "从云端下载存档"
		download_btn.pressed.connect(_cloud_download_pressed)
		row.add_child(download_btn)
		var logout_btn: Button = UIKitRef.icon_button("close", 68)
		logout_btn.tooltip_text = "退出登录"
		logout_btn.pressed.connect(_auth_logout)
		row.add_child(logout_btn)
	elif configured:
		_auth_phone_edit = LineEdit.new()
		_auth_phone_edit.placeholder_text = "手机号"
		_auth_phone_edit.custom_minimum_size = Vector2(460, 46)
		_auth_phone_edit.add_theme_font_size_override("font_size", 22)
		vbox.add_child(_auth_phone_edit)
		_auth_password_edit = LineEdit.new()
		_auth_password_edit.placeholder_text = "密码（至少 6 位）"
		_auth_password_edit.secret = true
		_auth_password_edit.custom_minimum_size = Vector2(460, 46)
		_auth_password_edit.add_theme_font_size_override("font_size", 22)
		vbox.add_child(_auth_password_edit)
		_auth_error_label = Label.new()
		_auth_error_label.text = str(auth.get("last_error"))
		_auth_error_label.add_theme_font_size_override("font_size", 18)
		_auth_error_label.add_theme_color_override("font_color", Color("ff9b8a"))
		_auth_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_auth_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_auth_error_label.custom_minimum_size = Vector2(460, 0)
		vbox.add_child(_auth_error_label)
		vbox.add_child(row)
		var login_btn: Button = UIKitRef.icon_button("cloud", 68)
		login_btn.tooltip_text = "登录"
		login_btn.pressed.connect(_auth_signin_pressed)
		row.add_child(login_btn)
		var signup_btn: Button = UIKitRef.icon_button("check", 68)
		signup_btn.tooltip_text = "注册新账号"
		signup_btn.pressed.connect(_auth_signup_pressed)
		row.add_child(signup_btn)
	else:
		vbox.add_child(row)
	var close_btn: Button = UIKitRef.icon_button("back", 68)
	close_btn.tooltip_text = "返回"
	close_btn.pressed.connect(clear_overlays)
	row.add_child(close_btn)
	_auth_panel_open = true


func _auth_signin_pressed() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null or _auth_phone_edit == null or _auth_password_edit == null:
		return
	auth.call("sign_in", _auth_phone_edit.text, _auth_password_edit.text)


func _auth_signup_pressed() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null or _auth_phone_edit == null or _auth_password_edit == null:
		return
	auth.call("sign_up", _auth_phone_edit.text, _auth_password_edit.text)


func _auth_logout() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth != null:
		auth.call("logout")
	clear_overlays()
	_refresh_auth_icon()


func _cloud_upload_pressed() -> void:
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud == null or not bool(cloud.call("can_sync")):
		_show_toast("close", "请先登录")
		return
	cloud.call("upload", UserData.export_dict())


func _cloud_download_pressed() -> void:
	_show_confirm("从云端下载", "云端存档会覆盖本机当前进度，确定继续？", "download", _cloud_download_now)


func _cloud_download_now() -> void:
	var cloud: Node = get_node_or_null("/root/CloudSave")
	if cloud == null or not bool(cloud.call("can_sync")):
		_show_toast("close", "请先登录")
		return
	cloud.call("download")


func _on_cloud_uploaded(ok: bool, message: String) -> void:
	if message.strip_edges() == "":
		return
	_show_toast("check" if ok else "close", message)


func _on_cloud_downloaded(ok: bool, data: Variant, message: String) -> void:
	if ok and data is Dictionary:
		UserData.overwrite_from_dict(data as Dictionary)
		style_def = StylesRef.get_style(UserData.selected_style)
		_build_styleboxes()
		if cells.size() > 0:
			_refresh()
		_update_coin_label()
		_open_auth_panel()
		_show_toast("check", message)
	else:
		_show_toast("close", message)


func _show_confirm(title_text: String, body_text: String, icon_name: String, on_confirm: Callable) -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(640, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(88, 88)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UIKitRef.COL_ACCENT
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(540, 0)
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	var ok_btn: Button = UIKitRef.icon_button("check", 68)
	ok_btn.tooltip_text = "确定"
	ok_btn.pressed.connect(func() -> void:
		clear_overlays()
		on_confirm.call())
	row.add_child(ok_btn)
	var cancel_btn: Button = UIKitRef.icon_button("back", 68)
	cancel_btn.tooltip_text = "取消"
	cancel_btn.pressed.connect(clear_overlays)
	row.add_child(cancel_btn)


func _show_merge_dialog() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(700, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon("cloud")
	icon_rect.custom_minimum_size = Vector2(88, 88)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UIKitRef.COL_ACCENT
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = "选择存档"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.text = "检测到本地存档与账号存档，请选择保留哪一个（只选择一次）"
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	vbox.add_child(row)
	var local_btn: Button = UIKitRef.icon_button("home", 72)
	local_btn.tooltip_text = "保留本地存档"
	local_btn.pressed.connect(_resolve_merge.bind("local"))
	row.add_child(local_btn)
	var account_btn: Button = UIKitRef.icon_button("cloud", 72)
	account_btn.tooltip_text = "使用账号存档"
	account_btn.pressed.connect(_resolve_merge.bind("account"))
	row.add_child(account_btn)


func _resolve_merge(choice: String) -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth != null:
		auth.call("resolve_merge", choice)
	_merge_pending_on_menu = false
	clear_overlays()
	_refresh_auth_icon()


func _on_start_pressed() -> void:
	if not UserData.tutorial_done:
		menu_root.visible = false
		_open_help(true)
		return
	_open_mode_select()


func _daily_today_key() -> String:
	var wt: Node = get_node_or_null("/root/WorldTime")
	if wt != null:
		var k: String = str(wt.call("today_key"))
		if k != "":
			return k
		return str(wt.call("local_today_key"))
	return ""


func _on_daily_pressed() -> void:
	var wt: Node = get_node_or_null("/root/WorldTime")
	var online: bool = wt != null and bool(wt.get("synced")) and not bool(wt.get("offline"))
	if not online:
		_show_notice("每日挑战需要联网", "无法获取服务器时间，请检查网络后重试（常规挑战可离线游玩）", "cloud_off",
			func() -> void:
				if wt != null:
					wt.call("sync"))
		return
	var key: String = str(wt.call("today_key"))
	if UserData.daily_done_key == key:
		_show_notice("今日已完成", "每日挑战每天只能通关一次，明天 0 点刷新", "check", Callable())
		return
	start_run("daily")


func _show_notice(title_text: String, body_text: String, icon_name: String, retry: Callable) -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(660, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(92, 92)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UIKitRef.COL_ACCENT
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	vbox.add_child(row)
	if retry.is_valid():
		var retry_btn: Button = UIKitRef.icon_button("reset", 64)
		retry_btn.tooltip_text = "重试"
		retry_btn.pressed.connect(func() -> void:
			clear_overlays()
			retry.call())
		row.add_child(retry_btn)
	var back: Button = UIKitRef.icon_button("back", 64)
	back.tooltip_text = "返回"
	back.pressed.connect(clear_overlays)
	row.add_child(back)


func _show_toast(icon_name: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	_last_toast = text
	if overlay_root == null:
		return
	if _toast_node != null and is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var panel: PanelContainer = UIKitRef.overlay_panel(Vector2(0, 0))
	panel.add_theme_stylebox_override("panel", UIKitRef.make_sb(Color("08110a", 0.94), UIKitRef.COL_ACCENT, 18, 2))
	overlay_root.add_child(panel)
	_toast_node = panel
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UIKitRef.icon(icon_name)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UIKitRef.COL_ACCENT
	row.add_child(icon)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	row.add_child(lbl)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = 84
	panel.offset_bottom = 140
	var tw: Tween = create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)


func _big_card() -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(286, 300)
	b.focus_mode = Control.FOCUS_NONE
	UIKitRef.apply_btn_styles(b,
		UIKitRef.make_sb(Color(0.04, 0.09, 0.05, 0.85), Color(0.30, 0.43, 0.27), 20, 2),
		UIKitRef.make_sb(Color(0.13, 0.22, 0.14, 0.95), Color(0.66, 0.84, 0.52), 20, 2))
	return b


func _open_mode_select() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(700, 0))
	_overlay_title(vbox, "play", "选择模式")
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	vbox.add_child(row)

	var infinite_card: Button = _big_card()
	infinite_card.pressed.connect(func() -> void: start_run("infinite"))
	row.add_child(infinite_card)
	var iv: VBoxContainer = VBoxContainer.new()
	iv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	infinite_card.add_child(iv)
	iv.add_child(_card_icon("infinity"))
	iv.add_child(_card_text("常规挑战", 32, UIKitRef.COL_TEXT))
	var inf_sub: String = "当前第 %d 关" % maxi(1, UserData.infinite_level)
	iv.add_child(_card_text(inf_sub, 19, UIKitRef.COL_DIM))

	var daily_card: Button = _big_card()
	daily_card.pressed.connect(_on_daily_pressed)
	row.add_child(daily_card)
	var dv: VBoxContainer = VBoxContainer.new()
	dv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	daily_card.add_child(dv)
	dv.add_child(_card_icon("calendar"))
	dv.add_child(_card_text("每日挑战", 32, UIKitRef.COL_TEXT))
	var daily_done: bool = false
	var wt: Node = get_node_or_null("/root/WorldTime")
	if wt != null and bool(wt.get("synced")):
		daily_done = UserData.daily_done_key == str(wt.call("today_key"))
	var daily_sub: String = "今日已完成" if daily_done else "每天 10 关"
	dv.add_child(_card_text(daily_sub, 19, UIKitRef.COL_DIM))
	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 8)
	dv.add_child(reward_row)
	var coin_icon: TextureRect = TextureRect.new()
	coin_icon.texture = UIKitRef.icon("coin")
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color("ffd166")
	reward_row.add_child(coin_icon)
	var reward_label: Label = Label.new()
	reward_label.text = "+%d" % LevelPlanRef.COIN_REWARD_DAILY
	reward_label.add_theme_font_size_override("font_size", 24)
	reward_label.add_theme_color_override("font_color", UIKitRef.COL_ACCENT)
	reward_row.add_child(reward_label)
	if daily_done:
		reward_label.text = "今日已完成"
		reward_label.add_theme_color_override("font_color", UIKitRef.COL_DIM)

	var back: Button = UIKitRef.icon_button("back", 54)
	back.tooltip_text = "返回"
	back.pressed.connect(clear_overlays)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(back)


func _card_icon(icon_name: String) -> TextureRect:
	var tex: TextureRect = TextureRect.new()
	tex.texture = UIKitRef.icon(icon_name)
	tex.custom_minimum_size = Vector2(96, 96)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = UIKitRef.COL_ACCENT
	return tex


func _card_text(txt: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func start_run(p_mode: String = "infinite") -> void:
	mode = p_mode
	if mode == "infinite":
		# 常规模式保留本地进度：继续上次的关卡与种子
		if UserData.infinite_seed == 0:
			UserData.infinite_seed = LevelPlanRef.new_run_seed()
		run_seed = UserData.infinite_seed
		level = max(1, UserData.infinite_level)
	else:
		level = 1
		run_seed = LevelPlanRef.new_run_seed()
		_daily_key = _daily_today_key()
	run_time = 0.0
	timing = true
	paused = false
	solved = false
	undo_used = false
	hint_used = false
	screen_mode = "game"
	menu_root.visible = false
	game_root.visible = true
	clear_overlays()
	_load_level()


func _load_level() -> void:
	level_start_time = run_time
	paused = false
	solved = false
	clear_overlays()
	var n: int
	var target: int
	var seed_value: int
	var locked_count: int = 2
	if mode == "daily":
		n = LevelPlanRef.daily_grid_size(level)
		target = LevelPlanRef.daily_target(level)
		mutation = LevelPlanRef.daily_mutation(level)
		seed_value = LevelPlanRef.daily_level_seed(level, _daily_key)
	else:
		n = LevelPlanRef.infinite_grid_size(level)
		target = LevelPlanRef.infinite_target(level)
		mutation = LevelPlanRef.infinite_mutation(level)
		seed_value = LevelPlanRef.infinite_seed(run_seed, level)
		locked_count = LevelPlanRef.infinite_locked_count(level)
	mutation_icon = LevelPlanRef.mutation_icon(mutation)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var locked: int = 0
	if mutation == "frozen":
		var pool: Array = []
		for i in range(n * n):
			pool.append(i)
		for _k in range(locked_count):
			if pool.is_empty():
				break
			var idx: int = rng.randi_range(0, pool.size() - 1)
			locked |= 1 << (pool[idx] as int)
			pool.remove_at(idx)
	room = PuzzleEngineRef.generate(rng, n, target, locked)
	state = room["state"] as int
	initial_state = state
	step_limit = int(room.get("optimal", 0)) + 2
	failed = false
	if mode == "infinite":
		UserData.best_infinite = max(UserData.best_infinite, level)
		UserData.save()
	history_cells.clear()
	net = 0
	undo_used = false
	hint_used = false
	_rebuild_grid(n)
	_refresh()
	_update_hud()
	_update_buttons()
	_place_floor()
	if mutation != "" and not _suppress_alerts:
		_show_mutation_alert()


func _cell_size(n: int) -> int:
	if n <= 3:
		return 108
	if n == 4:
		return 96
	if n == 5:
		return 84
	if n == 6:
		return 74
	if n == 7:
		return 66
	return 60


func _rebuild_grid(n: int) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cells.clear()
	grid.columns = n
	cell_px = _cell_size(n)
	for i in range(n * n):
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(cell_px, cell_px)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_cell_pressed.bind(i))
		var pattern_layer: Control = PatternRef.new() as Control
		pattern_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pattern_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(pattern_layer)
		var decal_layer: Control = DecalRef.new() as Control
		decal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(decal_layer)
		grid.add_child(b)
		cells.append(b)


func _refresh() -> void:
	var locked: int = room.get("locked", 0) as int
	var blind: bool = mutation == "blind"
	var pattern: String = style_def.get("pattern", "none") as String
	var accent: Color = style_def.get("accent", Color(1, 1, 1, 0.3)) as Color
	for i in range(cells.size()):
		var btn: Button = cells[i] as Button
		var is_locked: bool = ((locked >> i) & 1) != 0
		var is_on: bool = ((state >> i) & 1) != 0
		btn.disabled = is_locked
		var pattern_layer: Control = null
		if btn.get_child_count() > 0:
			pattern_layer = btn.get_child(0) as Control
		if pattern_layer != null and pattern_layer.has_method("setup"):
			var eff_accent: Color = accent
			if blind:
				eff_accent = Color(0.55, 0.62, 0.52, 0.30)
			pattern_layer.setup(pattern, eff_accent, blind)
			pattern_layer.visible = (not is_locked) and pattern != "none" and (is_on or blind)
		var decal_layer: Control = null
		if btn.get_child_count() > 1:
			decal_layer = btn.get_child(1) as Control
		if decal_layer != null and decal_layer.has_method("setup"):
			var decal_kind: String = ""
			if is_locked and mutation == "frozen":
				decal_kind = "frozen"
			elif blind and not is_locked:
				decal_kind = "blind"
			decal_layer.setup(decal_kind, Color(0.78, 0.90, 1.0, 0.85))
			decal_layer.visible = decal_kind != ""
		if is_locked:
			var frozen: StyleBoxFlat = _sb_frozen_on if is_on else _sb_frozen
			for s in ["normal", "hover", "pressed", "focus", "disabled"]:
				btn.add_theme_stylebox_override(s, frozen)
			continue
		var normal: StyleBoxFlat = _sb_on if is_on else _sb_off
		var hover: StyleBoxFlat = _sb_on_hover if is_on else _sb_off_hover
		if blind:
			normal = _sb_blind_on if is_on else _sb_blind_off
			hover = normal
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_stylebox_override("focus", normal)
		btn.add_theme_stylebox_override("disabled", normal)


func _remaining() -> int:
	var n: int = room.get("n", 0) as int
	if n == 0:
		return 0
	return PuzzleEngineRef.popcount(PuzzleEngineRef.all_on(n) & (~state))


func _update_hud() -> void:
	if mode == "daily":
		level_label.text = "%d/%d" % [level, LevelPlanRef.DAILY_LEVELS]
	else:
		level_label.text = str(level)
	UIKitRef.stat_label(hud["steps"] as HBoxContainer).text = "%d/%d" % [net, step_limit]
	var steps_lbl: Label = UIKitRef.stat_label(hud["steps"] as HBoxContainer)
	var steps_col: Color = UIKitRef.COL_TEXT
	if step_limit > 0 and net >= step_limit:
		steps_col = Color("ff6b6b")
	elif step_limit > 0 and net == step_limit - 1:
		steps_col = Color("ffb36b")
	steps_lbl.add_theme_color_override("font_color", steps_col)
	UIKitRef.stat_label(hud["optimal"] as HBoxContainer).text = str(room.get("optimal", 0))
	UIKitRef.stat_label(hud["remaining"] as HBoxContainer).text = str(_remaining())
	if mutation_icon == "":
		mutation_rect.visible = false
	else:
		mutation_rect.texture = UIKitRef.icon(mutation_icon)
		mutation_rect.visible = true
	if dots_box != null:
		dots_box.visible = mode == "daily"
		for i in range(dots.size()):
			var dot: Panel = dots[i] as Panel
			var sb: StyleBoxFlat = _dot_todo
			if i < level - 1:
				sb = _dot_done
			elif i == level - 1:
				sb = _dot_current
			dot.add_theme_stylebox_override("panel", sb)


func _update_buttons() -> void:
	if pause_btn != null:
		pause_btn.disabled = solved or failed
	if undo_btn != null:
		undo_btn.disabled = solved or failed or undo_used or history_cells.is_empty()
	if hint_btn != null:
		hint_btn.disabled = solved or failed or hint_used or mutation_icon == "lock"
	if reset_btn != null:
		reset_btn.disabled = solved or failed


func _on_cell_pressed(cell: int) -> void:
	if alert_open or failed:
		return
	if solved or paused:
		return
	var n: int = room.get("n", 0) as int
	if n == 0:
		return
	var locked: int = room.get("locked", 0) as int
	if ((locked >> cell) & 1) != 0:
		return
	state = PuzzleEngineRef.apply_press(state, cell, n)
	history_cells.append(cell)
	net += 1
	sfx_click.play()
	_refresh()
	_update_hud()
	_update_buttons()
	var btn: Button = cells[cell] as Button
	_spawn_sparks(btn.global_position + Vector2(cell_px, cell_px) * 0.5, COL_ON)
	if state == PuzzleEngineRef.all_on(n):
		_clear_level()
		return
	if net >= step_limit:
		_fail_level()


func _fail_level() -> void:
	if failed:
		return
	failed = true
	timing = false
	sfx_deny.play()
	_update_buttons()
	_show_fail_overlay()


func _show_fail_overlay() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(580, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon("steps")
	icon_rect.custom_minimum_size = Vector2(92, 92)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = Color("ff8a7a")
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = "步数用尽"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.text = "本关步数上限很紧：%d 步，用尽即失败" % step_limit
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	var retry: Button = UIKitRef.icon_button("reset", 72)
	retry.tooltip_text = "重试本关"
	retry.pressed.connect(_restart_level)
	row.add_child(retry)
	var home: Button = UIKitRef.icon_button("home", 72)
	home.tooltip_text = "返回主页"
	home.pressed.connect(_to_menu)
	row.add_child(home)


func _clear_level() -> void:
	solved = true
	_update_buttons()
	sfx_win.play()
	_confetti()
	await get_tree().create_timer(0.9).timeout
	if mode == "daily" and level >= LevelPlanRef.DAILY_LEVELS:
		_victory()
		return
	# 常规模式：每清一关立即写入常规记录与历史（而不是等整轮结束）
	if mode == "infinite":
		var level_seconds: float = maxf(0.1, run_time - level_start_time)
		UserData.add_history(level_seconds, level, "infinite")
		UserData.record_infinite_clear(level, level_seconds)
	level += 1
	if mode == "infinite":
		UserData.infinite_level = level
		UserData.infinite_seed = run_seed
		UserData.save()
	_load_level()


func _victory() -> void:
	timing = false
	paused = false
	solved = true
	var reward: int = 0
	if mode == "daily":
		var key: String = _daily_key if _daily_key != "" else _daily_today_key()
		if UserData.daily_done_key != key:
			reward = LevelPlanRef.COIN_REWARD_DAILY
			UserData.coins += reward
			UserData.daily_done_key = key
			UserData.daily_claimed = key
			UserData.save()
		UserData.add_history(run_time, LevelPlanRef.DAILY_LEVELS, "daily")
		UserData.record_daily_clear(key, run_time)
		_update_coin_label()
		_show_victory_overlay(run_time, reward)
	else:
		UserData.add_history(run_time, level, "infinite")
		UserData.record_infinite_clear(level, run_time)
		_show_victory_overlay(run_time, 0)


func _on_undo() -> void:
	if solved or failed or paused or undo_used or history_cells.is_empty():
		return
	undo_used = true
	var cell: int = history_cells.pop_back() as int
	state = PuzzleEngineRef.apply_press(state, cell, room.get("n", 0) as int)
	net -= 1
	sfx_click.play()
	_refresh()
	_update_hud()
	_update_buttons()


func _on_reset() -> void:
	if solved or failed or paused:
		return
	state = initial_state
	history_cells.clear()
	net = 0
	sfx_click.play()
	_refresh()
	_update_hud()
	_update_buttons()


func _on_hint() -> void:
	if solved or failed or paused or hint_used:
		return
	if LevelPlanRef.mutation_icon(mutation) == "lock":
		return
	hint_used = true
	_update_buttons()
	var n: int = room.get("n", 0) as int
	var res: Dictionary = PuzzleEngineRef.solve(state, n, room.get("locked", 0) as int)
	if not (res["ok"] as bool):
		return
	var presses: int = res["presses"] as int
	if presses == 0:
		return
	var cell: int = 0
	for i in range(n * n):
		if ((presses >> i) & 1) != 0:
			cell = i
			break
	_flash_cell(cell)


func _flash_cell(cell: int) -> void:
	if cell < 0 or cell >= cells.size():
		return
	var btn: Button = cells[cell] as Button
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.16, 1.16), 0.10)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.16)


# ---------------- 物理特效 ----------------

func _spawn_sparks(pos: Vector2, color: Color, count: int = 4) -> void:
	if physics_root == null:
		return
	for _i in range(count):
		var body: RigidBody2D = RigidBody2D.new()
		body.position = pos
		body.gravity_scale = 1.4
		body.linear_damp = 1.2
		body.angular_damp = 2.0
		body.collision_layer = 2
		body.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 3.0
		shape.shape = circle
		body.add_child(shape)
		var poly: Polygon2D = Polygon2D.new()
		var s: float = randf_range(2.6, 4.2)
		poly.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		poly.color = color
		body.add_child(poly)
		body.apply_central_impulse(Vector2(randf_range(-90, 90), randf_range(-220, -80)))
		physics_root.add_child(body)
		get_tree().create_timer(0.9).timeout.connect(body.queue_free)


func _confetti() -> void:
	if physics_root == null:
		return
	var rect: Rect2 = board_panel.get_global_rect()
	var colors: Array = [COL_ON, Color("7fbf5f"), Color("ff9b9b"), Color("8fd6ff"), Color("ffffff")]
	for _i in range(18):
		var body: RigidBody2D = RigidBody2D.new()
		body.position = rect.get_center() + Vector2(randf_range(-120, 120), randf_range(-40, 40))
		body.gravity_scale = 1.1
		body.linear_damp = 0.8
		body.collision_layer = 2
		body.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 2.5
		shape.shape = circle
		body.add_child(shape)
		var poly: Polygon2D = Polygon2D.new()
		var s: float = randf_range(2.0, 3.6)
		poly.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		poly.color = colors[randi_range(0, colors.size() - 1)] as Color
		body.add_child(poly)
		body.apply_central_impulse(Vector2(randf_range(-240, 240), randf_range(-420, -160)))
		physics_root.add_child(body)
		get_tree().create_timer(1.4).timeout.connect(body.queue_free)


# ---------------- 覆盖层 ----------------

func clear_overlays() -> void:
	_auth_panel_open = false
	for child in overlay_root.get_children():
		overlay_root.remove_child(child)
		child.queue_free()


func _overlay_base(min_size: Vector2) -> VBoxContainer:
	overlay_root.add_child(UIKitRef.dim_layer(0.55))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(center)
	var panel: PanelContainer = UIKitRef.overlay_panel(min_size)
	center.add_child(panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	return vbox


func _overlay_title(vbox: VBoxContainer, icon_name: String, text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var tex: TextureRect = TextureRect.new()
	tex.texture = UIKitRef.icon(icon_name)
	tex.custom_minimum_size = Vector2(36, 36)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(tex)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	row.add_child(label)
	vbox.add_child(row)


func _toggle_pause() -> void:
	if alert_open:
		return
	if screen_mode != "game" or solved:
		return
	paused = not paused
	if paused:
		_open_pause()
	else:
		clear_overlays()


func _open_pause() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(440, 0))
	_overlay_title(vbox, "pause", "暂停")
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	vbox.add_child(row)
	var resume: Button = UIKitRef.icon_button("play", 76)
	resume.tooltip_text = "继续"
	resume.pressed.connect(_toggle_pause)
	row.add_child(resume)
	var restart: Button = UIKitRef.icon_button("reset", 76)
	restart.tooltip_text = "重新开始本关"
	restart.pressed.connect(_restart_level)
	row.add_child(restart)
	var home: Button = UIKitRef.icon_button("home", 76)
	home.tooltip_text = "返回主页"
	home.pressed.connect(_to_menu)
	row.add_child(home)


func _restart_level() -> void:
	failed = false
	timing = true
	paused = false
	clear_overlays()
	_load_level()


func _to_menu() -> void:
	if mode == "infinite" and screen_mode == "game":
		UserData.infinite_level = level
		UserData.infinite_seed = run_seed
		UserData.save()
	timing = false
	paused = false
	clear_overlays()
	show_menu()


func _open_settings() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(560, 0))
	_overlay_title(vbox, "gear", "设置")

	var volume_row: HBoxContainer = HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	var vol_icon: TextureRect = TextureRect.new()
	vol_icon.texture = UIKitRef.icon("volume")
	vol_icon.custom_minimum_size = Vector2(28, 28)
	vol_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vol_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	volume_row.add_child(vol_icon)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = UserData.volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260, 32)
	slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(slider)
	vbox.add_child(volume_row)

	var fs_row: HBoxContainer = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 14)
	fs_row.add_child(_small_icon("expand"))
	var fs_btn: CheckButton = CheckButton.new()
	fs_btn.tooltip_text = "全屏"
	fs_btn.button_pressed = UserData.fullscreen
	fs_btn.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(fs_btn)
	vbox.add_child(fs_row)

	var music_row: HBoxContainer = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 14)
	music_row.add_child(_small_icon("music"))
	var music_btn: CheckButton = CheckButton.new()
	music_btn.tooltip_text = "音乐开关"
	music_btn.button_pressed = UserData.music_on
	music_btn.toggled.connect(_on_music_toggled)
	music_row.add_child(music_btn)
	vbox.add_child(music_row)

	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 14)
	size_row.add_child(_small_icon("monitor"))
	var size_opt: OptionButton = OptionButton.new()
	size_opt.add_theme_font_size_override("font_size", 22)
	size_opt.custom_minimum_size = Vector2(240, 46)
	for i in range(WINDOW_LABELS.size()):
		size_opt.add_item(WINDOW_LABELS[i] as String, i)
	var current_idx: int = 1
	for i in range(WINDOW_SIZES.size()):
		var candidate: Vector2i = WINDOW_SIZES[i]
		if candidate == UserData.window_size:
			current_idx = i
	size_opt.select(current_idx)
	size_opt.item_selected.connect(_on_window_size_selected)
	size_row.add_child(size_opt)
	vbox.add_child(size_row)

	var reset_row: HBoxContainer = HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reset_row.add_theme_constant_override("separation", 12)
	var reset_btn: Button = UIKitRef.icon_button("reset", 54)
	reset_btn.tooltip_text = "重置常规模式进度"
	reset_btn.pressed.connect(_reset_infinite_progress)
	reset_row.add_child(reset_btn)
	var reset_label: Label = Label.new()
	reset_label.text = "常规进度"
	reset_label.add_theme_font_size_override("font_size", 20)
	reset_label.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	reset_row.add_child(reset_label)
	vbox.add_child(reset_row)

	var back: Button = UIKitRef.icon_button("back", 64)
	back.tooltip_text = "返回"
	back.pressed.connect(clear_overlays)
	vbox.add_child(back)


func _reset_infinite_progress() -> void:
	UserData.infinite_level = 1
	UserData.infinite_seed = 0
	UserData.save()
	_open_settings()


func _on_volume_changed(value: float) -> void:
	UserData.volume = value
	UserData.apply_settings()
	UserData.save()


func _on_fullscreen_toggled(pressed: bool) -> void:
	UserData.fullscreen = pressed
	UserData.apply_settings()
	UserData.save()


func _on_music_toggled(pressed: bool) -> void:
	UserData.music_on = pressed
	if bgm != null:
		bgm.volume_db = -16.0 if pressed else -80.0
		if pressed and bgm.stream != null and not bgm.playing:
			bgm.play()
	UserData.save()


func _on_window_size_selected(index: int) -> void:
	if index < 0 or index >= WINDOW_SIZES.size():
		return
	var win_size: Vector2i = WINDOW_SIZES[index]
	UserData.window_size = win_size
	UserData.apply_settings()
	UserData.save()


func _open_shop() -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(900, 0))
	_overlay_title(vbox, "shop", "商店")

	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)
	var coin_icon: TextureRect = TextureRect.new()
	coin_icon.texture = UIKitRef.icon("coin")
	coin_icon.custom_minimum_size = Vector2(32, 32)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color("ffd166")
	header.add_child(coin_icon)
	var coins_label: Label = Label.new()
	coins_label.text = str(UserData.coins)
	coins_label.add_theme_font_size_override("font_size", 30)
	coins_label.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	header.add_child(coins_label)

	var gridc: GridContainer = GridContainer.new()
	gridc.columns = 3
	gridc.add_theme_constant_override("h_separation", 18)
	gridc.add_theme_constant_override("v_separation", 18)
	gridc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(gridc)
	for style in StylesRef.all():
		gridc.add_child(_style_card(style))
	_update_coin_label()

	var back: Button = UIKitRef.icon_button("back", 54)
	back.tooltip_text = "返回"
	back.pressed.connect(clear_overlays)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(back)


func _style_card(style: Dictionary) -> Button:
	var id: String = style["id"] as String
	var price: int = style["price"] as int
	var owned: bool = UserData.owned_styles.has(id)
	var selected: bool = UserData.selected_style == id
	var card: Button = _big_card()
	card.custom_minimum_size = Vector2(238, 228)
	card.tooltip_text = style["name"] as String
	card.pressed.connect(_on_style_pressed.bind(style))
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var prev: GridContainer = GridContainer.new()
	prev.columns = 3
	prev.add_theme_constant_override("h_separation", 4)
	prev.add_theme_constant_override("v_separation", 4)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(9):
		var cell: Panel = Panel.new()
		cell.custom_minimum_size = Vector2(20, 20)
		var is_on: bool = i % 2 == 0
		var bg: Color = (style["on"] if is_on else style["off"]) as Color
		var border: Color = (style["on_border"] if is_on else style["off_border"]) as Color
		cell.add_theme_stylebox_override("panel", UIKitRef.make_sb(bg, border, 3, 1))
		prev.add_child(cell)
	v.add_child(prev)
	v.add_child(_card_text(style["name"] as String, 22, UIKitRef.COL_TEXT))

	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 6)
	v.add_child(bottom_row)
	if owned:
		if selected:
			var check: TextureRect = TextureRect.new()
			check.texture = UIKitRef.icon("check")
			check.custom_minimum_size = Vector2(24, 24)
			check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			check.modulate = UIKitRef.COL_ACCENT
			bottom_row.add_child(check)
		else:
			bottom_row.add_child(_card_text("使用", 20, UIKitRef.COL_DIM))
	else:
		var c_icon: TextureRect = TextureRect.new()
		c_icon.texture = UIKitRef.icon("coin")
		c_icon.custom_minimum_size = Vector2(24, 24)
		c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_icon.modulate = Color("ffd166") if UserData.coins >= price else Color(0.7, 0.6, 0.4, 0.6)
		bottom_row.add_child(c_icon)
		var price_label: Label = Label.new()
		price_label.text = str(price)
		price_label.add_theme_font_size_override("font_size", 22)
		price_label.add_theme_color_override("font_color",
			UIKitRef.COL_TEXT if UserData.coins >= price else UIKitRef.COL_DIM)
		bottom_row.add_child(price_label)
	return card


func _on_style_pressed(style: Dictionary) -> void:
	var id: String = style["id"] as String
	var price: int = style["price"] as int
	var style_name: String = str(style["name"])
	if UserData.owned_styles.has(id):
		_equip_style(id)
		_show_toast("check", "已装备：" + style_name)
		return
	if UserData.coins < price:
		if sfx_deny != null:
			sfx_deny.play()
		_show_toast("coin", "金币不足（还差 %d）" % (price - UserData.coins))
		return
	UserData.coins -= price
	UserData.owned_styles.append(id)
	UserData.selected_style = id
	UserData.record_purchase(id, price)
	UserData.save()
	_equip_style(id)
	_update_coin_label()
	if sfx_coin != null:
		sfx_coin.play()
	_show_toast("check", "购买成功：" + style_name)


func _equip_style(id: String) -> void:
	UserData.selected_style = id
	style_def = StylesRef.get_style(id)
	UserData.save()
	_build_styleboxes()
	if cells.size() > 0:
		_refresh()
	_update_coin_label()
	_open_shop()


func _open_history(p_mode: String = "") -> void:
	if p_mode != "":
		_history_mode = p_mode
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(700, 0))
	_overlay_title(vbox, "clock", "通关记录")

	# 模式切换（每日 / 常规）
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 20)
	vbox.add_child(tabs)
	var daily_tab: Button = UIKitRef.icon_button("calendar", 54)
	daily_tab.tooltip_text = "每日记录"
	if _history_mode == "daily":
		daily_tab.modulate = UIKitRef.COL_ACCENT
	daily_tab.pressed.connect(func() -> void: _open_history("daily"))
	tabs.add_child(daily_tab)
	var inf_tab: Button = UIKitRef.icon_button("infinity", 54)
	inf_tab.tooltip_text = "常规记录"
	if _history_mode == "infinite":
		inf_tab.modulate = UIKitRef.COL_ACCENT
	inf_tab.pressed.connect(func() -> void: _open_history("infinite"))
	tabs.add_child(inf_tab)

	var rec: Dictionary = UserData.records.get("infinite" if _history_mode == "infinite" else "daily", {}) as Dictionary
	var summary: HBoxContainer = HBoxContainer.new()
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 26)
	if _history_mode == "infinite":
		summary.add_child(UIKitRef.stat("trophy", "%d" % int(rec.get("clear_count", 0)), 26, 24))
		summary.add_child(UIKitRef.stat("clock", UserData.format_time(float(rec.get("total_seconds", 0))), 26, 24))
	else:
		var days: Array = rec.get("cleared_days", []) as Array
		summary.add_child(UIKitRef.stat("calendar", "%d" % days.size(), 26, 24))
		summary.add_child(UIKitRef.stat("clock", UserData.format_time(float(rec.get("total_seconds", 0))), 26, 24))
	vbox.add_child(summary)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var rows: Array = []
	for item in UserData.history:
		var item_mode: String = str((item as Dictionary).get("mode", "daily"))
		if item_mode == _history_mode:
			rows.append(item)
	if rows.is_empty():
		var empty: Label = Label.new()
		empty.text = "暂无记录"
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", UIKitRef.COL_DIM)
		list.add_child(empty)
	else:
		for item in rows:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var date_label: Label = Label.new()
			date_label.text = UserData.format_date(int(item.get("ts", 0)))
			date_label.add_theme_font_size_override("font_size", 18)
			date_label.add_theme_color_override("font_color", UIKitRef.COL_DIM)
			date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(date_label)
			var time_row: HBoxContainer = UIKitRef.stat("clock", UserData.format_time(float(item.get("seconds", 0.0))), 22, 20)
			row.add_child(time_row)
			var cleared_row: HBoxContainer = UIKitRef.stat("trophy", "%d" % int(item.get("cleared", 0)), 22, 20)
			row.add_child(cleared_row)
			list.add_child(row)

	var back: Button = UIKitRef.icon_button("back", 60)
	back.tooltip_text = "返回"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(clear_overlays)
	vbox.add_child(back)


var _help_start_after: bool = false


func _open_help(start_after: bool = false) -> void:
	_help_start_after = start_after
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(900, 0))
	var title: Label = Label.new()
	title.text = "灯泡方块"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "点亮每一盏灯"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_help_section(content, "玩法")
	_help_row(content, "hand", "点方格：它和上下左右四格一起切换亮灭")
	_help_row(content, "bulb", "全部点亮即可过关")
	_help_row(content, "infinity", "常规挑战：无限关，可离线，进度自动保存在本机")
	_help_row(content, "calendar", "每日挑战：每天 10 关，需联网，每天只能通关一次")
	_help_row(content, "steps", "每关步数上限很紧，规划好再点；步数用尽即失败")

	_help_section(content, "变异块")
	_help_row(content, "eye", "幽暗：格子几乎同色，明暗差别极细微，印花模糊")
	_help_row(content, "snow", "冰封：部分格子被冰封不能点，带雪花印花")
	_help_row(content, "lock", "硬化：本关提示被禁用")
	_help_row(content, "help", "进入变异关时会先弹警示说明")

	_help_section(content, "图标含义")
	_help_row(content, "play", "开始游戏 / 继续")
	_help_row(content, "shop", "商店：用金币购买方块风格")
	_help_row(content, "gear", "设置：音量、音乐、窗口尺寸、全屏、重置常规进度")
	_help_row(content, "clock", "通关记录（每日 / 常规分开）")
	_help_row(content, "coin", "金币：每日挑战通关 +100")
	_help_row(content, "flag", "关卡进度与已通关次数")
	_help_row(content, "undo", "撤销：每关 1 次")
	_help_row(content, "reset", "重置：每关不限次数，步数清零")
	_help_row(content, "hint", "提示：每关 1 次，闪烁一个应点的格子")
	_help_row(content, "pause", "暂停：继续 / 重开本关 / 返回主页")
	_help_row(content, "steps", "已用步数 / 步数上限")
	_help_row(content, "target", "本关最优步数")
	_help_row(content, "bulb", "剩余未点亮的灯数量")
	_help_row(content, "cloud", "登录状态：云 = 已登录，斜杠云 = 本地模式")
	_help_row(content, "home", "返回主页")

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	vbox.add_child(row)
	if _help_start_after:
		var go: Button = UIKitRef.icon_button("play", 72)
		go.tooltip_text = "开始挑战"
		go.pressed.connect(_finish_help)
		row.add_child(go)
	var back: Button = UIKitRef.icon_button("back", 72)
	back.tooltip_text = "关闭"
	back.pressed.connect(_close_help)
	row.add_child(back)


func _help_section(parent: VBoxContainer, text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", UIKitRef.COL_ACCENT)
	lbl.custom_minimum_size = Vector2(0, 40)
	parent.add_child(lbl)


func _help_row(parent: VBoxContainer, icon_name: String, text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UIKitRef.icon(icon_name)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UIKitRef.COL_ACCENT
	row.add_child(icon)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	parent.add_child(row)


func _finish_help() -> void:
	if _help_start_after:
		UserData.tutorial_done = true
		UserData.save()
		_help_start_after = false
		clear_overlays()
		_open_mode_select()
	else:
		clear_overlays()


func _close_help() -> void:
	if _help_start_after:
		_finish_help()
	else:
		clear_overlays()


func _show_mutation_alert() -> void:
	alert_open = true
	paused = true
	if mutation == "frozen" and sfx_frozen != null:
		sfx_frozen.play()
	elif mutation == "blind" and sfx_blind != null:
		sfx_blind.play()
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(640, 0))
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = UIKitRef.icon(mutation_icon)
	icon_rect.custom_minimum_size = Vector2(104, 104)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = UIKitRef.COL_ACCENT
	vbox.add_child(icon_rect)
	var title: Label = Label.new()
	title.text = LevelPlanRef.mutation_name(mutation)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var body: Label = Label.new()
	body.text = LevelPlanRef.mutation_desc(mutation)
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", UIKitRef.COL_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(540, 0)
	vbox.add_child(body)
	var btn: Button = UIKitRef.icon_button("check", 68)
	btn.tooltip_text = "知道了"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_dismiss_mutation_alert)
	vbox.add_child(btn)


func _dismiss_mutation_alert() -> void:
	alert_open = false
	paused = false
	clear_overlays()


func _show_victory_overlay(seconds: float, reward: int = 0) -> void:
	clear_overlays()
	var vbox: VBoxContainer = _overlay_base(Vector2(520, 0))
	var trophy: TextureRect = TextureRect.new()
	trophy.texture = UIKitRef.icon("trophy")
	trophy.custom_minimum_size = Vector2(88, 88)
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.modulate = UIKitRef.COL_ACCENT
	vbox.add_child(trophy)
	var done: Label = Label.new()
	done.text = "每日通关" if mode == "daily" else "全部通关"
	done.add_theme_font_size_override("font_size", 40)
	done.add_theme_color_override("font_color", UIKitRef.COL_TEXT)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(done)
	var time_row: HBoxContainer = UIKitRef.stat("clock", UserData.format_time(seconds), 40, 52)
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(time_row)
	if mode == "daily":
		var coin_row: HBoxContainer = HBoxContainer.new()
		coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
		coin_row.add_theme_constant_override("separation", 10)
		vbox.add_child(coin_row)
		var coin_icon: TextureRect = TextureRect.new()
		coin_icon.texture = UIKitRef.icon("coin")
		coin_icon.custom_minimum_size = Vector2(40, 40)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.modulate = Color("ffd166")
		coin_row.add_child(coin_icon)
		var reward_label: Label = Label.new()
		reward_label.add_theme_font_size_override("font_size", 34)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if reward > 0:
			reward_label.text = "+%d" % reward
			reward_label.add_theme_color_override("font_color", UIKitRef.COL_ACCENT)
		else:
			reward_label.text = "今日已领取"
			reward_label.add_theme_color_override("font_color", UIKitRef.COL_DIM)
		coin_row.add_child(reward_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)
	var home: Button = UIKitRef.icon_button("home", 76)
	home.tooltip_text = "返回主页"
	home.pressed.connect(_to_menu)
	row.add_child(home)
	var again: Button = UIKitRef.icon_button("play", 76)
	again.tooltip_text = "再来一局"
	again.pressed.connect(func() -> void: start_run(mode))
	row.add_child(again)


# ---------------- 测试与截图模式 ----------------

func _auto_demo() -> void:
	print("=== AUTO DEMO: 常规（无限）+ 每日 自动最优解 ===")
	var fails: int = 0
	var demo_seed: int = 20261125
	var levels: Array = [1, 5, 10, 25, 50, 75, 100, 110, 130, 160]
	for lv in levels:
		fails += _validate_level(false, lv, demo_seed)
	for i in range(1, LevelPlanRef.DAILY_LEVELS + 1):
		fails += _validate_level(true, i)
	print("AUTO_DEMO_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _validate_level(is_daily: bool, lv: int, demo_seed: int = 0) -> int:
	var tag: String = "daily" if is_daily else "inf"
	var n: int
	var target: int
	var mut: String
	var seed_value: int
	var locked_count: int = 2
	if is_daily:
		n = LevelPlanRef.daily_grid_size(lv)
		target = LevelPlanRef.daily_target(lv)
		mut = LevelPlanRef.daily_mutation(lv)
		seed_value = LevelPlanRef.daily_level_seed(lv)
	else:
		n = LevelPlanRef.infinite_grid_size(lv)
		target = LevelPlanRef.infinite_target(lv)
		mut = LevelPlanRef.infinite_mutation(lv)
		seed_value = LevelPlanRef.infinite_seed(demo_seed, lv)
		locked_count = LevelPlanRef.infinite_locked_count(lv)
	var fails: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var locked: int = 0
	if mut == "frozen":
		var pool: Array = []
		for i in range(n * n):
			pool.append(i)
		for _k in range(locked_count):
			if pool.is_empty():
				break
			var idx: int = rng.randi_range(0, pool.size() - 1)
			locked |= 1 << (pool[idx] as int)
			pool.remove_at(idx)
	var data: Dictionary = PuzzleEngineRef.generate(rng, n, target, locked)
	var res: Dictionary = PuzzleEngineRef.solve(data["state"] as int, n, locked)
	if not (res["ok"] as bool):
		print("FAIL %s L%d unsolvable" % [tag, lv])
		return 1
	var presses: int = res["presses"] as int
	var final_state: int = PuzzleEngineRef.apply_presses(data["state"] as int, presses, n)
	var steps: int = PuzzleEngineRef.popcount(presses)
	print("%s L%d: n=%d target=%d optimal=%d solved_in=%d locked=%d mut=%s" % [
		tag, lv, n, target, data["optimal"], steps, locked, mut])
	if final_state != PuzzleEngineRef.all_on(n):
		fails += 1
		print("FAIL %s L%d solution invalid" % [tag, lv])
	if steps != (data["optimal"] as int):
		fails += 1
		print("FAIL %s L%d optimal mismatch %d vs %d" % [tag, lv, steps, data["optimal"]])
	return fails


func _ui_test() -> void:
	print("=== UI TEST ===")
	var fails: int = 0
	# 深拷贝真实存档（export_dict 里的数组是引用，测试会追加记录）
	var preserve: Dictionary = JSON.parse_string(JSON.stringify(UserData.export_dict())) as Dictionary
	_suppress_alerts = true
	UserData.infinite_level = 1
	UserData.infinite_seed = 0
	UserData.coins = 0
	UserData.daily_claimed = ""
	UserData.daily_done_key = ""
	UserData.owned_styles = ["default"]
	UserData.selected_style = "default"
	style_def = StylesRef.get_style("default")
	start_run("infinite")
	# 1) 撤销只能用一次
	_on_cell_pressed(0)
	if net != 1:
		fails += 1
		print("FAIL: press net=%d" % net)
	_on_undo()
	if net != 0 or state != initial_state:
		fails += 1
		print("FAIL: undo not reverted")
	_on_cell_pressed(0)
	_on_undo()
	if net != 1:
		fails += 1
		print("FAIL: second undo should be blocked, net=%d" % net)
	_on_reset()
	if net != 0 or state != initial_state:
		fails += 1
		print("FAIL: reset")
	# 2) 提示只能用一次
	_on_hint()
	if not hint_used:
		fails += 1
		print("FAIL: hint not used")
	var hint_flag: bool = hint_used
	_on_hint()
	if hint_flag != hint_used:
		fails += 1
		print("FAIL: second hint should be blocked")
	# 3) 解第一关 → 自动进第二关（常规模式不会结束）
	var n1: int = room.get("n", 0) as int
	var res: Dictionary = PuzzleEngineRef.solve(state, n1, room.get("locked", 0) as int)
	var presses: int = res["presses"] as int
	for i in range(n1 * n1):
		if ((presses >> i) & 1) != 0:
			_on_cell_pressed(i)
			await get_tree().process_frame
	if not solved:
		fails += 1
		print("FAIL: level 1 not solved")
	await get_tree().create_timer(1.4).timeout
	if level != 2:
		fails += 1
		print("FAIL: level=%d expected 2" % level)
	# 3.5) 常规模式本地进度：清关后保存，重开继续
	if UserData.infinite_level != 2:
		fails += 1
		print("FAIL: infinite progress not saved (%d)" % UserData.infinite_level)
	start_run("infinite")
	if level != 2:
		fails += 1
		print("FAIL: infinite resume level=%d expected 2" % level)
	# 4) 暂停开关
	_toggle_pause()
	if not paused:
		fails += 1
		print("FAIL: pause on")
	_toggle_pause()
	if paused:
		fails += 1
		print("FAIL: pause off")
	# 4.5) 变异警示弹窗
	_suppress_alerts = false
	level = 5
	_load_level()
	if not alert_open:
		fails += 1
		print("FAIL: mutation alert not shown")
	if not paused:
		fails += 1
		print("FAIL: mutation alert should pause")
	_dismiss_mutation_alert()
	if alert_open or paused:
		fails += 1
		print("FAIL: mutation alert not dismissed")
	_suppress_alerts = true
	level = 1
	_load_level()
	# 4.6) 变异印花：冰封关的锁格应有最上层雪花印花
	level = 5
	_load_level()
	var frozen_marks: int = 0
	for btn in cells:
		var b: Button = btn as Button
		if b.get_child_count() > 1 and (b.get_child(1) as Control).visible:
			frozen_marks += 1
	if frozen_marks == 0:
		fails += 1
		print("FAIL: mutation decal missing")
	level = 1
	_load_level()
	# 4.7) 步数限制：超过上限 → 失败弹窗
	level = 1
	_load_level()
	if step_limit != int(room.get("optimal", 0)) + 2:
		fails += 1
		print("FAIL: step_limit=%d" % step_limit)
	net = step_limit
	_on_cell_pressed(0)
	if not failed:
		fails += 1
		print("FAIL: step limit not enforced")
	if overlay_root.get_child_count() == 0:
		fails += 1
		print("FAIL: fail overlay missing")
	_restart_level()
	if failed or net != 0:
		fails += 1
		print("FAIL: retry after fail")
	# 4.8) 记录分模式 + 常规最高关卡
	UserData.add_history(10.0, 10, "daily")
	UserData.add_history(20.0, 5, "infinite")
	if str((UserData.history[0] as Dictionary).get("mode", "")) != "infinite":
		fails += 1
		print("FAIL: history mode not stored")
	_open_history("infinite")
	if overlay_root.get_child_count() == 0:
		fails += 1
		print("FAIL: history overlay missing")
	clear_overlays()
	if UserData.best_infinite < level:
		fails += 1
		print("FAIL: best_infinite=%d level=%d" % [UserData.best_infinite, level])
	# 4.9) 每日挑战：离线拦截 / 联网可进 / 今日已完成拦截
	var wt: Node = get_node_or_null("/root/WorldTime")
	if wt == null:
		fails += 1
		print("FAIL: WorldTime autoload missing")
	else:
		wt.set("synced", false)
		wt.set("offline", true)
		show_menu()
		_on_daily_pressed()
		if screen_mode == "game":
			fails += 1
			print("FAIL: offline daily should be blocked")
		wt.set("server_unix", int(Time.get_unix_time_from_system()))
		wt.set("synced", true)
		wt.set("offline", false)
		_on_daily_pressed()
		if screen_mode != "game":
			fails += 1
			print("FAIL: online daily should start")
		UserData.daily_done_key = str(wt.call("today_key"))
		show_menu()
		_on_daily_pressed()
		if screen_mode == "game":
			fails += 1
			print("FAIL: completed daily should be blocked")
		UserData.daily_done_key = ""
		clear_overlays()
	# 5) 每日模式：直接通关第 10 关 → +100 金币 + 胜利页
	start_run("daily")
	level = LevelPlanRef.DAILY_LEVELS
	_load_level()
	var n10: int = room.get("n", 0) as int
	var res10: Dictionary = PuzzleEngineRef.solve(state, n10, room.get("locked", 0) as int)
	var presses10: int = res10["presses"] as int
	for i in range(n10 * n10):
		if ((presses10 >> i) & 1) != 0:
			_on_cell_pressed(i)
			await get_tree().process_frame
	await get_tree().create_timer(1.4).timeout
	if UserData.coins != LevelPlanRef.COIN_REWARD_DAILY:
		fails += 1
		print("FAIL: daily reward coins=%d" % UserData.coins)
	if UserData.daily_claimed != LevelPlanRef.today_string():
		fails += 1
		print("FAIL: daily_claimed not set")
	if overlay_root.get_child_count() == 0:
		fails += 1
		print("FAIL: victory overlay missing")
	# 6) 同一天重复领取不加金币
	var coins_before: int = UserData.coins
	_victory()
	if UserData.coins != coins_before:
		fails += 1
		print("FAIL: daily reward granted twice")
	# 7) 商店购买：金币不足提示 / 购买成功提示
	UserData.coins = 0
	_open_shop()
	_on_style_pressed(StylesRef.get_style("sakura"))
	if UserData.coins != 0:
		fails += 1
		print("FAIL: insufficient coins should not deduct")
	if not _last_toast.contains("金币不足"):
		fails += 1
		print("FAIL: missing insufficient toast (%s)" % _last_toast)
	UserData.coins = 500
	_open_shop()
	_on_style_pressed(StylesRef.get_style("sakura"))
	if not _last_toast.contains("购买成功"):
		fails += 1
		print("FAIL: missing purchase toast (%s)" % _last_toast)
	if not UserData.owned_styles.has("sakura"):
		fails += 1
		print("FAIL: style not owned")
	if UserData.selected_style != "sakura":
		fails += 1
		print("FAIL: style not equipped")
	if (style_def.get("id", "") as String) != "sakura":
		fails += 1
		print("FAIL: style_def not applied")
	# 8) 登录/存档：默认 local_guest，存档路径 user://saves/<user_id>/slot_0.json
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null:
		fails += 1
		print("FAIL: Auth autoload missing")
	else:
		var uid: String = str(auth.get("user_id"))
		if uid == "":
			fails += 1
			print("FAIL: Auth user_id empty")
		elif uid != "local_guest" and not AuthLogic.valid_user_id(uid):
			fails += 1
			print("FAIL: Auth user_id invalid: %s" % uid)
	var sp: String = UserData.save_path()
	if not sp.contains("/saves/") or not sp.ends_with("/slot_0.json"):
		fails += 1
		print("FAIL: save path %s" % sp)
	if not FileAccess.file_exists(UserData.save_path()):
		fails += 1
		print("FAIL: save file missing at %s" % UserData.save_path())
	# 9) 存档导出/覆盖（云上传/下载的基础）
	UserData.coins = 321
	UserData.infinite_level = 9
	var snap: Dictionary = UserData.export_dict()
	UserData.coins = 0
	UserData.infinite_level = 1
	UserData.overwrite_from_dict(snap)
	if UserData.coins != 321 or UserData.infinite_level != 9:
		fails += 1
		print("FAIL: export/overwrite roundtrip")
	# 10) 幽暗：亮/灭保留约 22% 亮度差，且斜纹已减淡
	var l_on: float = _sb_blind_on.bg_color.get_luminance()
	var l_off: float = _sb_blind_off.bg_color.get_luminance()
	var rel: float = (l_on - l_off) / maxf(l_off, 0.0001)
	if rel < 0.19 or rel > 0.26:
		fails += 1
		print("FAIL: blind brightness diff %.3f (expect ~0.22)" % rel)
	# 11) 旧存档迁移：丢弃错误最高关，从历史重建常规/每日记录
	UserData.best_infinite = 77
	UserData.history = [
		{"ts": 1700000000, "seconds": 10, "cleared": 3, "mode": "infinite"},
		{"ts": 1700000100, "seconds": 20, "cleared": 9, "mode": "infinite"},
		{"ts": 1700000200, "seconds": 30, "cleared": 10, "mode": "daily"},
	]
	UserData.records = {}
	UserData.purchases = []
	UserData.meta = {"version": 1, "updated_at": "2026-01-01T00:00:00Z"}
	UserData.migrate_records()
	if UserData.best_infinite != 9:
		fails += 1
		print("FAIL: migration best_infinite=%d (expect 9)" % UserData.best_infinite)
	var inf_mig: Dictionary = UserData.records.get("infinite", {}) as Dictionary
	if int(inf_mig.get("clear_count", 0)) != 2:
		fails += 1
		print("FAIL: migration infinite clear_count")
	var day_mig: Dictionary = UserData.records.get("daily", {}) as Dictionary
	if (day_mig.get("cleared_days", []) as Array).size() != 1:
		fails += 1
		print("FAIL: migration daily days")
	# 12) 模式选择卡不再显示“最高关”
	_open_mode_select()
	var labels: Array = []
	_collect_label_texts(overlay_root, labels)
	for text in labels:
		if str(text).contains("最高"):
			fails += 1
			print("FAIL: mode card still shows best record: %s" % str(text))
			break
	clear_overlays()
	# 14) 云同步合并不回退：金币/进度取大、记录合并
	UserData.coins = 100
	UserData.infinite_level = 2
	UserData.records = {
		"infinite": {"best_level": 3, "clear_count": 1, "total_seconds": 5},
		"daily": {"clear_count": 1, "cleared_days": ["2026-01-01"], "total_seconds": 5},
	}
	UserData.history = []
	UserData.owned_styles = ["default"]
	UserData.merge_from_dict({
		"coins": 300,
		"infinite_level": 9,
		"infinite_seed": 123,
		"records": {
			"infinite": {"best_level": 77, "clear_count": 5, "total_seconds": 60},
			"daily": {"clear_count": 2, "cleared_days": ["2026-01-02"], "total_seconds": 30},
		},
		"history": [{"ts": 1, "seconds": 2, "cleared": 77, "mode": "infinite"}],
		"owned_styles": ["default", "sakura"],
	})
	if UserData.coins != 300 or UserData.infinite_level != 9 or UserData.best_infinite != 77:
		fails += 1
		print("FAIL: merge coins/level/best")
	var merged_inf: Dictionary = UserData.records.get("infinite", {}) as Dictionary
	if int(merged_inf.get("clear_count", 0)) != 5:
		fails += 1
		print("FAIL: merge infinite count")
	var merged_day: Dictionary = UserData.records.get("daily", {}) as Dictionary
	if (merged_day.get("cleared_days", []) as Array).size() != 2:
		fails += 1
		print("FAIL: merge daily days")
	if not UserData.owned_styles.has("sakura"):
		fails += 1
		print("FAIL: merge styles")
	# 先还原测试前的真实存档（在退出登录之前，保证写回原账号/本地路径）
	UserData.overwrite_from_dict(preserve)
	# 13) 最后测退出登录 + 登录面板输入框（会切回 local_guest）
	if auth != null:
		auth.call("logout")
		_open_auth_panel()
		var edits: Array = []
		_collect_line_edits(overlay_root, edits)
		if edits.size() < 2:
			fails += 1
			print("FAIL: auth panel line edits %d" % edits.size())
		clear_overlays()
	print("UI_TEST_RESULT fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _collect_line_edits(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is LineEdit:
			out.append(child)
		_collect_line_edits(child, out)


func _collect_label_texts(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		_collect_label_texts(child, out)


func _shot(shot_name: String) -> void:
	_suppress_alerts = true
	if sun != null and sun.force_hour < 0.0:
		sun.force_hour = 10.0
		sun.refresh()
	match shot_name:
		"menu":
			show_menu()
		"mode":
			show_menu()
			_open_mode_select()
		"shop":
			show_menu()
			UserData.coins = 250
			_update_coin_label()
			_open_shop()
		"game":
			menu_root.visible = false
			start_run("infinite")
		"daily":
			menu_root.visible = false
			start_run("daily")
		"pause":
			menu_root.visible = false
			start_run("infinite")
			_toggle_pause()
		"victory":
			menu_root.visible = false
			start_run("daily")
			run_time = 214.0
			_show_victory_overlay(214.0, LevelPlanRef.COIN_REWARD_DAILY)
		"mutation":
			menu_root.visible = false
			start_run("infinite")
			_suppress_alerts = false
			level = 5
			_load_level()
		"decal":
			menu_root.visible = false
			start_run("infinite")
			level = 5
			_load_level()
		"blind":
			menu_root.visible = false
			start_run("infinite")
			level = 15
			_load_level()
		"fail":
			menu_root.visible = false
			start_run("infinite")
			net = step_limit
			_fail_level()
		"history":
			show_menu()
			_open_history("daily")
		"auth":
			show_menu()
			await get_tree().create_timer(1.8).timeout
			_open_auth_panel()
		"notice":
			show_menu()
			var wt: Node = get_node_or_null("/root/WorldTime")
			if wt != null:
				wt.set("synced", false)
				wt.set("offline", true)
			_on_daily_pressed()
		"tutorial":
			menu_root.visible = true
			_open_help(false)
	await get_tree().create_timer(0.8).timeout
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OS.get_user_data_dir().path_join("shot_%s.png" % shot_name)
	var err: int = img.save_png(path)
	print("SHOT_PATH=", path, " err=", err)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if err == OK else 1)
