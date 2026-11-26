class_name AuthLogic
extends RefCounted
## 登录与存档的纯逻辑（不依赖网络/场景树，方便单测）。

const GUEST_ID: String = "local_guest"
const SAVES_ROOT: String = "user://saves"
const SLOT_FILE: String = "slot_0.json"


static func save_path_for(user_id: String) -> String:
	## 存档路径：user://saves/<user_id>/slot_0.json
	var uid: String = user_id if valid_user_id(user_id) else GUEST_ID
	return SAVES_ROOT + "/" + uid + "/" + SLOT_FILE


static func valid_user_id(id: String) -> bool:
	## 只允许安全目录名（Supabase UUID 也符合：a-z0-9-）
	if id.is_empty() or id.length() > 64:
		return false
	if id == "." or id == "..":
		return false
	for i in range(id.length()):
		var ch: String = id[i]
		var ok: bool = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") \
			or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-"
		if not ok:
			return false
	return true


static func merge_decision(guest_exists: bool, account_exists: bool) -> String:
	## 登录成功后的存档处理：
	##   auto_merge   本地有、账号无 → 直接合并到账号
	##   ask          两边都有     → 弹一次选择（保留本地 / 使用账号）
	##   load_account 只有账号存档 → 直接加载账号存档
	##   none         都没有       → 无操作
	if guest_exists and not account_exists:
		return "auto_merge"
	if guest_exists and account_exists:
		return "ask"
	if not guest_exists and account_exists:
		return "load_account"
	return "none"


static func key_kind(key: String) -> String:
	## Supabase 新 API Key 体系：
	##   sb_publishable_... 客户端可用（等同旧 anon key）
	##   sb_secret_...      服务端专用（等同旧 service_role），绝不能放进客户端
	if key.begins_with("sb_secret_"):
		return "secret"
	if key.begins_with("sb_publishable_"):
		return "publishable"
	if key.begins_with("eyJ"):
		return "legacy"
	return "unknown"


static func client_key_ok(key: String) -> bool:
	var kind: String = key_kind(key)
	return kind == "publishable" or kind == "legacy"


static func login_error_message(code: int, body_text: String) -> String:
	## 把 Supabase Auth 的常见错误翻译成给玩家的简短提示（不暴露后端细节）
	var low: String = body_text.to_lower()
	if low.contains("email not confirmed") or low.contains("email_not_confirmed"):
		return "账号需要验证后才能登录"
	if low.contains("credentials"):
		return "手机号或密码不正确"
	if low.contains("user already registered"):
		return "该手机号已注册，请直接登录"
	if low.contains("captcha_failed") or low.contains("captcha protection"):
		return "暂时无法登录，请稍后再试"
	if low.contains("anonymous_provider_disabled"):
		return "请使用手机号登录"
	if low.contains("password") and (low.contains("least") or low.contains("weak")):
		return "密码至少需要 6 位"
	if low.contains("email") and low.contains("invalid"):
		return "登录信息格式不正确"
	if code == 400:
		return "输入有误，请检查手机号与密码"
	return "登录失败，请稍后再试"


static func valid_email(email: String) -> bool:
	var text: String = email.strip_edges()
	var at: int = text.find("@")
	var dot: int = text.rfind(".")
	return at > 0 and dot > at + 1 and dot < text.length() - 1 and text.length() <= 254


static func normalize_phone(input: String) -> String:
	var s: String = input.strip_edges()
	for token in [" ", "-", "(", ")", "\t"]:
		s = s.replace(token, "")
	if s.begins_with("+86"):
		s = s.substr(3)
	elif s.begins_with("86") and s.length() == 13:
		s = s.substr(2)
	return s


static func valid_phone(input: String) -> bool:
	## 中国大陆手机号：1 开头、第二位 3-9、共 11 位、且全部为数字
	var s: String = normalize_phone(input)
	if s.length() != 11:
		return false
	if s.substr(0, 1) != "1":
		return false
	var second: String = s.substr(1, 1)
	if not (second in ["3", "4", "5", "6", "7", "8", "9"]):
		return false
	for i in range(s.length()):
		if not (s[i] in "0123456789"):
			return false
	return true


static func phone_email(input: String) -> String:
	## Supabase 邮箱登录底层需要邮箱；用固定后缀把手机号映射成内部标识。
	## 手机号已通过严格格式校验，不含 @ / 引号 / 空白，无法注入。
	return normalize_phone(input) + "@phone.local"


static func valid_password(password: String) -> bool:
	return password.length() >= 6


static func cloud_row_url(base_url: String, user_id: String) -> String:
	var base: String = base_url.rstrip("/")
	# user_id 必须是合法 UUID（由 Supabase 签发），再做 URL 编码，避免查询参数注入
	return base + "/rest/v1/saves?user_id=eq." + user_id.uri_encode()


static func cloud_upload_url(base_url: String) -> String:
	return base_url.rstrip("/") + "/rest/v1/saves?on_conflict=user_id"
