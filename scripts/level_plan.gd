class_name LevelPlan
extends RefCounted
## 关卡计划：常规（无限）与每日（10 关）两种模式。

const DAILY_LEVELS: int = 10
const LEVEL_SEED_STEP: int = 7919
const COIN_REWARD_DAILY: int = 100


# ---------------- 常规无限模式 ----------------

static func infinite_grid_size(level: int) -> int:
	## 前 100 关缓慢变大：3×3 → 7×7（约 40 关到顶），之后固定 7×7
	return clampi(3 + (level - 1) / 10, 3, 7)


static func infinite_target(level: int) -> int:
	## 前 100 关缓慢加最优步数（2 → 10）；100 关后线性上升（每 3 关 +1，封顶 15）
	if level <= 100:
		return clampi(2 + (level - 1) / 12, 2, 10)
	return clampi(10 + (level - 100) / 3, 10, 15)


static func infinite_mutation(level: int) -> String:
	## 每 5 关一个脚本化变异（轮换）
	if level < 5 or level % 5 != 0:
		return ""
	var muts: Array = ["blind", "frozen", "no_hint"]
	return muts[(level / 5) % muts.size()] as String


static func infinite_locked_count(level: int) -> int:
	## 冰封锁格数：100 关前 2 个，之后逐步增加
	if level < 100:
		return 2
	return clampi(2 + (level - 100) / 20, 2, 6)


static func infinite_seed(run_seed: int, level: int) -> int:
	return run_seed + level * LEVEL_SEED_STEP


# ---------------- 每日模式 ----------------

static func daily_grid_size(index: int) -> int:
	## 第 1 关 3×3 → 第 10 关 7×7
	return clampi(3 + (index - 1) / 2, 3, 7)


static func daily_target(index: int) -> int:
	return clampi(2 + index / 2, 2, 7)


static func daily_mutation(index: int) -> String:
	match index:
		6:
			return "blind"
		8:
			return "frozen"
		10:
			return "no_hint"
	return ""


static func daily_seed(day_key: String = "") -> int:
	## 每日挑战种子：优先用联网时间得到的日期 key（YYYYMMDD）；
	## 未联网时退回本地日期（仅用于展示/离线兜底，每日挑战本身要求联网）
	var key: String = day_key
	if key == "" or not key.is_valid_int():
		var d: Dictionary = Time.get_datetime_dict_from_system()
		key = "%04d%02d%02d" % [d["year"], d["month"], d["day"]]
	return int(key)


static func daily_level_seed(index: int, day_key: String = "") -> int:
	return daily_seed(day_key) + index * LEVEL_SEED_STEP


static func today_string() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d" % [d["year"], d["month"], d["day"]]


# ---------------- 公共 ----------------

static func new_run_seed() -> int:
	## 常规模式每局新的随机种子
	var unix: float = Time.get_unix_time_from_system()
	var ticks: int = Time.get_ticks_usec()
	var extra: int = int(randi())
	return int(unix) * 1000003 + ticks + extra


static func mutation_icon(mut: String) -> String:
	match mut:
		"blind":
			return "eye"
		"frozen":
			return "snow"
		"no_hint":
			return "lock"
	return ""


static func mutation_name(mut: String) -> String:
	match mut:
		"blind":
			return "幽暗"
		"frozen":
			return "冰封"
		"no_hint":
			return "硬化"
	return ""


static func mutation_desc(mut: String) -> String:
	match mut:
		"blind":
			return "所有格子几乎同色，只有极细微的明暗差别，印花也变模糊了——仔细看也许能分辨"
		"frozen":
			return "部分格子被冰封，无法点击"
		"no_hint":
			return "本关提示被禁用，只能自己解"
	return ""
