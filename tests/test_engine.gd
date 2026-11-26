extends SceneTree
## headless 测试：
##   Godot.exe --headless --path game --script res://tests/test_engine.gd
## 期望 FAILURES=0，退出码 0。

const PuzzleEngineRef := preload("res://scripts/puzzle_engine.gd")
const LevelPlanRef := preload("res://scripts/level_plan.gd")
const SunSystemRef := preload("res://scripts/sun_system.gd")
const StylesRef := preload("res://scripts/styles.gd")
const AuthLogicRef := preload("res://scripts/auth_logic.gd")
const WorldTimeRef := preload("res://scripts/world_time.gd")

var failures: int = 0


func _assert_true(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_test_known_solves()
	_test_single_press()
	_test_infinite_plan()
	_test_daily_plan()
	_test_generate_levels()
	_test_locked_generation()
	_test_sun_system()
	_test_run_randomness()
	_test_styles()
	_test_mutations()
	_test_auth_logic()
	_test_world_time()
	print("FAILURES=", failures)
	quit(1 if failures > 0 else 0)


func _test_known_solves() -> void:
	var expect: Dictionary = {3: [5, 341], 4: [4, 16770], 5: [15, 14098296], 6: [28, 48838473645]}
	for n in expect:
		var res: Dictionary = PuzzleEngineRef.solve(0, n)
		_assert_true(res["ok"] as bool, "solve(0,%d) ok" % n)
		_assert_true((res["optimal"] as int) == (expect[n][0] as int), "solve(0,%d) optimal" % n)
		_assert_true((res["presses"] as int) == (expect[n][1] as int), "solve(0,%d) presses" % n)
	var res2: Dictionary = PuzzleEngineRef.solve(PuzzleEngineRef.all_on(5), 5)
	_assert_true((res2["optimal"] as int) == 0, "solve(all_on,5) = 0")


func _test_single_press() -> void:
	for n in [3, 4, 5, 6]:
		var cell: int = (n * n) >> 1
		var masks: Array = PuzzleEngineRef.press_masks(n)
		var state: int = PuzzleEngineRef.all_on(n) ^ (masks[cell] as int)
		var res: Dictionary = PuzzleEngineRef.solve(state, n)
		_assert_true(res["ok"] as bool, "single press n=%d ok" % n)
		_assert_true((res["optimal"] as int) == 1, "single press n=%d optimal 1" % n)
		_assert_true((res["presses"] as int) == (1 << cell), "single press n=%d presses" % n)


func _test_infinite_plan() -> void:
	_assert_true(LevelPlanRef.infinite_grid_size(1) == 3, "inf L1 3x3")
	_assert_true(LevelPlanRef.infinite_grid_size(100) == 7, "inf L100 7x7")
	_assert_true(LevelPlanRef.infinite_target(1) == 2, "inf L1 target 2")
	_assert_true(LevelPlanRef.infinite_target(100) == 10, "inf L100 target 10")
	# 前 100 关单调缓升；100 关后线性上升
	for lv in range(2, 201):
		_assert_true(LevelPlanRef.infinite_grid_size(lv) >= LevelPlanRef.infinite_grid_size(lv - 1), "inf size monotonic L%d" % lv)
		_assert_true(LevelPlanRef.infinite_target(lv) >= LevelPlanRef.infinite_target(lv - 1), "inf target monotonic L%d" % lv)
	_assert_true(LevelPlanRef.infinite_target(130) > LevelPlanRef.infinite_target(100), "inf post-100 linear rise")
	_assert_true(LevelPlanRef.infinite_target(160) >= LevelPlanRef.infinite_target(130), "inf post-100 keeps rising")
	# 变异轮换
	_assert_true(LevelPlanRef.infinite_mutation(5) != "", "inf mutation at L5")
	_assert_true(LevelPlanRef.infinite_mutation(6) == "", "inf no mutation at L6")
	_assert_true(LevelPlanRef.infinite_mutation(10) != "", "inf mutation at L10")
	_assert_true(LevelPlanRef.infinite_locked_count(99) == 2, "inf locked 2 before 100")
	_assert_true(LevelPlanRef.infinite_locked_count(160) > 2, "inf locked grows after 100")


func _test_daily_plan() -> void:
	_assert_true(LevelPlanRef.DAILY_LEVELS == 10, "daily 10 levels")
	_assert_true(LevelPlanRef.daily_grid_size(1) == 3, "daily L1 3x3")
	_assert_true(LevelPlanRef.daily_grid_size(10) == 7, "daily L10 7x7")
	_assert_true(LevelPlanRef.daily_target(1) == 2, "daily L1 target 2")
	_assert_true(LevelPlanRef.daily_target(10) == 7, "daily L10 target 7")
	_assert_true(LevelPlanRef.daily_mutation(6) == "blind", "daily L6 blind")
	_assert_true(LevelPlanRef.daily_mutation(8) == "frozen", "daily L8 frozen")
	_assert_true(LevelPlanRef.daily_mutation(10) == "no_hint", "daily L10 no_hint")
	_assert_true(LevelPlanRef.daily_seed() > 20000000, "daily seed from date")
	_assert_true(LevelPlanRef.today_string().length() == 8, "today string YYYYMMDD")
	_assert_true(LevelPlanRef.COIN_REWARD_DAILY == 100, "daily reward 100 coins")


func _check_level(n: int, target: int, mut: String, seed_value: int, locked_count: int, tag: String) -> void:
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
	_assert_true(res["ok"] as bool, "%s solvable" % tag)
	if not (res["ok"] as bool):
		return
	var steps: int = PuzzleEngineRef.popcount(res["presses"] as int)
	_assert_true(steps == (data["optimal"] as int), "%s optimal matches" % tag)
	_assert_true(steps >= target - 1, "%s not trivial (target %d got %d)" % [tag, target, steps])
	var final_state: int = PuzzleEngineRef.apply_presses(data["state"] as int, res["presses"] as int, n)
	_assert_true(final_state == PuzzleEngineRef.all_on(n), "%s solution works" % tag)


func _test_generate_levels() -> void:
	var demo_seed: int = 20261125
	for lv in [1, 10, 50, 100, 130, 160]:
		_check_level(LevelPlanRef.infinite_grid_size(lv), LevelPlanRef.infinite_target(lv),
			LevelPlanRef.infinite_mutation(lv), LevelPlanRef.infinite_seed(demo_seed, lv),
			LevelPlanRef.infinite_locked_count(lv), "inf L%d" % lv)
	for i in range(1, LevelPlanRef.DAILY_LEVELS + 1):
		_check_level(LevelPlanRef.daily_grid_size(i), LevelPlanRef.daily_target(i),
			LevelPlanRef.daily_mutation(i), LevelPlanRef.daily_level_seed(i), 2, "daily L%d" % i)


func _test_locked_generation() -> void:
	var n: int = 5
	var locked: int = 0b00001 | 0b00100
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var data: Dictionary = PuzzleEngineRef.generate(rng, n, 3, locked)
	var res: Dictionary = PuzzleEngineRef.solve(data["state"] as int, n, locked)
	_assert_true(res["ok"] as bool, "locked solvable")
	_assert_true(((res["presses"] as int) & locked) == 0, "locked cells never pressed")
	var final_state: int = PuzzleEngineRef.apply_presses(data["state"] as int, res["presses"] as int, n)
	_assert_true(final_state == PuzzleEngineRef.all_on(n), "locked solution works")


func _test_sun_system() -> void:
	var noon: Dictionary = SunSystemRef.sun_state(12.0)
	_assert_true(noon["is_day"] as bool, "noon is day")
	_assert_true(absf((noon["sun_uv"] as Vector2).x - 0.5) < 0.06, "noon sun centered")
	_assert_true((noon["elevation"] as float) > 0.9, "noon high")
	var morning: Dictionary = SunSystemRef.sun_state(7.0)
	_assert_true((morning["shadow_offset"] as Vector2).x > 0.0, "morning shadow to right")
	var evening: Dictionary = SunSystemRef.sun_state(17.0)
	_assert_true((evening["shadow_offset"] as Vector2).x < 0.0, "evening shadow to left")
	var night: Dictionary = SunSystemRef.sun_state(23.0)
	_assert_true(not (night["is_day"] as bool), "night")
	_assert_true((night["intensity"] as float) < 0.3, "night dim")


func _test_run_randomness() -> void:
	var seed_a: int = 111111
	var seed_b: int = 222222
	var diff: int = 0
	for lv in range(1, 11):
		var n: int = LevelPlanRef.infinite_grid_size(lv)
		var target: int = LevelPlanRef.infinite_target(lv)
		var ra: RandomNumberGenerator = RandomNumberGenerator.new()
		ra.seed = LevelPlanRef.infinite_seed(seed_a, lv)
		var rb: RandomNumberGenerator = RandomNumberGenerator.new()
		rb.seed = LevelPlanRef.infinite_seed(seed_b, lv)
		var da: Dictionary = PuzzleEngineRef.generate(ra, n, target, 0)
		var db: Dictionary = PuzzleEngineRef.generate(rb, n, target, 0)
		if (da["state"] as int) != (db["state"] as int):
			diff += 1
	_assert_true(diff >= 8, "different run seeds give different levels (diff=%d)" % diff)
	var s1: int = LevelPlanRef.new_run_seed()
	var s2: int = LevelPlanRef.new_run_seed()
	_assert_true(s1 != s2, "new_run_seed() returns different seeds")


func _test_styles() -> void:
	var styles: Array = StylesRef.all()
	_assert_true(styles.size() == 6, "6 styles (1 free + 5 purchasable)")
	var ids: Array = []
	var paid: int = 0
	var last_price: int = 0
	for s in styles:
		var d: Dictionary = s as Dictionary
		var id: String = d["id"] as String
		var price: int = d["price"] as int
		var pattern: String = d["pattern"] as String
		_assert_true(not ids.has(id), "style id unique: " + id)
		ids.append(id)
		_assert_true(pattern in StylesRef.PATTERNS, "style pattern valid: " + id)
		_assert_true(d["on"] is Color and d["off"] is Color, "style colors: " + id)
		if price == 0:
			_assert_true(id == StylesRef.default_id(), "only default is free")
		else:
			paid += 1
			_assert_true(price > last_price, "paid style price increasing: " + id)
			last_price = price
	_assert_true(paid == 5, "exactly 5 purchasable styles")
	_assert_true((StylesRef.get_style("sakura")["price"] as int) > 0, "get_style sakura")
	_assert_true((StylesRef.get_style("nope")["id"] as String) == StylesRef.default_id(), "get_style fallback default")


func _test_mutations() -> void:
	for mut in ["blind", "frozen", "no_hint"]:
		_assert_true(LevelPlanRef.mutation_name(mut) != "", "mutation name: " + mut)
		_assert_true(LevelPlanRef.mutation_desc(mut) != "", "mutation desc: " + mut)
		_assert_true(LevelPlanRef.mutation_icon(mut) != "", "mutation icon: " + mut)
	_assert_true(LevelPlanRef.mutation_name("") == "", "no mutation has no name")
	_assert_true(LevelPlanRef.infinite_mutation(5) != "", "infinite L5 has mutation")
	_assert_true(LevelPlanRef.infinite_mutation(4) == "", "infinite L4 no mutation")


func _test_auth_logic() -> void:
	_assert_true(AuthLogicRef.save_path_for("local_guest") == "user://saves/local_guest/slot_0.json", "guest save path")
	_assert_true(AuthLogicRef.save_path_for("550e8400-e29b-41d4-a716-446655440000").ends_with("/slot_0.json"), "uuid save path")
	_assert_true(AuthLogicRef.save_path_for("../evil") == AuthLogicRef.save_path_for("local_guest"), "unsafe id falls back to guest")
	_assert_true(AuthLogicRef.valid_user_id("550e8400-e29b-41d4-a716-446655440000"), "uuid valid")
	_assert_true(AuthLogicRef.valid_user_id("local_guest"), "guest valid")
	_assert_true(not AuthLogicRef.valid_user_id(""), "empty invalid")
	_assert_true(not AuthLogicRef.valid_user_id("a/b"), "slash invalid")
	_assert_true(not AuthLogicRef.valid_user_id(".."), "dotdot invalid")
	_assert_true(AuthLogicRef.merge_decision(true, false) == "auto_merge", "merge: only local -> auto")
	_assert_true(AuthLogicRef.merge_decision(true, true) == "ask", "merge: both -> ask")
	_assert_true(AuthLogicRef.merge_decision(false, true) == "load_account", "merge: only account -> load")
	_assert_true(AuthLogicRef.merge_decision(false, false) == "none", "merge: neither -> none")
	_assert_true(AuthLogicRef.key_kind("sb_secret_abc") == "secret", "key kind: secret")
	_assert_true(AuthLogicRef.key_kind("sb_publishable_abc") == "publishable", "key kind: publishable")
	_assert_true(AuthLogicRef.key_kind("eyJhbGciOi") == "legacy", "key kind: legacy anon")
	_assert_true(AuthLogicRef.key_kind("abc") == "unknown", "key kind: unknown")
	_assert_true(not AuthLogicRef.client_key_ok("sb_secret_abc"), "secret key not client-safe")
	_assert_true(AuthLogicRef.client_key_ok("sb_publishable_abc"), "publishable key client-safe")
	_assert_true(AuthLogicRef.client_key_ok("eyJhbGciOi"), "legacy anon key client-safe")
	_assert_true(AuthLogicRef.login_error_message(400, '{"error_code":"invalid_login_credentials"}').contains("不正确"), "auth error: bad password")
	_assert_true(AuthLogicRef.login_error_message(400, '{"error_code":"email_not_confirmed"}').contains("验证"), "auth error: email confirm")
	_assert_true(AuthLogicRef.login_error_message(400, '{"error_code":"captcha_failed"}').contains("稍后"), "auth error: captcha generic")
	_assert_true(AuthLogicRef.login_error_message(422, '{"error_code":"anonymous_provider_disabled"}').contains("手机号"), "auth error: use phone")
	_assert_true(AuthLogicRef.login_error_message(500, "").contains("稍后"), "auth error: generic")
	_assert_true(AuthLogicRef.valid_phone("13800138000"), "phone: valid")
	_assert_true(AuthLogicRef.valid_phone("+86 138-0013-8000"), "phone: +86 formatted")
	_assert_true(not AuthLogicRef.valid_phone("12345"), "phone: too short")
	_assert_true(not AuthLogicRef.valid_phone("12800138000"), "phone: bad second digit")
	_assert_true(not AuthLogicRef.valid_phone("1380013800a"), "phone: non digit")
	_assert_true(AuthLogicRef.phone_email("13800138000") == "13800138000@phone.local", "phone: internal email")
	_assert_true(AuthLogicRef.phone_email("+86 138-0013-8000") == "13800138000@phone.local", "phone: normalized email")
	_assert_true(not AuthLogicRef.phone_email("13800138000").contains(" "), "phone: email no spaces")
	_assert_true(AuthLogicRef.valid_password("123456"), "password: 6 ok")
	_assert_true(not AuthLogicRef.valid_password("12345"), "password: too short")
	_assert_true(AuthLogicRef.cloud_row_url("https://x.supabase.co", "abc").ends_with("/rest/v1/saves?user_id=eq.abc"), "cloud row url")
	_assert_true(AuthLogicRef.cloud_upload_url("https://x.supabase.co/").ends_with("/rest/v1/saves?on_conflict=user_id"), "cloud upload url")


func _test_world_time() -> void:
	_assert_true(WorldTimeRef.key_from_unix(0, 480) == "19700101", "UTC+8 unix0 key")
	_assert_true(WorldTimeRef.key_from_unix(0, -300) == "19691231", "UTC-5 unix0 key")
	_assert_true(WorldTimeRef.key_from_unix(0, 0) == "19700101", "UTC unix0 key")
	_assert_true(WorldTimeRef.seconds_until_next_day(0, 0) == 86400, "midnight -> 86400")
	_assert_true(WorldTimeRef.seconds_until_next_day(3600, 0) == 82800, "01:00 -> 82800")
	_assert_true(WorldTimeRef.key_from_unix(86400, 0) == "19700102", "next day key")
