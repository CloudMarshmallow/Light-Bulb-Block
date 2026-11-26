extends Node
## 登录（Supabase Auth · 手机号 + 密码）：拿到稳定的 user_id 与 access_token。
## 实现说明：Supabase 邮箱/密码接口底层需要 email，这里把「手机号」映射成内部标识
## `<11位手机号>@phone.local`（手机号先做严格格式校验，不含特殊字符，无法注入）。
## 原则：登录失败 / 网络不可用 一律回退 local_guest，绝不阻塞游戏启动。

signal state_changed

const SESSION_PATH: String = "user://auth_session.json"
const CONFIG_PATH: String = "user://auth_config.json"
const BUNDLED_CONFIG_PATH: String = "res://auth_config.json"
const TIMEOUT_SEC: float = 10.0

var user_id: String = AuthLogic.GUEST_ID
var state: String = "guest"      # guest | signing_in | signed_in
var configured: bool = false
var merge_pending: bool = false
var last_error: String = ""
var supabase_url: String = ""
var supabase_key: String = ""
var refresh_token: String = ""
var access_token: String = ""
var phone: String = ""

var _http: HTTPRequest
var _pending_action: String = "refresh"   # refresh | signin | signup


func _ready() -> void:
	load_config()
	_load_session()
	if configured and refresh_token != "":
		call_deferred("try_login")


func load_config() -> void:
	## 读取顺序：环境变量 → user://auth_config.json（用户覆盖）→ res://auth_config.json（随包内置）
	## 内置配置让分发出去的 exe 开箱即可登录，用户无需手动放配置文件。
	supabase_url = OS.get_environment("SUPABASE_URL")
	supabase_key = OS.get_environment("SUPABASE_ANON_KEY")
	if supabase_key == "":
		supabase_key = OS.get_environment("SUPABASE_PUBLISHABLE_KEY")
	if supabase_url == "" or supabase_key == "":
		_read_config_file(CONFIG_PATH)
	if supabase_url == "" or supabase_key == "":
		_read_config_file(BUNDLED_CONFIG_PATH)
	configured = supabase_url.begins_with("https://") and supabase_key != ""
	if configured and not AuthLogic.client_key_ok(supabase_key):
		configured = false
		last_error = "登录配置不可用"


func _read_config_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (json is Dictionary):
		return
	var d: Dictionary = json as Dictionary
	var u: String = str(d.get("url", ""))
	var k: String = str(d.get("anon_key", ""))
	if k == "":
		k = str(d.get("publishable_key", ""))
	if u != "" and k != "":
		supabase_url = u
		supabase_key = k


func key_kind() -> String:
	return AuthLogic.key_kind(supabase_key)


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if not (json is Dictionary):
		return
	var d: Dictionary = json as Dictionary
	refresh_token = str(d.get("refresh_token", ""))
	access_token = str(d.get("access_token", ""))
	phone = str(d.get("phone", ""))
	var saved_id: String = str(d.get("user_id", ""))
	if AuthLogic.valid_user_id(saved_id) and saved_id != AuthLogic.GUEST_ID:
		user_id = saved_id
		state = "signed_in"


func save_session() -> void:
	_ensure_dir(SESSION_PATH.get_base_dir())
	var f: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"user_id": user_id,
		"refresh_token": refresh_token,
		"access_token": access_token,
		"phone": phone,
	}))
	f.close()


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_login_done)


func try_login() -> void:
	## 启动时用 refresh_token 续登（静默，不阻塞）
	if not configured or refresh_token == "":
		return
	_pending_action = "refresh"
	_begin_request("refresh")


func sign_in(phone_input: String, password: String) -> void:
	if not configured:
		last_error = "登录暂不可用"
		state_changed.emit()
		return
	if not AuthLogic.valid_phone(phone_input):
		last_error = "手机号格式不正确"
		state_changed.emit()
		return
	if not AuthLogic.valid_password(password):
		last_error = "密码至少需要 6 位"
		state_changed.emit()
		return
	phone = AuthLogic.normalize_phone(phone_input)
	_pending_action = "signin"
	_begin_request("signin", phone_input, password)


func sign_up(phone_input: String, password: String) -> void:
	if not configured:
		last_error = "登录暂不可用"
		state_changed.emit()
		return
	if not AuthLogic.valid_phone(phone_input):
		last_error = "手机号格式不正确"
		state_changed.emit()
		return
	if not AuthLogic.valid_password(password):
		last_error = "密码至少需要 6 位"
		state_changed.emit()
		return
	phone = AuthLogic.normalize_phone(phone_input)
	_pending_action = "signup"
	_begin_request("signup", phone_input, password)


func _begin_request(action: String, phone_input: String = "", password: String = "") -> void:
	_ensure_http()
	# 上一个请求还在飞行时先取消，避免 HTTPRequest busy 报错（如启动续登与手动登录重叠）
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	state = "signing_in"
	last_error = ""
	state_changed.emit()
	var headers: PackedStringArray = PackedStringArray([
		"apikey: " + supabase_key,
		"Content-Type: application/json",
	])
	var url: String = ""
	var body: String = ""
	match action:
		"refresh":
			url = supabase_url.rstrip("/") + "/auth/v1/token?grant_type=refresh_token"
			body = JSON.stringify({"refresh_token": refresh_token})
		"signin":
			url = supabase_url.rstrip("/") + "/auth/v1/token?grant_type=password"
			body = JSON.stringify({"email": AuthLogic.phone_email(phone_input), "password": password})
		"signup":
			url = supabase_url.rstrip("/") + "/auth/v1/signup"
			body = JSON.stringify({"email": AuthLogic.phone_email(phone_input), "password": password, "data": {}})
	var err: int = _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		last_error = "网络不可用，请稍后再试"
		_set_guest()


func _on_login_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		last_error = AuthLogic.login_error_message(code, body.get_string_from_utf8())
		_set_guest()
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (json is Dictionary):
		last_error = "登录失败，请稍后再试"
		_set_guest()
		return
	var d: Dictionary = json as Dictionary
	# 若项目仍开启邮箱验证，signup 不会返回 session（内部映射邮箱收不到确认信）
	if str(d.get("access_token", "")) == "" and _pending_action == "signup":
		last_error = "注册暂不可用，请联系开发者"
		_set_guest()
		return
	var new_id: String = ""
	var user: Variant = d.get("user")
	if user is Dictionary:
		new_id = str((user as Dictionary).get("id", ""))
	if not AuthLogic.valid_user_id(new_id) or new_id == AuthLogic.GUEST_ID:
		last_error = "登录失败，请稍后再试"
		_set_guest()
		return
	refresh_token = str(d.get("refresh_token", refresh_token))
	access_token = str(d.get("access_token", access_token))
	user_id = new_id
	state = "signed_in"
	last_error = ""
	save_session()
	_resolve_saves_after_login()
	state_changed.emit()


func _resolve_saves_after_login() -> void:
	var guest_path: String = AuthLogic.save_path_for(AuthLogic.GUEST_ID)
	var account_path: String = AuthLogic.save_path_for(user_id)
	var guest_exists: bool = FileAccess.file_exists(guest_path)
	var account_exists: bool = FileAccess.file_exists(account_path)
	match AuthLogic.merge_decision(guest_exists, account_exists):
		"auto_merge":
			_copy_file(guest_path, account_path)
			merge_pending = false
		"ask":
			merge_pending = true
		_:
			merge_pending = false


func resolve_merge(choice: String) -> void:
	## choice: "local" 保留本地 / "account" 使用账号存档
	var guest_path: String = AuthLogic.save_path_for(AuthLogic.GUEST_ID)
	var account_path: String = AuthLogic.save_path_for(user_id)
	if choice == "local":
		_copy_file(guest_path, account_path)
	merge_pending = false
	state_changed.emit()


func logout() -> void:
	refresh_token = ""
	access_token = ""
	phone = ""
	user_id = AuthLogic.GUEST_ID
	state = "guest"
	merge_pending = false
	last_error = ""
	save_session()
	state_changed.emit()


func status_label() -> String:
	match state:
		"signing_in":
			return "登录中…"
		"signed_in":
			return "已登录"
		_:
			return "本地模式"


func is_signed_in() -> bool:
	return state == "signed_in" and user_id != AuthLogic.GUEST_ID and access_token != ""


func _set_guest() -> void:
	state = "guest"
	user_id = AuthLogic.GUEST_ID
	refresh_token = ""
	access_token = ""
	state_changed.emit()


func _copy_file(from_path: String, to_path: String) -> void:
	var f: FileAccess = FileAccess.open(from_path, FileAccess.READ)
	if f == null:
		return
	var content: String = f.get_as_text()
	f.close()
	_ensure_dir(to_path.get_base_dir())
	var out: FileAccess = FileAccess.open(to_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(content)
	out.close()


func _ensure_dir(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
