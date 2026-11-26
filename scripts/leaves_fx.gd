extends Node2D
## 背景环境层（参考 CHOICE 标题画面：飘叶 / 尘埃 / 树影呼吸 / 云影缓慢掠过）
## - RigidBody2D 树叶（重力 + 风力 + 旋转），FastNoiseLite 驱动风
## - 尘埃光点（轻飘、随风晃、慢慢下落，纯绘制）
## - 树冠影子按太阳方向偏移并缓慢「呼吸」
## - 云影：两团很淡的大椭圆缓慢横移

const LEAF_COUNT: int = 24
const MOTE_COUNT: int = 16

var sun
var wind_strength: float = 0.0
var leaves: Array = []

var _noise: FastNoiseLite
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _screen: Vector2 = Vector2(1280, 720)
var _motes: Array = []


func _ready() -> void:
	_rng.seed = 20261125
	_noise = FastNoiseLite.new()
	_noise.seed = 11
	_noise.frequency = 0.05
	_screen = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_viewport_resized)
	_spawn_leaves()
	_spawn_motes()


func _on_viewport_resized() -> void:
	_screen = get_viewport_rect().size


func _spawn_leaves() -> void:
	var colors: Array = [
		Color("8fbf5f"), Color("6fa34a"), Color("c9d98a"), Color("a8c46a"), Color("7aa84e"),
	]
	for i in range(LEAF_COUNT):
		var body: RigidBody2D = RigidBody2D.new()
		body.gravity_scale = 0.10
		body.linear_damp = 1.6
		body.angular_damp = 0.8
		body.collision_layer = 0
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 5.0
		shape.shape = circle
		body.add_child(shape)
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(0, -7), Vector2(5, -2), Vector2(4, 5), Vector2(0, 8), Vector2(-4, 5), Vector2(-5, -2),
		])
		poly.color = colors[i % colors.size()] as Color
		body.add_child(poly)
		var border: Line2D = Line2D.new()
		border.points = PackedVector2Array([Vector2(0, -7), Vector2(5, -2), Vector2(4, 5), Vector2(0, 8), Vector2(-4, 5), Vector2(-5, -2), Vector2(0, -7)])
		border.width = 1.0
		border.default_color = Color(0.12, 0.22, 0.08, 0.85)
		body.add_child(border)
		var stem: Line2D = Line2D.new()
		stem.points = PackedVector2Array([Vector2(0, 6), Vector2(0, 13)])
		stem.width = 1.0
		stem.default_color = Color(0.45, 0.55, 0.3, 0.9)
		body.add_child(stem)
		body.position = Vector2(_rng.randf_range(0.0, _screen.x), _rng.randf_range(-_screen.y, _screen.y))
		body.rotation = _rng.randf_range(0.0, TAU)
		body.angular_velocity = _rng.randf_range(-0.8, 0.8)
		add_child(body)
		leaves.append(body)


func _spawn_motes() -> void:
	## 尘埃/花粉光点：轻飘、随风摆、缓慢下落
	for i in range(MOTE_COUNT):
		_motes.append({
			"pos": Vector2(_rng.randf_range(0.0, _screen.x), _rng.randf_range(0.0, _screen.y)),
			"size": _rng.randf_range(1.0, 2.6),
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(6.0, 18.0),
			"alpha": _rng.randf_range(0.18, 0.42),
		})


func _process(delta: float) -> void:
	_time += delta
	wind_strength = _noise.get_noise_1d(_time * 40.0)
	var gust: float = _noise.get_noise_1d(_time * 12.0 + 100.0)
	for item in leaves:
		if not (item is RigidBody2D):
			continue
		var rb: RigidBody2D = item as RigidBody2D
		var mass: float = maxf(rb.mass, 0.05)
		var force: Vector2 = Vector2(
			(wind_strength * 520.0 + 70.0) * mass,
			(-45.0 * gust) * mass
		)
		rb.apply_central_force(force)
		rb.apply_torque(mass * wind_strength * 140.0)
		if rb.position.y > _screen.y + 80.0:
			rb.position = Vector2(_rng.randf_range(0.0, _screen.x), -60.0)
			rb.rotation = _rng.randf_range(0.0, TAU)
		elif rb.position.x > _screen.x + 100.0:
			rb.position.x = -80.0
		elif rb.position.x < -100.0:
			rb.position.x = _screen.x + 80.0
	# 尘埃光点
	for m in _motes:
		var d: Dictionary = m as Dictionary
		var p: Vector2 = d["pos"] as Vector2
		var speed: float = d["speed"] as float
		var phase: float = d["phase"] as float
		p.x += (wind_strength * 26.0 + 8.0) * delta + sin(_time * 0.9 + phase) * 6.0 * delta
		p.y += (speed - wind_strength * 10.0) * delta
		if p.y > _screen.y + 20.0:
			p = Vector2(_rng.randf_range(-40.0, _screen.x), -20.0)
		if p.x > _screen.x + 40.0:
			p.x = -40.0
		elif p.x < -60.0:
			p.x = _screen.x + 20.0
		d["pos"] = p
	queue_redraw()


func _draw() -> void:
	# 1) 云影：两团很淡的大椭圆缓慢横移（CHOICE 的云影呼吸）
	var cloud_a: Vector2 = Vector2(fposmod(_time * 9.0 + _screen.x * 0.2, _screen.x + 900.0) - 450.0, _screen.y * 0.32)
	var cloud_b: Vector2 = Vector2(fposmod(_time * 6.0 + _screen.x * 0.7, _screen.x + 1100.0) - 550.0, _screen.y * 0.62)
	draw_colored_polygon(_ellipse(cloud_a, Vector2(420.0, 120.0), 24), Color(0.02, 0.05, 0.02, 0.06))
	draw_colored_polygon(_ellipse(cloud_b, Vector2(520.0, 150.0), 24), Color(0.02, 0.05, 0.02, 0.05))

	# 2) 尘埃光点（随风飘、暖白微光）
	for m in _motes:
		var d: Dictionary = m as Dictionary
		var p: Vector2 = d["pos"] as Vector2
		var s: float = d["size"] as float
		var a: float = d["alpha"] as float * (0.75 + 0.25 * sin(_time * 1.3 + float(d["phase"])))
		draw_circle(p, s, Color(1.0, 0.96, 0.78, a))

	if sun == null:
		return
	var offset: Vector2 = sun.shadow_offset
	# 3) 树冠大影子：按太阳方向拉长，并缓慢「呼吸」
	var breathe: float = 0.5 + 0.5 * sin(_time * 0.35)
	var tree_base: Vector2 = Vector2(_screen.x * 0.30, _screen.y * 0.80) + offset * (1.8 + breathe * 0.9)
	var scale_x: float = 0.92 + breathe * 0.14
	var ellipse: PackedVector2Array = _ellipse(tree_base, Vector2(250.0 * scale_x, 48.0 * (0.94 + breathe * 0.10)), 32)
	draw_colored_polygon(ellipse, Color(0.04, 0.08, 0.03, 0.22 + breathe * 0.08))
	# 4) 落叶影子
	for item in leaves:
		if not (item is RigidBody2D):
			continue
		var rb: RigidBody2D = item as RigidBody2D
		var p: Vector2 = rb.position + offset
		var shadow_poly: PackedVector2Array = PackedVector2Array([
			p + Vector2(0, -6), p + Vector2(4, -2), p + Vector2(3, 4),
			p + Vector2(0, 7), p + Vector2(-3, 4), p + Vector2(-4, -2),
		])
		draw_colored_polygon(shadow_poly, Color(0.04, 0.08, 0.03, 0.24))


func _ellipse(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
