extends Node
## 联网时间（用于每日挑战）：从服务器取 UTC 时间，再叠加本地时区得到“今天”的日期。
## 联网失败不阻塞游戏：offline=true，普通模式照常玩；每日挑战由 main 拦截提示。

signal time_changed

const TIMEOUT_SEC: float = 6.0

var server_unix: int = 0     # 最近一次同步到的 UTC 秒
var synced: bool = false
var offline: bool = true
var last_error: String = ""
var tz_bias_min: int = 0     # Godot: 东八区为 +480

var _http: HTTPRequest
var _attempt: int = 0        # 0=Supabase Date 头, 1=worldtimeapi, 2=timeapi.io


func _ready() -> void:
	var tz: Dictionary = Time.get_time_zone_from_system()
	tz_bias_min = int(tz.get("bias", 0))
	call_deferred("sync")


func sync() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT_SEC
		add_child(_http)
		_http.request_completed.connect(_on_response)
	_attempt = 0
	_try_next()


func _try_next() -> void:
	var auth: Node = get_node_or_null("/root/Auth")
	var headers: PackedStringArray = PackedStringArray()
	var url: String = ""
	var method: int = HTTPClient.METHOD_GET
	if _attempt == 0 and auth != null and str(auth.get("supabase_url")) != "":
		url = str(auth.get("supabase_url")).rstrip("/") + "/auth/v1/health"
		method = HTTPClient.METHOD_GET
		if str(auth.get("supabase_key")) != "":
			headers = PackedStringArray(["apikey: " + str(auth.get("supabase_key"))])
	elif _attempt <= 1:
		url = "https://worldtimeapi.org/api/timezone/Etc/UTC"
	elif _attempt == 2:
		url = "https://timeapi.io/api/Time/current/zone?timeZone=UTC"
	if url == "":
		_set_offline("无可用的时间服务")
		return
	var err: int = _http.request(url, headers, method)
	if err != OK:
		_attempt += 1
		_try_next()


func _on_response(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var now: int = -1
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400:
		if _attempt == 0:
			now = _parse_http_date(_find_header(headers, "date"))
		elif _attempt == 1:
			now = _parse_worldtime(body.get_string_from_utf8())
		elif _attempt == 2:
			now = _parse_timeapi(body.get_string_from_utf8())
	if now > 0:
		server_unix = now
		synced = true
		offline = false
		last_error = ""
		time_changed.emit()
		return
	_attempt += 1
	if _attempt > 2:
		_set_offline("时间服务不可用")
	else:
		_try_next()


func _set_offline(reason: String) -> void:
	offline = true
	synced = false
	last_error = reason
	time_changed.emit()


func today_key() -> String:
	## 服务器 UTC + 本地时区 → YYYYMMDD；未同步返回 ""
	if not synced:
		return ""
	return key_from_unix(server_unix, tz_bias_min)


func local_today_key() -> String:
	## 离线兜底（仅用于展示/旧逻辑），每日挑战本身要求联网
	return key_from_unix(int(Time.get_unix_time_from_system()), tz_bias_min)


static func key_from_unix(unix: int, bias_min: int = 0) -> String:
	var local_unix: int = unix + bias_min * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix)
	return "%04d%02d%02d" % [d["year"], d["month"], d["day"]]


static func seconds_until_next_day(unix: int, bias_min: int = 0) -> int:
	var local_unix: int = unix + bias_min * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix)
	var passed: int = int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"])
	return 86400 - passed


func _find_header(headers: PackedStringArray, name: String) -> String:
	var lower: String = name.to_lower()
	for h in headers:
		var idx: int = h.find(":")
		if idx <= 0:
			continue
		if h.substr(0, idx).strip_edges().to_lower() == lower:
			return h.substr(idx + 1).strip_edges()
	return ""


func _parse_http_date(raw: String) -> int:
	## 例：Thu, 26 Nov 2026 04:25:28 GMT
	var s: String = raw.replace(",", "")
	var parts: PackedStringArray = s.split(" ", false)
	if parts.size() < 5:
		return -1
	var day: int = int(parts[1])
	var month: int = _month_index(parts[2])
	var year: int = int(parts[3])
	var clock: PackedStringArray = parts[4].split(":")
	if month <= 0 or clock.size() < 3:
		return -1
	return _utc_to_unix(year, month, day, int(clock[0]), int(clock[1]), int(clock[2]))


func _parse_worldtime(body: String) -> int:
	var json: Variant = JSON.parse_string(body)
	if not (json is Dictionary):
		return -1
	var d: Dictionary = json as Dictionary
	if d.has("unixtime"):
		return int(d["unixtime"])
	var dt: String = str(d.get("utc_datetime", ""))
	return _parse_iso_utc(dt)


func _parse_timeapi(body: String) -> int:
	var json: Variant = JSON.parse_string(body)
	if not (json is Dictionary):
		return -1
	var d: Dictionary = json as Dictionary
	return _parse_iso_utc(str(d.get("dateTime", "")))


func _parse_iso_utc(raw: String) -> int:
	if raw.length() < 19:
		return -1
	var date_part: String = raw.substr(0, 10)
	var time_part: String = raw.substr(11, 8)
	return int(Time.get_unix_time_from_datetime_string(date_part + "T" + time_part))


func _utc_to_unix(year: int, month: int, day: int, hour: int, minute: int, second: int) -> int:
	var dt: Dictionary = {
		"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute, "second": second,
	}
	return int(Time.get_unix_time_from_datetime_dict(dt))


func _month_index(name: String) -> int:
	var months: Array = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var idx: int = months.find(name)
	return idx + 1
