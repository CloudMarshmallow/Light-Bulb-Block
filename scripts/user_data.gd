extends Node
## 设置与闯关记录持久化（autoload：UserData）
## 存档路径：user://saves/<user_id>/slot_0.json（user_id 由 Auth 提供，离线为 local_guest）
## v2 存档新增：records（常规/每日记录汇总）、purchases（购买记录）、meta（版本/更新时间）

signal saved

const GUEST_ID: String = "local_guest"
const SAVE_VERSION: int = 2

const WINDOW_PRESETS: Array = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const WINDOW_PRESET_LABELS: Array = ["1024 × 576", "1280 × 720", "1600 × 900", "1920 × 1080"]

var volume: float = 0.7
var music_on: bool = true
var fullscreen: bool = false
var window_size: Vector2i = Vector2i(1280, 720)
var tutorial_done: bool = false
var coins: int = 0
var owned_styles: Array = ["default"]
var selected_style: String = "default"
var daily_claimed: String = ""
var daily_done_key: String = ""
var best_infinite: int = 0
var infinite_level: int = 1
var infinite_seed: int = 0
var history: Array = []
var records: Dictionary = {}
var purchases: Array = []
var meta: Dictionary = {}
var test_mode: bool = false   # 测试/截图/自动演示时写到独立测试存档，避免污染真实账号
var _loaded_user_id: String = GUEST_ID   # 与内存数据对应的账号（防止登录状态切换时写错路径）


func _ready() -> void:
	_load_fields_from_defaults()
	load_save()
	apply_settings()
	var auth: Node = get_node_or_null("/root/Auth")
	if auth != null and auth.has_signal("state_changed"):
		auth.state_changed.connect(_on_auth_state_changed)


func _load_fields_from_defaults() -> void:
	volume = 0.7
	music_on = true
	fullscreen = false
	window_size = Vector2i(1280, 720)
	tutorial_done = false
	coins = 0
	owned_styles = ["default"]
	selected_style = "default"
	daily_claimed = ""
	daily_done_key = ""
	best_infinite = 0
	infinite_level = 1
	infinite_seed = 0
	history = []
	records = _empty_records()
	purchases = []
	meta = {"version": SAVE_VERSION, "updated_at": _now_iso()}


func _empty_records() -> Dictionary:
	return {
		"infinite": {"best_level": 0, "clear_count": 0, "total_seconds": 0},
		"daily": {"clear_count": 0, "cleared_days": [], "total_seconds": 0},
	}


func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _on_auth_state_changed() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth == null:
		return
	# 登录后若待用户选择合并方式，先不重载（避免覆盖本地存档内容）
	if bool(auth.get("merge_pending")):
		return
	load_save()
	apply_settings()


func current_user_id() -> String:
	var auth: Node = get_node_or_null("/root/Auth")
	if auth != null:
		var uid: String = str(auth.get("user_id"))
		if AuthLogic.valid_user_id(uid):
			return uid
	return GUEST_ID


func save_path() -> String:
	if test_mode:
		return "user://saves/_test/slot_0.json"
	return AuthLogic.save_path_for(_loaded_user_id)


func _read_save_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return null
	return JSON.parse_string(text)


func load_save() -> void:
	_load_fields_from_defaults()
	_loaded_user_id = current_user_id()
	var path: String = save_path()
	var parsed: Variant = _read_save_json(path)
	# 主存档损坏时回退到上一份备份（原子写入前保留的 .bak）
	if not (parsed is Dictionary):
		parsed = _read_save_json(path + ".bak")
	if not (parsed is Dictionary):
		return
	_apply_dict(parsed as Dictionary)
	migrate_if_needed()


func _history_has_mode(mode: String) -> bool:
	for item in history:
		if item is Dictionary and str((item as Dictionary).get("mode", "daily")) == mode:
			return true
	return false


func migrate_if_needed() -> void:
	## 旧版（无 records）或 records 为空但 history 有数据时，从真实历史重建记录
	var needs: bool = int(meta.get("version", 1)) < SAVE_VERSION
	if not needs:
		var inf: Dictionary = records.get("infinite", {}) as Dictionary
		var day: Dictionary = records.get("daily", {}) as Dictionary
		if not records.has("infinite") or not records.has("daily"):
			needs = true
		elif int(inf.get("clear_count", 0)) == 0 and _history_has_mode("infinite"):
			needs = true
		elif int(day.get("clear_count", 0)) == 0 and _history_has_mode("daily"):
			needs = true
	if needs:
		migrate_records()
	else:
		best_infinite = int((records["infinite"] as Dictionary).get("best_level", best_infinite))


func _apply_dict(d: Dictionary) -> void:
	if d.has("volume"):
		volume = clampf(float(d["volume"]), 0.0, 1.0)
	if d.has("music_on"):
		music_on = bool(d["music_on"])
	if d.has("fullscreen"):
		fullscreen = bool(d["fullscreen"])
	if d.has("tutorial_done"):
		tutorial_done = bool(d["tutorial_done"])
	if d.has("coins"):
		coins = max(0, int(d["coins"]))
	if d.has("owned_styles") and (d["owned_styles"] is Array):
		owned_styles = d["owned_styles"] as Array
	if d.has("selected_style"):
		selected_style = str(d["selected_style"])
	if d.has("daily_claimed"):
		daily_claimed = str(d["daily_claimed"])
	if d.has("daily_done_key"):
		daily_done_key = str(d["daily_done_key"])
	if d.has("best_infinite"):
		best_infinite = int(d["best_infinite"])
	if d.has("infinite_level"):
		infinite_level = max(1, int(d["infinite_level"]))
	if d.has("infinite_seed"):
		infinite_seed = int(d["infinite_seed"])
	if d.has("window_size") and (d["window_size"] is Array):
		var arr: Array = d["window_size"] as Array
		if arr.size() == 2:
			window_size = Vector2i(int(arr[0]), int(arr[1]))
	if d.has("history") and (d["history"] is Array):
		history = d["history"] as Array
	if d.has("records") and (d["records"] is Dictionary):
		records = d["records"] as Dictionary
	if d.has("purchases") and (d["purchases"] is Array):
		purchases = d["purchases"] as Array
	if d.has("meta") and (d["meta"] is Dictionary):
		meta = d["meta"] as Dictionary


func _derive_records(hist: Array) -> Dictionary:
	var inf: Dictionary = {"best_level": 0, "clear_count": 0, "total_seconds": 0}
	var day: Dictionary = {"clear_count": 0, "cleared_days": [], "total_seconds": 0}
	var days: Dictionary = {}
	for item in hist:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item as Dictionary
		var m: String = str(e.get("mode", "daily"))
		var secs: int = int(e.get("seconds", 0))
		if m == "infinite":
			inf["clear_count"] = int(inf["clear_count"]) + 1
			inf["total_seconds"] = int(inf["total_seconds"]) + secs
			var lv: int = int(e.get("cleared", 0))
			if lv > int(inf["best_level"]):
				inf["best_level"] = lv
		else:
			day["clear_count"] = int(day["clear_count"]) + 1
			day["total_seconds"] = int(day["total_seconds"]) + secs
			var ts: int = int(e.get("ts", 0))
			var d: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
			days["%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]] = true
	day["cleared_days"] = days.keys()
	return {"infinite": inf, "daily": day}


func merge_from_dict(other: Dictionary) -> void:
	## 登录/手动同步时把另一份存档无损合并进来（金币取大、进度取大、记录合并，绝不回退进度）
	coins = max(coins, int(other.get("coins", 0)))
	var other_level: int = max(1, int(other.get("infinite_level", 1)))
	if other_level > infinite_level:
		infinite_level = other_level
		infinite_seed = int(other.get("infinite_seed", infinite_seed))
	# 皮肤/购买记录合并
	var merged_styles: Array = []
	for s in owned_styles:
		if not merged_styles.has(s):
			merged_styles.append(s)
	var other_styles: Variant = other.get("owned_styles", [])
	if other_styles is Array:
		for s in other_styles:
			if not merged_styles.has(s):
				merged_styles.append(s)
	owned_styles = merged_styles
	var buy_keys: Dictionary = {}
	var merged_purchases: Array = []
	for p in purchases + (other.get("purchases", []) as Array if other.get("purchases", []) is Array else []):
		if not (p is Dictionary):
			continue
		var key: String = "%s|%s" % [str((p as Dictionary).get("style", "")), str((p as Dictionary).get("at", ""))]
		if buy_keys.has(key):
			continue
		buy_keys[key] = true
		merged_purchases.append(p)
	purchases = merged_purchases
	# 记录合并
	var other_records: Dictionary = other.get("records", {}) as Dictionary
	if other_records.is_empty():
		other_records = _derive_records((other.get("history", []) as Array) if other.get("history", []) is Array else [])
	var a_inf: Dictionary = records.get("infinite", {}) as Dictionary
	var b_inf: Dictionary = other_records.get("infinite", {}) as Dictionary
	var a_day: Dictionary = records.get("daily", {}) as Dictionary
	var b_day: Dictionary = other_records.get("daily", {}) as Dictionary
	var inf: Dictionary = {
		"best_level": maxi(int(a_inf.get("best_level", 0)), int(b_inf.get("best_level", 0))),
		"clear_count": maxi(int(a_inf.get("clear_count", 0)), int(b_inf.get("clear_count", 0))),
		"total_seconds": maxi(int(a_inf.get("total_seconds", 0)), int(b_inf.get("total_seconds", 0))),
	}
	var days: Array = []
	for d in (a_day.get("cleared_days", []) as Array) + (b_day.get("cleared_days", []) as Array):
		if not days.has(d):
			days.append(d)
	var day: Dictionary = {
		"clear_count": maxi(int(a_day.get("clear_count", 0)), int(b_day.get("clear_count", 0))),
		"cleared_days": days,
		"total_seconds": maxi(int(a_day.get("total_seconds", 0)), int(b_day.get("total_seconds", 0))),
	}
	records = {"infinite": inf, "daily": day}
	best_infinite = int(inf["best_level"])
	# 通关历史合并（按 ts 去重，保留最近 20 条）
	var seen: Dictionary = {}
	var merged_hist: Array = []
	for item in history + ((other.get("history", []) as Array) if other.get("history", []) is Array else []):
		if not (item is Dictionary):
			continue
		var ts_key: String = "%d|%s" % [int((item as Dictionary).get("ts", 0)), str((item as Dictionary).get("mode", ""))]
		if seen.has(ts_key):
			continue
		seen[ts_key] = true
		merged_hist.append(item)
	merged_hist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("ts", 0)) > int(b.get("ts", 0)))
	if merged_hist.size() > 20:
		merged_hist.resize(20)
	history = merged_hist
	var other_daily_key: String = str(other.get("daily_done_key", ""))
	if other_daily_key > daily_done_key:
		daily_done_key = other_daily_key
	meta["version"] = SAVE_VERSION
	save()


func migrate_records() -> void:
	## 从 history 重建 records（旧版没有 records；旧“最高关”可能是测试残留 → 不再信任）
	records = _derive_records(history)
	best_infinite = int((records["infinite"] as Dictionary)["best_level"])
	# 购买记录从已拥有皮肤推导（旧版没有 purchases）
	if purchases.is_empty():
		purchases = []
		for style_key in owned_styles:
			var k: String = str(style_key)
			if k == "default":
				continue
			purchases.append({"style": k, "price": _style_price(k), "at": ""})
	meta["version"] = SAVE_VERSION
	save()


func _style_price(style_key: String) -> int:
	for st in Styles.all():
		var sd: Dictionary = st as Dictionary
		if str(sd.get("id", "")) == style_key:
			return int(sd.get("price", 0))
	return 0


func export_dict() -> Dictionary:
	## 完整存档（用于云上传 / 备份）
	return {
		"version": SAVE_VERSION,
		"meta": meta,
		"volume": volume,
		"music_on": music_on,
		"fullscreen": fullscreen,
		"window_size": [window_size.x, window_size.y],
		"tutorial_done": tutorial_done,
		"coins": coins,
		"owned_styles": owned_styles,
		"selected_style": selected_style,
		"purchases": purchases,
		"daily_claimed": daily_claimed,
		"daily_done_key": daily_done_key,
		"best_infinite": best_infinite,
		"infinite_level": infinite_level,
		"infinite_seed": infinite_seed,
		"records": records,
		"history": history,
	}


func overwrite_from_dict(d: Dictionary) -> void:
	## 用云端/备份数据覆盖本地（下载后调用）
	_load_fields_from_defaults()
	_apply_dict(d)
	migrate_if_needed()
	save()
	apply_settings()


func save() -> void:
	meta["version"] = SAVE_VERSION
	meta["updated_at"] = _now_iso()
	var d: Dictionary = export_dict()
	var path: String = save_path()
	var dir: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# 原子写入：先写临时文件，成功后再替换主文件；旧主文件留作 .bak 备份
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var err: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		return
	saved.emit()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var offset: Vector2i = usable.size - window_size
	var pos: Vector2i = usable.position + Vector2i(offset.x >> 1, offset.y >> 1)
	DisplayServer.window_set_position(pos)


func record_infinite_clear(level_cleared: int, seconds: float) -> void:
	if records.is_empty():
		migrate_records()
	var inf: Dictionary = records.get("infinite", {}) as Dictionary
	inf["clear_count"] = int(inf.get("clear_count", 0)) + 1
	inf["total_seconds"] = int(inf.get("total_seconds", 0)) + int(seconds)
	if level_cleared > int(inf.get("best_level", 0)):
		inf["best_level"] = level_cleared
	records["infinite"] = inf
	best_infinite = int(inf["best_level"])
	save()


func record_daily_clear(day_key: String, seconds: float) -> void:
	if records.is_empty():
		migrate_records()
	var day: Dictionary = records.get("daily", {}) as Dictionary
	day["clear_count"] = int(day.get("clear_count", 0)) + 1
	day["total_seconds"] = int(day.get("total_seconds", 0)) + int(seconds)
	var days: Array = day.get("cleared_days", []) as Array
	if day_key != "" and not days.has(day_key):
		days.append(day_key)
	day["cleared_days"] = days
	records["daily"] = day
	save()


func record_purchase(style_key: String, price: int) -> void:
	purchases.append({"style": style_key, "price": price, "at": _now_iso()})
	save()


func add_history(seconds: float, cleared: int, mode: String = "daily") -> void:
	history.push_front({
		"ts": int(Time.get_unix_time_from_system()),
		"seconds": seconds,
		"cleared": cleared,
		"mode": mode,
	})
	if history.size() > 20:
		history.resize(20)
	save()


func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var mm: int = floori(float(total) / 60.0)
	var ss: int = total % 60
	return "%02d:%02d" % [mm, ss]


func format_date(ts: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]
