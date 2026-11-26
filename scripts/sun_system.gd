extends Node
## 太阳系统：根据本地时区时间计算太阳位置、光线颜色、阴影方向。
## 每 1 秒刷新一次；纯计算函数 sun_state() 可单测。

signal updated

var sun_uv: Vector2 = Vector2(0.5, 0.02)
var shadow_offset: Vector2 = Vector2.ZERO
var ray_color: Color = Color.WHITE
var intensity: float = 1.0
var is_day: bool = true
var elevation: float = 1.0
var hour: float = 12.0

var _timer: float = 0.0
var force_hour: float = -1.0


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		refresh()


func refresh() -> void:
	if force_hour >= 0.0:
		hour = force_hour
	else:
		var t: Dictionary = Time.get_datetime_dict_from_system()
		hour = float(t["hour"]) + float(t["minute"]) / 60.0
	var state: Dictionary = sun_state(hour)
	sun_uv = state["sun_uv"]
	shadow_offset = state["shadow_offset"]
	ray_color = state["ray_color"]
	intensity = state["intensity"]
	is_day = state["is_day"]
	elevation = state["elevation"]
	updated.emit()


static func sun_state(local_hour: float) -> Dictionary:
	## 返回本地时间（0~24）对应的太阳状态。
	var h: float = fmod(local_hour, 24.0)
	if h < 0.0:
		h += 24.0
	var daytime: bool = h >= 6.0 and h < 18.0
	var phase: float = 0.0
	if daytime:
		phase = (h - 6.0) / 12.0
	else:
		var night_hour: float = h if h >= 18.0 else h + 24.0
		phase = (night_hour - 18.0) / 12.0
	var elev: float = sin(phase * PI)
	var x: float = phase
	var sun: Vector2 = Vector2(lerpf(0.08, 0.92, x), lerpf(0.46, 0.02, elev))
	var shadow_len: float = lerpf(1.0, 0.25, elev)
	var shadow_dir: float = 1.0 if x < 0.5 else -1.0
	var shadow: Vector2 = Vector2(shadow_dir * 34.0 * shadow_len, 16.0 * shadow_len)

	var color: Color = Color(0.55, 0.65, 0.95)
	var power: float = 0.18
	if daytime:
		if elev > 0.55:
			color = Color(1.0, 0.98, 0.90)
		elif elev > 0.2:
			color = Color(1.0, 0.85, 0.62)
		else:
			color = Color(1.0, 0.62, 0.38)
		power = lerpf(0.35, 0.95, elev)

	return {
		"sun_uv": sun,
		"is_day": daytime,
		"elevation": elev,
		"shadow_offset": shadow,
		"ray_color": color,
		"intensity": power,
		"hour": h,
	}
