extends Node
## 云存档：Supabase PostgREST（表 public.saves）
## - 手动上传 / 下载
## - 登录后自动同步（云端/本地取较新）
## - 游戏进度变化后自动上传（4 秒防抖）
## 未登录或网络不可用时只提示/静默失败，不影响本地游戏。

signal upload_finished(ok: bool, message: String)
signal download_finished(ok: bool, data: Variant, message: String)
signal sync_finished(ok: bool, data: Variant, updated_at: String, message: String)

const TIMEOUT_SEC: float = 12.0
const AUTO_UPLOAD_DELAY: float = 4.0

var busy: bool = false

var _http_up: HTTPRequest
var _http_down: HTTPRequest
var _sync_mode: bool = false
var _quiet_upload: bool = false
var _auto_timer: Timer
var _auto_data: Dictionary = {}
var _auto_pending: bool = false


func _ready() -> void:
	_http_up = HTTPRequest.new()
	_http_up.timeout = TIMEOUT_SEC
	add_child(_http_up)
	_http_up.request_completed.connect(_on_upload_done)
	_http_down = HTTPRequest.new()
	_http_down.timeout = TIMEOUT_SEC
	add_child(_http_down)
	_http_down.request_completed.connect(_on_download_done)
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.wait_time = AUTO_UPLOAD_DELAY
	add_child(_auto_timer)
	_auto_timer.timeout.connect(_on_auto_timeout)


func can_sync() -> bool:
	var auth: Node = get_node_or_null("/root/Auth")
	return auth != null and bool(auth.call("is_signed_in"))


func _auth() -> Node:
	return get_node_or_null("/root/Auth")


func upload(data: Dictionary, quiet: bool = false) -> void:
	if busy:
		upload_finished.emit(false, "正在同步，请稍候")
		return
	var auth: Node = _auth()
	if auth == null or not bool(auth.call("is_signed_in")):
		upload_finished.emit(false, "请先登录")
		return
	busy = true
	_quiet_upload = quiet
	var headers: PackedStringArray = PackedStringArray([
		"apikey: " + str(auth.get("supabase_key")),
		"Authorization: Bearer " + str(auth.get("access_token")),
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates",
	])
	var body: String = JSON.stringify({
		"user_id": str(auth.get("user_id")),
		"data": data,
		"updated_at": Time.get_datetime_string_from_system(true) + "Z",
	})
	var url: String = AuthLogic.cloud_upload_url(str(auth.get("supabase_url")))
	var err: int = _http_up.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		busy = false
		upload_finished.emit(false, "网络不可用，请稍后再试")


func download() -> void:
	if busy:
		download_finished.emit(false, null, "正在同步，请稍候")
		return
	var auth: Node = _auth()
	if auth == null or not bool(auth.call("is_signed_in")):
		download_finished.emit(false, null, "请先登录")
		return
	busy = true
	_sync_mode = false
	_chat_download(str(auth.get("supabase_url")), str(auth.get("supabase_key")), str(auth.get("access_token")), str(auth.get("user_id")))


func sync_on_login() -> void:
	## 登录后自动同步：拉云端数据，由主界面决定用云端还是本地覆盖
	if busy:
		return
	var auth: Node = _auth()
	if auth == null or not bool(auth.call("is_signed_in")):
		return
	busy = true
	_sync_mode = true
	_chat_download(str(auth.get("supabase_url")), str(auth.get("supabase_key")), str(auth.get("access_token")), str(auth.get("user_id")))


func queue_upload(data: Dictionary) -> void:
	## 进度变化后延迟自动上传（避免频繁请求）
	if not can_sync():
		return
	_auto_data = data
	_auto_pending = true
	_auto_timer.start()


func _chat_download(base: String, key: String, token: String, user_id: String) -> void:
	var headers: PackedStringArray = PackedStringArray([
		"apikey: " + key,
		"Authorization: Bearer " + token,
	])
	var url: String = AuthLogic.cloud_row_url(base, user_id) + "&select=data,updated_at"
	var err: int = _http_down.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		busy = false
		download_finished.emit(false, null, "网络不可用，请稍后再试")


func _on_auto_timeout() -> void:
	if not _auto_pending:
		return
	_auto_pending = false
	upload(_auto_data, true)


func _on_upload_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var quiet: bool = _quiet_upload
	_quiet_upload = false
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		upload_finished.emit(false, "" if quiet else "网络不可用，请稍后再试")
		return
	if code == 401 or code == 403:
		var a: Node = _auth()
		if a != null:
			a.call("try_login")
		upload_finished.emit(false, "" if quiet else "登录已过期，请重新登录")
		return
	if code >= 200 and code < 300:
		upload_finished.emit(true, "" if quiet else "已上传到云端")
	else:
		upload_finished.emit(false, "" if quiet else "云端保存失败，请稍后再试")


func _on_download_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sync_mode: bool = _sync_mode
	_sync_mode = false
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if sync_mode:
			sync_finished.emit(false, null, "", "网络不可用")
		else:
			download_finished.emit(false, null, "网络不可用，请稍后再试")
		return
	if code == 401 or code == 403:
		if sync_mode:
			sync_finished.emit(false, null, "", "登录已过期，请重新登录")
		else:
			download_finished.emit(false, null, "登录已过期，请重新登录")
		return
	if code < 200 or code >= 300:
		if sync_mode:
			sync_finished.emit(false, null, "", "云端读取失败")
		else:
			download_finished.emit(false, null, "云端读取失败，请稍后再试")
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (json is Array):
		if sync_mode:
			sync_finished.emit(false, null, "", "云端读取失败")
		else:
			download_finished.emit(false, null, "云端读取失败，请稍后再试")
		return
	var rows: Array = json as Array
	if rows.is_empty():
		if sync_mode:
			sync_finished.emit(true, null, "", "")
		else:
			download_finished.emit(false, null, "云端还没有存档，请先上传")
		return
	var row: Dictionary = rows[0] as Dictionary
	var data: Variant = row.get("data")
	if not (data is Dictionary):
		if sync_mode:
			sync_finished.emit(false, null, "", "云端存档格式不正确")
		else:
			download_finished.emit(false, null, "云端存档格式不正确")
		return
	var updated_at: String = str(row.get("updated_at", ""))
	if sync_mode:
		sync_finished.emit(true, data, updated_at, "")
	else:
		download_finished.emit(true, data, "已从云端下载")
